package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.ClaudeApiKeyService;
import com.chuseok22.elumserver.ai.application.service.ClaudeKeyHealthTracker;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.AiFailureKind;
import com.chuseok22.elumserver.ai.core.ClaudeApiKey;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Claude(Anthropic Messages API) 텍스트 생성 (#1083): 키 우선순위대로 시도 > 키 문제면 다음 키 > 다 실패하면 던짐
 * 지시문·입력 조립·스키마는 Gemini 것을 그대로 씀 (제공자를 바꿔도 같은 지시 > 비교 가능, OpenAiTextClient 와 같은 이유)
 */
@Slf4j
@Component
public class ClaudeTextClient implements TextGenerationClient {

  private static final String BASE_URL = "https://api.anthropic.com";
  private static final String MESSAGES_PATH = "/v1/messages";
  // API 버전 (temperature 등 샘플링 값을 보내면 400 인 버전 — 보내지 않음)
  static final String ANTHROPIC_VERSION = "2026-10-21";
  // 응답 최대 토큰 (일과 12단계 + 영어 장면도 넉넉히 들어감. 잘리면 max_tokens 로 실패 처리)
  static final int MAX_OUTPUT_TOKENS = 8192;
  // CLAUDE_TEXT_EFFORT: 이 값이면 effort 를 싣지 않음
  private static final String EFFORT_UNSET = "UNSET";
  /**
   * 일과 만들기 지시문 뒤에 붙이는 Claude 전용 보강 (운영 DB 지시문과 무관하게 코드에서 붙음)
   * 실측(#1083): Haiku 5.5 가 description 에 "앉아서 기다려요"·"잡고 밀어요"처럼 두 동작을 잇는 일이 31단계 중 3번 > 보강
   */
  static final String ROUTINE_CREATE_SUPPLEMENT = """

    [추가 확인 규칙]
    - description 에는 동작 하나만 씁니다. "~아서/~어서"(앉아서 기다려요), "~고"(잡고 밀어요), "~며", \
    "~ㄹ 때"(자를 때 앉아요)로 두 동작이나 조건을 잇지 않습니다. \
    예: "의자에 앉아서 기다려요"(X) → "의자에서 기다려요"(O), "손잡이를 잡고 카트를 밀어요"(X) → \
    "두 손으로 카트를 밀어요"(O).
    - title·description 은 한국어로만 씁니다. 한자·일본어·영어 낱말을 섞지 않습니다(imagePromptEn 만 영어).
    - 단계는 실제로 하는 순서대로 놓습니다.""";

  private final GeminiTextClient geminiTextClient;
  private final PromptTemplateService promptTemplateService;
  private final SystemConfigService systemConfigService;
  private final AiCallLogService aiCallLogService;
  private final ClaudeApiKeyService claudeApiKeyService;
  private final ClaudeKeyHealthTracker keyHealthTracker;
  private final RestClient restClient;

  public ClaudeTextClient(
    GeminiTextClient geminiTextClient, PromptTemplateService promptTemplateService,
    SystemConfigService systemConfigService, AiCallLogService aiCallLogService,
    ClaudeApiKeyService claudeApiKeyService, ClaudeKeyHealthTracker keyHealthTracker,
    AiRestClientFactory restClientFactory
  ) {
    this.geminiTextClient = geminiTextClient;
    this.promptTemplateService = promptTemplateService;
    this.systemConfigService = systemConfigService;
    this.aiCallLogService = aiCallLogService;
    this.claudeApiKeyService = claudeApiKeyService;
    this.keyHealthTracker = keyHealthTracker;
    this.restClient = restClientFactory.create(BASE_URL);
  }

  @Override
  public TextProvider provider() {
    return TextProvider.CLAUDE;
  }

  /// 켜진 키가 하나라도 있으면 쓸 수 있음
  @Override
  public boolean available() {
    return claudeApiKeyService.hasEnabledKey();
  }

  @Override
  public String generateRoutineJson(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> answers,
    boolean includeImagePromptEn
  ) {
    return call(
      promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX) + ROUTINE_CREATE_SUPPLEMENT,
      geminiTextClient.buildCreateRoutineUserContent(sanitizedInputText, nickname, supportGoals, answers),
      geminiTextClient.responseSchema(includeImagePromptEn), AiCallType.CLAUDE_TEXT_CREATE
    );
  }

  @Override
  public String generateQuestionJson(String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText) {
    return call(
      promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX),
      geminiTextClient.buildQuestionUserContent(sanitizedInputText, nickname, supportGoals),
      geminiTextClient.questionResponseSchemaFor(supportGoals), AiCallType.CLAUDE_TEXT_QUESTION
    );
  }

  // 관리자 시험은 영어 장면까지 받아 봄 (Gemini·OpenAI 와 같음). 실제 호출과 같게 보강도 붙임
  @Override
  public String generateRoutineJsonForTest(String systemPrompt, String sampleInput) {
    return call(
      systemPrompt + ROUTINE_CREATE_SUPPLEMENT,
      geminiTextClient.buildCreateRoutineUserContent(sampleInput, null, Set.of(), List.of()),
      geminiTextClient.responseSchema(true), AiCallType.CLAUDE_TEXT_CREATE
    );
  }

  @Override
  public String generateQuestionJsonForTest(String systemPrompt, String sampleInput) {
    return call(
      systemPrompt, geminiTextClient.buildQuestionUserContent(sampleInput, null, Set.of()),
      geminiTextClient.questionResponseSchemaForTest(), AiCallType.CLAUDE_TEXT_QUESTION
    );
  }

  @Override
  public String pickPictogramJson(String stepTitle, String stepDescription) {
    AppLocale locale = AiCallContext.currentContentLocale();
    return call(
      GeminiPictogramPickSpec.pictogramPickSystemPrompt(locale),
      geminiTextClient.buildPictogramPickUserContent(stepTitle, stepDescription),
      GeminiPictogramPickSpec.pictogramPickSchema(locale), AiCallType.CLAUDE_TEXT_PICTOGRAM
    );
  }

  @Override
  public String buildRoutineMemoryJson(String memoryUserContent) {
    return call(
      RoutineMemorySpec.SYSTEM_PROMPT, memoryUserContent, RoutineMemorySpec.RESPONSE_SCHEMA,
      AiCallType.CLAUDE_TEXT_MEMORY
    );
  }

  /**
   * 키 순서대로 1번 호출: 쉬는 키 뒤로 > 키 문제(401·403·402·429·529·5xx·시간 초과·크레딧)면 다음 키 > 그 밖의 실패는 바로 던짐
   * 다른 키로도 안 고쳐지는 실패(요청 형식 400·모델 없음 404·잘린 응답)는 키를 넘기지 않음 > 제공자 사슬이 다음 제공자로
   */
  private String call(String systemPrompt, String userContent, Map<String, Object> geminiSchema, AiCallType callType) {
    List<ClaudeApiKey> keys = keysInTryOrder();
    if (keys.isEmpty()) {
      throw new IllegalStateException("Claude 키가 없음");
    }
    String model = systemConfigService.getString(ConfigKey.CLAUDE_TEXT_MODEL);
    Map<String, Object> body = buildRequestBody(model, systemPrompt, userContent, geminiSchema, effortSetting());
    RuntimeException lastFailure = null;
    for (int keyIndex = 0; keyIndex < keys.size(); keyIndex++) {
      ClaudeApiKey key = keys.get(keyIndex);
      try {
        return callWithKey(key, model, body, callType);
      } catch (RuntimeException e) {
        lastFailure = e;
        if (!ClaudeFailures.shouldTryNextKey(e)) {
          throw e;
        }
        boolean hasNextKey = keyIndex + 1 < keys.size();
        log.warn("[claude text] key failed, {} : key={}, callType={}, kind={}",
          hasNextKey ? "trying next key" : "no more keys", key.nickname(), callType, ClaudeFailures.kindOf(e));
      }
    }
    throw lastFailure;
  }

  /// 켜진 키 > 쉬지 않는 키 먼저 (우선순위 유지), 쉬는 키는 뒤에 (모두 쉬어도 끝까지 시도)
  private List<ClaudeApiKey> keysInTryOrder() {
    List<ClaudeApiKey> healthyKeys = new ArrayList<>();
    List<ClaudeApiKey> coolingKeys = new ArrayList<>();
    for (ClaudeApiKey key : claudeApiKeyService.enabledKeys()) {
      (keyHealthTracker.isCoolingDown(key.id()) ? coolingKeys : healthyKeys).add(key);
    }
    healthyKeys.addAll(coolingKeys);
    return healthyKeys;
  }

  private String callWithKey(ClaudeApiKey key, String model, Map<String, Object> body, AiCallType callType) {
    long startedAt = System.currentTimeMillis();
    log.info("[claude text] call start : model={}, key={}, callType={}", model, key.nickname(), callType);
    try {
      ClaudeMessageResponse response = restClient.post()
        .uri(MESSAGES_PATH)
        .header("x-api-key", key.apiKey())
        .header("anthropic-version", ANTHROPIC_VERSION)
        .body(body)
        .retrieve()
        .body(ClaudeMessageResponse.class);
      String content = ClaudeMessageResponse.extractJsonText(response);
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.info("[claude text] call done : model={}, key={}, elapsedMs={}, responseLength={}",
        model, key.nickname(), elapsedMs, LogTextLength.of(content));
      aiCallLogService.recordSuccess(callType, model, elapsedMs, response.toUsageMetadata(), key.nickname());
      keyHealthTracker.onSuccess(key.id());
      return content;
    } catch (RuntimeException e) {
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.warn("[claude text] call failed : model={}, key={}, elapsedMs={}", model, key.nickname(), elapsedMs, e);
      aiCallLogService.recordFailure(callType, model, elapsedMs, ClaudeFailures.describe(e), key.nickname());
      if (ClaudeFailures.shouldTryNextKey(e)) {
        keyHealthTracker.onFailure(key.id(), AiFailureKind.classify(ClaudeFailures.describe(e)));
      }
      throw e;
    }
  }

  private String effortSetting() {
    String raw = systemConfigService.getString(ConfigKey.CLAUDE_TEXT_EFFORT);
    return raw == null || raw.isBlank() || EFFORT_UNSET.equals(raw.trim()) ? null : raw.trim();
  }

  /**
   * 요청 본문: 모델, 최대 토큰, 시스템 지시, 사용자 입력 1개, JSON 스키마 강제(output_config.format)
   * temperature 는 보내지 않음 (API 버전 2026-10-21 에서 400), effort 는 설정했을 때만
   */
  static Map<String, Object> buildRequestBody(
    String model, String systemPrompt, String userContent, Map<String, Object> geminiSchema, String effort
  ) {
    Map<String, Object> outputConfig = new LinkedHashMap<>();
    outputConfig.put("format", Map.of("type", "json_schema", "schema", StrictJsonSchemas.from(geminiSchema)));
    if (effort != null) {
      outputConfig.put("effort", effort);
    }
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("model", model);
    body.put("max_tokens", MAX_OUTPUT_TOKENS);
    body.put("system", systemPrompt);
    body.put("messages", List.of(Map.of("role", "user", "content", userContent)));
    body.put("output_config", outputConfig);
    return body;
  }
}
