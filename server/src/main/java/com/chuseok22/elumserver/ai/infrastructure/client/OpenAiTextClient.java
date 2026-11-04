package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.RoutineTranslationDraft;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * OpenAI 텍스트 생성.
 *
 * <p>OpenAI가 데이터 공유에 동의한 조직에 <b>텍스트 모델에 한해</b> 하루 무료 토큰을
 * 준다(mini·nano 계열 250만/일). 이룸의 텍스트 사용량은 그 한도 안에 들어간다.
 * 다만 <b>영구 보장이 아니므로</b> 언제든 Gemini로 되돌릴 수 있어야 한다 — 그래서
 * 제공자를 코드가 아니라 설정으로 고른다.
 *
 * <p><b>모델을 고를 때 주의한다.</b> 실측에서 nano급은 한국어 문장이 깨졌다
 * (gpt-4o-mini가 "가출하기 전에 인사해요"를 생성). 카드 문장은 당사자가 소리 내어
 * 듣는 말이라 품질 저하가 곧 사용자 피해다. 기본값을 mini급으로 두는 이유다.
 *
 * <p>프롬프트와 사용자 입력 조립은 {@link GeminiTextClient}의 것을 그대로 쓴다.
 * 제공자를 바꿨다고 지시문이 달라지면 두 제공자를 비교할 수 없다 —
 * {@link OpenAiImageClient}가 Gemini 프롬프트 빌더를 재사용하는 것과 같은 이유다.
 */
@Slf4j
@Component
public class OpenAiTextClient implements TextGenerationClient {

  private static final String BASE_URL = "https://api.openai.com";

  private final GeminiTextClient geminiTextClient;
  private final PromptTemplateService promptTemplateService;
  private final SystemConfigService systemConfigService;
  private final AiCallLogService aiCallLogService;

  private final RestClient restClient;

  public OpenAiTextClient(GeminiTextClient geminiTextClient, PromptTemplateService promptTemplateService,
    SystemConfigService systemConfigService, AiCallLogService aiCallLogService,
    AiRestClientFactory restClientFactory) {
    this.geminiTextClient = geminiTextClient;
    this.promptTemplateService = promptTemplateService;
    this.systemConfigService = systemConfigService;
    this.aiCallLogService = aiCallLogService;
    this.restClient = restClientFactory.create(BASE_URL);
  }

  @Override
  public TextProvider provider() {
    return TextProvider.OPENAI;
  }

  @Override
  public boolean available() {
    // 이미지와 같은 키를 쓴다. 같은 조직의 같은 계정이므로 키를 두 번 넣게 하면
    // 한쪽만 갱신해 놓고 왜 안 되는지 찾게 된다.
    return systemConfigService.hasSecret(ConfigKey.OPENAI_API_KEY);
  }

  @Override
  public String generateRoutineJson(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> answers,
    boolean includeImagePromptEn
  ) {
    String systemPrompt = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    String userContent = geminiTextClient.buildCreateRoutineUserContent(
      sanitizedInputText, nickname, supportGoals, answers
    );
    return call(
      systemPrompt, userContent, geminiTextClient.responseSchema(includeImagePromptEn),
      "routine", AiCallType.OPENAI_TEXT_CREATE
    );
  }

  @Override
  public String generateQuestionJson(
    String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText
  ) {
    String systemPrompt = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX);
    String userContent = geminiTextClient.buildQuestionUserContent(
      sanitizedInputText, nickname, supportGoals
    );
    return call(
      systemPrompt, userContent, geminiTextClient.questionResponseSchemaFor(supportGoals),
      "routine_questions", AiCallType.OPENAI_TEXT_QUESTION
    );
  }

  @Override
  public String generateRoutineJsonForTest(String systemPrompt, String sampleInput) {
    String userContent = geminiTextClient.buildCreateRoutineUserContent(
      sampleInput, null, Set.of(), List.of()
    );
    // 관리자 시험은 영어 장면까지 받아 본다 — 글 AI 가 FLUX 용 문장을 어떻게 쓰는지 볼 곳이 여기다.
    return call(
      systemPrompt, userContent, geminiTextClient.responseSchema(true),
      "routine", AiCallType.OPENAI_TEXT_CREATE
    );
  }

  @Override
  public String pickPictogramJson(String stepTitle, String stepDescription) {
    AppLocale locale = AiCallContext.currentContentLocale();
    return call(
      GeminiPictogramPickSpec.pictogramPickSystemPrompt(locale),
      geminiTextClient.buildPictogramPickUserContent(stepTitle, stepDescription),
      GeminiPictogramPickSpec.pictogramPickSchema(locale), "pictogram", AiCallType.OPENAI_TEXT_PICTOGRAM
    );
  }

  @Override
  public String translateRoutineJson(
    RoutineTranslationDraft draft, AppLocale sourceLanguage, AppLocale targetLanguage
  ) {
    return call(
      RoutineTranslateSpec.systemPrompt(sourceLanguage, targetLanguage),
      RoutineTranslateSpec.userContent(draft, sourceLanguage, targetLanguage),
      RoutineTranslateSpec.schema(draft.steps().size()), "routine_translation", AiCallType.OPENAI_TEXT_TRANSLATE
    );
  }

  @Override
  public String generateQuestionJsonForTest(String systemPrompt, String sampleInput) {
    String userContent = geminiTextClient.buildQuestionUserContent(sampleInput, null, Set.of());
    return call(
      systemPrompt, userContent, geminiTextClient.questionResponseSchemaForTest(),
      "routine_questions", AiCallType.OPENAI_TEXT_QUESTION
    );
  }

  private String call(
    String systemPrompt, String userContent, Map<String, Object> geminiSchema,
    String schemaName, AiCallType callType
  ) {
    String model = systemConfigService.getString(ConfigKey.OPENAI_TEXT_MODEL);
    String apiKey = systemConfigService.getSecret(ConfigKey.OPENAI_API_KEY);

    Map<String, Object> body = buildRequestBody(
      model, systemPrompt, userContent, geminiSchema, schemaName, callType
    );

    long startedAt = System.currentTimeMillis();
    log.info("OpenAI 텍스트 생성 호출 시작: model={}, callType={}", model, callType);
    try {
      OpenAiChatResponse response = restClient.post()
        .uri("/v1/chat/completions")
        .header("Authorization", "Bearer " + apiKey)
        .body(body)
        .retrieve()
        .body(OpenAiChatResponse.class);

      String content = extractContent(response);
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.info("OpenAI 텍스트 생성 호출 완료: model={}, elapsedMs={}, responseLength={}",
        model, elapsedMs, LogTextLength.of(content));
      aiCallLogService.recordSuccess(callType, model, elapsedMs, toUsageMetadata(response));
      return content;
    } catch (Exception e) {
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.warn("OpenAI 텍스트 생성 호출 실패: model={}, elapsedMs={}", model, elapsedMs, e);
      aiCallLogService.recordFailure(callType, model, elapsedMs, e.getMessage());
      throw e;
    }
  }

  static Map<String, Object> buildRequestBody(
    String model, String systemPrompt, String userContent, Map<String, Object> geminiSchema,
    String schemaName, AiCallType callType
  ) {
    return Map.of(
      "model", model,
      "messages", List.of(
        Map.of("role", "system", "content", systemPrompt),
        Map.of("role", "user", "content", userContent)
      ),
      // temperature는 일부러 보내지 않는다. 일부 모델이 지정값을 거부해, 관리자가
      // 모델명만 바꿨을 뿐인데 호출이 통째로 깨지는 일을 막는다.
      "response_format", Map.of(
        "type", "json_schema",
        "json_schema", Map.of("name", schemaName, "strict", true, "schema", toStrictSchema(geminiSchema))
      ),
      // Chat Completions 는 store 를 보내야만 대시보드 Logs(Completions 탭)에 남는다.
      // 추가 요금은 없고, 보관은 처리방침 9항 "업체 정책에 따름"에 든다.
      "store", true,
      // Logs 에서 일과 만들기와 추가 질문을 갈라 보려고 호출 종류를 붙인다.
      "metadata", Map.of("call_type", callType.name())
    );
  }

  private String extractContent(OpenAiChatResponse response) {
    if (response == null || response.choices() == null || response.choices().isEmpty()) {
      throw new IllegalStateException("OpenAI 응답에 결과가 없음");
    }
    OpenAiChatResponse.Message message = response.choices().get(0).message();
    if (message == null || message.content() == null || message.content().isBlank()) {
      throw new IllegalStateException("OpenAI 응답 본문이 비어 있음");
    }
    return message.content();
  }

  // 토큰 수를 Gemini 형식으로 옮겨 담아 기존 로그·비용 계산 경로를 그대로 탄다.
  // 제공자마다 로그 스키마를 따로 두면 관리자 모니터링 화면이 제공자 수만큼 갈라진다.
  private com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse.UsageMetadata
      toUsageMetadata(OpenAiChatResponse response) {
    if (response == null || response.usage() == null) {
      return null;
    }
    OpenAiChatResponse.Usage usage = response.usage();
    return new GeminiGenerateContentResponse.UsageMetadata(
      usage.promptTokens(), usage.completionTokens(), usage.totalTokens()
    );
  }

  /// Gemini 스키마 > strict 규격 (변환 규칙은 StrictJsonSchemas 한 곳, Claude 도 같이 씀)
  static Map<String, Object> toStrictSchema(Map<String, Object> source) {
    return StrictJsonSchemas.from(source);
  }

  /// 응답에서 쓰는 것만 담는다. 모르는 필드는 무시된다.
  @JsonIgnoreProperties(ignoreUnknown = true)
  record OpenAiChatResponse(List<Choice> choices, Usage usage) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Choice(Message message) {

    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Message(String content) {

    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Usage(
      @JsonProperty("prompt_tokens") Integer promptTokens,
      @JsonProperty("completion_tokens") Integer completionTokens,
      @JsonProperty("total_tokens") Integer totalTokens
    ) {

    }
  }
}
