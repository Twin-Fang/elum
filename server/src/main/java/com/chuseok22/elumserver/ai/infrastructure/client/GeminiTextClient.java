package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.ChildProfileInput;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.RoutineCreateAiInput;
import com.chuseok22.elumserver.ai.core.RoutineQuestionAiInput;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Slf4j
@Component
@RequiredArgsConstructor
public class GeminiTextClient implements TextGenerationClient {

  // GeminiConfig(Task 1)와 LocalLlmConfig가 각각 RestClient 빈을 하나씩 등록해 타입이
  // 같은 빈이 2개 존재하므로, 파라미터명-빈명 자동 매칭에만 기대지 않고 명시한다.
  @Qualifier("geminiRestClient")
  private final RestClient geminiRestClient;
  private final GeminiProperties geminiProperties;
  private final PromptTemplateService promptTemplateService;
  private final SystemConfigService systemConfigService;
  private final AiCallLogService aiCallLogService;
  private final PictogramCatalog pictogramCatalog;

  // 공통 JSON 매퍼 (DefaultJsonMapper)
  private final ObjectMapper objectMapper = DefaultJsonMapper.SHARED;

  @Override
  public TextProvider provider() {
    return TextProvider.GEMINI;
  }

  /// Gemini 키는 아직 배포 환경(yml)에 있다. 이미 돌아가는 경로라 건드리지 않았다.
  @Override
  public boolean available() {
    return geminiProperties.apiKey() != null && !geminiProperties.apiKey().isBlank();
  }

  @Override
  public String generateRoutineJson(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> answers,
    boolean includeImagePromptEn
  ) {
    return firstText(generate(sanitizedInputText, nickname, supportGoals, answers, includeImagePromptEn));
  }

  @Override
  public String generateQuestionJson(
    String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText
  ) {
    return firstText(generateQuestion(nickname, supportGoals, sanitizedInputText));
  }

  @Override
  public String generateRoutineJsonForTest(String systemPrompt, String sampleInput) {
    return firstText(generateForTest(systemPrompt, sampleInput));
  }

  @Override
  public String generateQuestionJsonForTest(String systemPrompt, String sampleInput) {
    return firstText(generateQuestionForTest(systemPrompt, sampleInput));
  }

  /// 직접 추가한 카드 한 장의 픽토그램 id 를 고른다. 지시문은 운영 DB 가 아니라 코드에 둔다 —
  /// 배포로 바로 바뀌고, 관리자 화면에서 실수로 지울 수 없다.
  /// ko 는 한국어 지시, 그 밖의 언어는 입력 언어와 무관하게 뜻으로 맞추라는 영어 지시
  @Override
  public String pickPictogramJson(String stepTitle, String stepDescription) {
    AppLocale locale = AiCallContext.currentContentLocale();
    return firstText(callGenerateContent(
      GeminiPictogramPickSpec.pictogramPickSystemPrompt(locale),
      buildPictogramPickUserContent(stepTitle, stepDescription),
      GeminiPictogramPickSpec.pictogramPickSchema(locale), AiCallType.GEMINI_TEXT_PICTOGRAM));
  }

  // OpenAiTextClient 가 같은 조립을 재사용한다 — 제공자를 바꿔도 지시가 달라지면 두 제공자를 비교할 수 없다.
  String buildPictogramPickUserContent(String stepTitle, String stepDescription) {
    Map<String, Object> input = new LinkedHashMap<>();
    input.put("task", "PICK_PICTOGRAM");
    input.put("stepTitle", stepTitle == null ? "" : stepTitle);
    input.put("stepDescription", stepDescription == null ? "" : stepDescription);
    input.put("pictogramCatalog", pictogramCatalog.ids());
    return toJson(input);
  }

  /**
   * 응답에서 JSON 본문 한 덩어리를 꺼낸다.
   *
   * <p>호출부마다 {@code candidates.get(0)...parts.get(0)}을 직접 훑으면
   * 응답이 비어 올 때 그 자리에서 인덱스 예외가 나 무엇이 없는지 알 수 없다.
   * 한 곳으로 모아 단계마다 무엇이 비었는지 말한다.
   */
  private String firstText(GeminiGenerateContentResponse response) {
    if (response == null || response.candidates() == null || response.candidates().isEmpty()) {
      throw new IllegalStateException("Gemini 응답에 candidates가 없음");
    }
    GeminiGenerateContentResponse.Content content = response.candidates().get(0).content();
    if (content == null || content.parts() == null || content.parts().isEmpty()) {
      throw new IllegalStateException("Gemini 응답에 본문이 없음");
    }
    String text = content.parts().get(0).text();
    if (text == null || text.isBlank()) {
      throw new IllegalStateException("Gemini 응답 본문이 비어 있음");
    }
    return text;
  }

  public GeminiGenerateContentResponse generate(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> answers,
    boolean includeImagePromptEn
  ) {
    String systemPrompt = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    String userContent = buildCreateRoutineUserContent(sanitizedInputText, nickname, supportGoals, answers);
    return callGenerateContent(
      systemPrompt, userContent, responseSchema(includeImagePromptEn), AiCallType.GEMINI_TEXT_CREATE);
  }

  /**
   * 카드 설명 한 줄을 FLUX 용 영어 장면으로 옮긴다.
   *
   * <p>일과 만들기 때는 같은 호출에서 영어 장면을 받으므로 이 호출이 없다. 보호자가 직접 추가한
   * 카드처럼 영어가 없는 카드만 탄다. 실패하면 던진다 — 부르는 쪽이 그 카드만 OpenAI 로 그린다.
   */
  public String translateImagePrompt(String stepDescription) {
    return translate(promptTemplateService.getContent(PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE), stepDescription);
  }

  /// 실사: 캐릭터 없이 물건·장소 중심 한 줄로 옮긴다. 만화용과 달리 "The character" 로 시작하지 않는다.
  public String translateRealisticImagePrompt(String stepDescription) {
    return translate(
      promptTemplateService.getContent(PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE), stepDescription);
  }

  /// 관리자 시험 전용: 저장된 지시문 대신 넘겨받은 것을 쓴다.
  public String translateImagePromptForTest(String systemPrompt, String sampleInput) {
    return translate(systemPrompt, sampleInput);
  }

  private String translate(String systemPrompt, String stepDescription) {
    if (stepDescription == null || stepDescription.isBlank()) {
      throw new IllegalStateException("번역할 카드 설명이 없음");
    }
    String userContent = buildTranslateUserContent(stepDescription);
    String json = firstText(callGenerateContent(
      systemPrompt, userContent, GeminiRoutineSchemas.IMAGE_PROMPT_SCHEMA, AiCallType.GEMINI_TEXT_IMAGE_PROMPT));
    try {
      String line = objectMapper.readTree(json).path("imagePromptEn").asText("");
      line = line.replaceAll("\\s+", " ").trim();
      if (line.isBlank()) {
        throw new IllegalStateException("번역 결과가 비어 있음");
      }
      return line;
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("번역 응답을 읽지 못함", e);
    }
  }

  // 관리자 미리보기와 실제 호출이 같은 조립을 쓴다.
  public String buildTranslateUserContent(String stepDescription) {
    return toJson(Map.of("task", "TRANSLATE_CARD_SCENE", "stepDescription",
      stepDescription == null ? "" : stepDescription));
  }

  // 실제 호출과 관리자 preview가 같은 조립 결과를 쓰도록 조립 로직만 따로 뗀 메서드.
  // Gemini를 호출하지 않으므로 AdminPromptService.preview()에서도 그대로 재사용한다.
  //
  // 이룸이 이름은 AI(Gemini·OpenAI 모두 이 조립기를 쓴다)에 나가지 않는다. nickname 은 자리표시로
  // 바꿔 싣고, 보호자가 글·답변에 적은 이름도 자리표시로 바꾼다. 응답의 자리표시는 RoutineAiPipeline 이 되돌린다.
  public String buildCreateRoutineUserContent(
    String routineText, String nickname, Set<SupportGoal> supportGoals, List<String> answers
  ) {
    AppLocale locale = AiCallContext.currentContentLocale();
    List<String> maskedAnswers = answers == null ? List.<String>of()
      : answers.stream().map(answer -> NicknamePlaceholder.mask(answer, nickname, locale)).toList();
    RoutineCreateAiInput input = new RoutineCreateAiInput(
      "CREATE_ROUTINE",
      NicknamePlaceholder.mask(routineText, nickname, locale),
      new ChildProfileInput(
        NicknamePlaceholder.forAi(nickname, locale), supportGoals == null ? Set.of() : supportGoals),
      maskedAnswers,
      pictogramCatalog.ids()
    );
    return toJson(input);
  }

  // 도움 목표 기반 추가 질문 생성. supportGoals에 PREPARE_ITEMS/PREPARE_NEW가 없으면
  // 호출하는 쪽(RoutineAiPipeline)에서 아예 이 메서드를 부르지 않는다.
  public GeminiGenerateContentResponse generateQuestion(
    String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText
  ) {
    String systemPrompt = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX);
    String userContent = buildQuestionUserContent(sanitizedInputText, nickname, supportGoals);
    return callGenerateContent(
      systemPrompt, userContent, questionResponseSchemaFor(supportGoals), AiCallType.GEMINI_TEXT_QUESTION
    );
  }

  public String buildQuestionUserContent(String routineText, String nickname, Set<SupportGoal> supportGoals) {
    AppLocale locale = AiCallContext.currentContentLocale();
    RoutineQuestionAiInput input = new RoutineQuestionAiInput(
      "GENERATE_ROUTINE_QUESTIONS", NicknamePlaceholder.mask(routineText, nickname, locale),
      new ChildProfileInput(
        NicknamePlaceholder.forAi(nickname, locale), supportGoals == null ? Set.of() : supportGoals)
    );
    return toJson(input);
  }

  // 관리자 테스트 전용: DB 조회 없이 전달받은 systemPrompt를 그대로 사용해
  // 저장 전 미리보기/저장된 값 테스트를 동일한 호출 경로로 지원한다.
  // 관리자 시험은 영어 장면까지 받아 본다 — 글 AI 가 FLUX 용 문장을 어떻게 쓰는지 볼 곳이 여기다.
  public GeminiGenerateContentResponse generateForTest(String systemPrompt, String sampleInput) {
    String userContent = buildCreateRoutineUserContent(sampleInput, null, Set.of(), List.of());
    return callGenerateContent(systemPrompt, userContent, responseSchema(true), AiCallType.GEMINI_TEXT_CREATE);
  }

  public GeminiGenerateContentResponse generateQuestionForTest(String systemPrompt, String sampleInput) {
    String userContent = buildQuestionUserContent(sampleInput, null, Set.of());
    return callGenerateContent(
      systemPrompt, userContent, questionResponseSchemaForTest(), AiCallType.GEMINI_TEXT_QUESTION
    );
  }

  private GeminiGenerateContentResponse callGenerateContent(
    String systemPrompt, String userContentText, Map<String, Object> schema, AiCallType callType
  ) {
    GeminiGenerateContentRequest request = new GeminiGenerateContentRequest(
      new GeminiGenerateContentRequest.GeminiSystemInstruction(
        List.of(new GeminiGenerateContentRequest.GeminiPart(systemPrompt))
      ),
      List.of(new GeminiGenerateContentRequest.GeminiContent(
        "user", List.of(new GeminiGenerateContentRequest.GeminiPart(userContentText))
      )),
      generationConfig(schema)
    );

    // 모델명은 호출 시점마다 시스템 설정에서 읽는다 — 관리자가 바꾸면 재배포 없이 반영된다.
    String model = systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL);
    long startedAt = System.currentTimeMillis();
    // 원문 대신 글자 수만 기록 (지시문·보호자 입력 공통)
    log.info(
      "Gemini 텍스트 생성 호출 시작: model={}, systemPromptLength={}, userContentLength={}",
      model, LogTextLength.of(systemPrompt), LogTextLength.of(userContentText)
    );
    try {
      GeminiGenerateContentResponse response = geminiRestClient.post()
        .uri("/v1beta/models/{model}:generateContent", model)
        .header("x-goog-api-key", geminiProperties.apiKey())
        .body(request)
        .retrieve()
        .body(GeminiGenerateContentResponse.class);
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.info(
        "Gemini 텍스트 생성 호출 완료: model={}, elapsedMs={}, responseLength={}",
        model, elapsedMs, responseTextLength(response)
      );
      aiCallLogService.recordSuccess(
        callType, model, elapsedMs, response == null ? null : response.usageMetadata()
      );
      return response;
    } catch (Exception e) {
      long elapsedMs = System.currentTimeMillis() - startedAt;
      log.warn(
        "Gemini 텍스트 생성 호출 실패: model={}, elapsedMs={}, systemPromptLength={}, userContentLength={}",
        model, elapsedMs, LogTextLength.of(systemPrompt), LogTextLength.of(userContentText), e
      );
      aiCallLogService.recordFailure(callType, model, elapsedMs, e.getMessage());
      throw e;
    }
  }

  /**
   * 로그용 응답 길이: 모든 후보·파트의 text 글자 수 합 (응답 없음 > 0)
   */
  private int responseTextLength(GeminiGenerateContentResponse response) {
    if (response == null || response.candidates() == null) {
      return 0;
    }
    return response.candidates().stream()
      .filter(candidate -> candidate != null && candidate.content() != null && candidate.content().parts() != null)
      .flatMap(candidate -> candidate.content().parts().stream())
      .filter(part -> part != null)
      .mapToInt(part -> LogTextLength.of(part.text()))
      .sum();
  }

  public Map<String, Object> responseSchema() {
    return responseSchema(false);
  }

  /// @param includeImagePromptEn 카드마다 영어 장면(imagePromptEn)을 필수로 받는다
  public Map<String, Object> responseSchema(boolean includeImagePromptEn) {
    return GeminiRoutineSchemas.responseSchema(includeImagePromptEn, !pictogramCatalog.isEmpty());
  }

  public Map<String, Object> questionResponseSchemaFor(Set<SupportGoal> supportGoals) {
    return GeminiRoutineSchemas.questionResponseSchemaFor(supportGoals);
  }

  public Map<String, Object> questionResponseSchemaForTest() {
    return GeminiRoutineSchemas.questionResponseSchemaForTest();
  }

  private String toJson(Object input) {
    try {
      return objectMapper.writeValueAsString(input);
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("Gemini 요청 JSON 직렬화 실패", e);
    }
  }

  // 테스트가 요청 모양을 직접 보도록 패키지 공개로 둔다.
  Map<String, Object> generationConfig(Map<String, Object> schema) {
    Map<String, Object> config = new LinkedHashMap<>();
    config.put("responseMimeType", "application/json");
    config.put("responseSchema", schema);
    config.put("temperature", systemConfigService.getDouble(ConfigKey.GEMINI_TEXT_TEMPERATURE));
    thinkingBudget().ifPresent(budget -> config.put("thinkingConfig", Map.of("thinkingBudget", budget)));
    return config;
  }

  /**
   * 관리자가 정한 생각 토큰 상한. UNSET 이거나 값이 망가졌으면 비어 있다 — 그러면 보내지 않는다.
   *
   * <p>망가진 값을 기본값(UNSET)처럼 다루는 이유: 이상한 숫자를 그대로 실으면 400 으로 일과 만들기가
   * 통째로 실패한다. 설정 파싱 실패를 기본값으로 덮는 SystemConfigService 방침과 같다.
   */
  private Optional<Integer> thinkingBudget() {
    String raw = systemConfigService.getString(ConfigKey.GEMINI_TEXT_THINKING_BUDGET);
    if (raw == null || raw.isBlank() || "UNSET".equals(raw.trim())) {
      return Optional.empty();
    }
    try {
      return Optional.of(Integer.parseInt(raw.trim()));
    } catch (NumberFormatException e) {
      log.warn("생각 토큰 상한 설정을 읽지 못해 보내지 않는다: value={}", raw);
      return Optional.empty();
    }
  }

  /// 로그에서 픽토그램 카탈로그(811개 id, 약 10KB)를 접는다 — 한 줄이 너무 길어져 로그를 읽기 어렵고 값도 고정이라 남길 이유가 없다.
  static String foldPictogramCatalog(String userContent) {
    return userContent == null ? null
      : userContent.replaceAll("\"pictogramCatalog\"\\s*:\\s*\\[[^\\]]*\\]", "\"pictogramCatalog\":\"[생략]\"");
  }
}
