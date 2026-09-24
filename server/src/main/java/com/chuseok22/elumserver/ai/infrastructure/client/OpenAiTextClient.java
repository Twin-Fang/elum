package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
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
 * 듣는 말이라 품질 저하가 곧 사고다. 기본값을 mini급으로 두는 이유다.
 *
 * <p>프롬프트와 사용자 입력 조립은 {@link GeminiTextClient}의 것을 그대로 쓴다.
 * 제공자를 바꿨다고 지시문이 달라지면 두 제공자를 비교할 수 없다 —
 * {@link OpenAiImageClient}가 Gemini 프롬프트 빌더를 재사용하는 것과 같은 이유다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class OpenAiTextClient implements TextGenerationClient {

  private static final String BASE_URL = "https://api.openai.com";

  private final GeminiTextClient geminiTextClient;
  private final PromptTemplateService promptTemplateService;
  private final SystemConfigService systemConfigService;
  private final AiCallLogService aiCallLogService;

  private final RestClient restClient = buildRestClient();

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

    Map<String, Object> body = Map.of(
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
      )
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
      log.info("OpenAI 텍스트 생성 호출 완료: model={}, elapsedMs={}, response={}",
        model, elapsedMs, content);
      aiCallLogService.recordSuccess(callType, model, elapsedMs, toUsageMetadata(response));
      return content;
    } catch (Exception e) {
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.warn("OpenAI 텍스트 생성 호출 실패: model={}, elapsedMs={}", model, elapsedMs, e);
      aiCallLogService.recordFailure(callType, model, elapsedMs, e.getMessage());
      throw e;
    }
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

  /**
   * Gemini 스키마 한 벌을 OpenAI strict 규격으로 옮긴다.
   *
   * <p><b>스키마를 두 벌로 나누지 않는 이유.</b> 일과 카드의 형태(제목·단계·설명)는
   * 제공자와 무관한 서비스 규칙이다. 두 곳에 적어 두면 한쪽만 고쳐져 제공자를 바꾼
   * 순간 카드 모양이 달라진다.
   *
   * <p>세 가지를 맞춘다 — strict 모드는 (1) 모든 객체에
   * {@code additionalProperties:false}를 요구하고, (2) {@code required}에 모든
   * 프로퍼티가 들어 있어야 하며, (3) {@code minItems} 같은 길이 제약을 받지 않는다.
   * 길이 제약은 버리는 것이 아니라 <b>프롬프트에 이미 적혀 있다</b> — 스키마로 두 번
   * 강제하던 것을 한 겹 잃을 뿐이라, 질문 개수가 모자라면 기존 목표별 fallback이 받는다.
   */
  static Map<String, Object> toStrictSchema(Map<String, Object> source) {
    Map<String, Object> converted = new LinkedHashMap<>();
    for (Map.Entry<String, Object> entry : source.entrySet()) {
      String key = entry.getKey();
      if (UNSUPPORTED_KEYWORDS.contains(key)) {
        continue;
      }
      converted.put(key, convertValue(entry.getValue()));
    }
    if ("object".equals(source.get("type"))) {
      Object properties = converted.get("properties");
      if (properties instanceof Map<?, ?> propertyMap) {
        converted.put("required", new ArrayList<>(propertyMap.keySet()));
      }
      converted.put("additionalProperties", false);
    }
    return converted;
  }

  @SuppressWarnings("unchecked")
  private static Object convertValue(Object value) {
    if (value instanceof Map<?, ?> map) {
      return toStrictSchema((Map<String, Object>) map);
    }
    if (value instanceof List<?> list) {
      return list.stream().map(OpenAiTextClient::convertValue).toList();
    }
    return value;
  }

  /// strict 모드가 받지 않는 키워드. 남겨 두면 400으로 호출 자체가 실패한다.
  private static final Set<String> UNSUPPORTED_KEYWORDS =
    Set.of("minItems", "maxItems", "minLength", "maxLength");

  // 텍스트 생성은 길어야 수십 초다. 읽기 제한을 넉넉히 두되 무한 대기는 막는다.
  private static RestClient buildRestClient() {
    SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(Duration.ofSeconds(10));
    factory.setReadTimeout(Duration.ofSeconds(120));
    return RestClient.builder().baseUrl(BASE_URL).requestFactory(factory).build();
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
