package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.ChildProfileInput;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.RoutineCreateAiInput;
import com.chuseok22.elumserver.ai.core.RoutineQuestionAiInput;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Slf4j
@Component
@RequiredArgsConstructor
public class GeminiTextClient {

  // GeminiConfig(Task 1)와 LocalLlmConfig가 각각 RestClient 빈을 하나씩 등록해 타입이
  // 같은 빈이 2개 존재하므로, 파라미터명-빈명 자동 매칭에만 기대지 않고 명시한다.
  @Qualifier("geminiRestClient")
  private final RestClient geminiRestClient;
  private final GeminiProperties geminiProperties;
  private final PromptTemplateService promptTemplateService;
  private final SystemConfigService systemConfigService;

  // Spring Boot 4.1은 Jackson 3 기반이라 Jackson 2 ObjectMapper 빈이 자동 구성되지 않으므로
  // RoutineAiPipeline과 동일하게 직접 생성해서 쓴다.
  private final ObjectMapper objectMapper = new ObjectMapper();

  public GeminiGenerateContentResponse generate(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> answers
  ) {
    String systemPrompt = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    String userContent = buildCreateRoutineUserContent(sanitizedInputText, nickname, supportGoals, answers);
    return callGenerateContent(systemPrompt, userContent);
  }

  // 실제 호출과 관리자 preview가 같은 조립 결과를 쓰도록 조립 로직만 따로 뗀 메서드.
  // Gemini를 호출하지 않으므로 AdminPromptService.preview()에서도 그대로 재사용한다.
  public String buildCreateRoutineUserContent(
    String routineText, String nickname, Set<SupportGoal> supportGoals, List<String> answers
  ) {
    RoutineCreateAiInput input = new RoutineCreateAiInput(
      "CREATE_ROUTINE",
      routineText,
      new ChildProfileInput(nickname, supportGoals == null ? Set.of() : supportGoals),
      answers == null ? List.of() : answers
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
    return callGenerateContent(systemPrompt, userContent, questionResponseSchemaFor(supportGoals));
  }

  public String buildQuestionUserContent(String routineText, String nickname, Set<SupportGoal> supportGoals) {
    RoutineQuestionAiInput input = new RoutineQuestionAiInput(
      "GENERATE_ROUTINE_QUESTIONS", routineText,
      new ChildProfileInput(nickname, supportGoals == null ? Set.of() : supportGoals)
    );
    return toJson(input);
  }

  // 관리자 테스트 전용: DB 조회 없이 전달받은 systemPrompt를 그대로 사용해
  // 저장 전 미리보기/저장된 값 테스트를 동일한 호출 경로로 지원한다.
  public GeminiGenerateContentResponse generateForTest(String systemPrompt, String sampleInput) {
    String userContent = buildCreateRoutineUserContent(sampleInput, null, Set.of(), List.of());
    return callGenerateContent(systemPrompt, userContent);
  }

  public GeminiGenerateContentResponse generateQuestionForTest(String systemPrompt, String sampleInput) {
    String userContent = buildQuestionUserContent(sampleInput, null, Set.of());
    return callGenerateContent(systemPrompt, userContent, questionResponseSchemaForTest());
  }

  private GeminiGenerateContentResponse callGenerateContent(String systemPrompt, String userContentText) {
    return callGenerateContent(systemPrompt, userContentText, responseSchema());
  }

  private GeminiGenerateContentResponse callGenerateContent(
    String systemPrompt, String userContentText, Map<String, Object> schema
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
    log.info(
      "Gemini 텍스트 생성 호출 시작: model={}, systemPrompt={}, userContent={}",
      model, systemPrompt, userContentText
    );
    try {
      GeminiGenerateContentResponse response = geminiRestClient.post()
        .uri("/v1beta/models/{model}:generateContent", model)
        .header("x-goog-api-key", geminiProperties.apiKey())
        .body(request)
        .retrieve()
        .body(GeminiGenerateContentResponse.class);
      log.info(
        "Gemini 텍스트 생성 호출 완료: model={}, elapsedMs={}, response={}",
        model, System.currentTimeMillis() - startedAt, response
      );
      return response;
    } catch (Exception e) {
      log.warn(
        "Gemini 텍스트 생성 호출 실패: model={}, elapsedMs={}, systemPrompt={}, userContent={}",
        model, System.currentTimeMillis() - startedAt, systemPrompt, userContentText, e
      );
      throw e;
    }
  }

  private String toJson(Object input) {
    try {
      return objectMapper.writeValueAsString(input);
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("Gemini 요청 JSON 직렬화 실패", e);
    }
  }

  private Map<String, Object> generationConfig(Map<String, Object> schema) {
    return Map.of(
      "responseMimeType", "application/json",
      "responseSchema", schema,
      "temperature", systemConfigService.getDouble(ConfigKey.GEMINI_TEXT_TEMPERATURE)
    );
  }

  private Map<String, Object> responseSchema() {
    return Map.of(
      "type", "object",
      "properties", Map.of(
        "title", Map.of(
          "type", "string",
          "description",
          "일과 전체를 아우르는 제목. 아이 친화적인 '~해요' 체로 작성 (예: '비오는 날 학교에 가요')"
        ),
        "steps", Map.of(
          "type", "array",
          "maxItems", 10,
          "items", Map.of(
            "type", "object",
            "properties", Map.of(
              "order", Map.of("type", "integer"),
              "title", Map.of(
                "type", "string",
                "minLength", 1,
                "description", "카드에 크게 표시할 2~4어절짜리 짧은 라벨. '~해요' 체 (예: '옷을 입어요')"
              ),
              "description", Map.of(
                "type", "string",
                "description",
                "아동에게 소리 내어 읽어줄 문장. title보다 조금 더 자세하게 서술 "
                  + "(예: '학교에 입고 갈 옷을 차례대로 입어요')"
              )
            ),
            "required", List.of("order", "title", "description")
          )
        )
      ),
      "required", List.of("title", "steps")
    );
  }

  // 선택된 도움 목표 중 질문 생성 대상(PREPARE_ITEMS/PREPARE_NEW)의 개수만큼 questions
  // 배열 크기를 정확히 강제한다 — 목표 2개를 선택했는데 Gemini가 질문 1개만 반환하는
  // 것을 스키마 단계에서부터 막기 위함.
  public Map<String, Object> questionResponseSchemaFor(Set<SupportGoal> supportGoals) {
    int relevantGoalCount = (int) (supportGoals == null ? 0 : supportGoals.stream()
      .filter(goal -> goal == SupportGoal.PREPARE_ITEMS || goal == SupportGoal.PREPARE_NEW)
      .count());
    return Map.of(
      "type", "object",
      "properties", Map.of(
        "questions", Map.of(
          "type", "array", "minItems", relevantGoalCount, "maxItems", relevantGoalCount,
          "items", questionItemSchema()
        )
      ),
      "required", List.of("questions")
    );
  }

  // 관리자 테스트 전용: 목표 개수를 알 수 없는 임의의 프롬프트 테스트이므로 questions
  // 배열 크기를 제한하지 않는다.
  private Map<String, Object> questionResponseSchemaForTest() {
    return Map.of(
      "type", "object",
      "properties", Map.of("questions", Map.of("type", "array", "items", questionItemSchema())),
      "required", List.of("questions")
    );
  }

  private Map<String, Object> questionItemSchema() {
    return Map.of(
      "type", "object",
      "properties", Map.of(
        "supportGoal", Map.of("type", "string", "enum", List.of("PREPARE_ITEMS", "PREPARE_NEW")),
        "question", Map.of("type", "string"),
        "options", Map.of(
          "type", "array",
          "minItems", 3,
          "maxItems", 5,
          "items", Map.of(
            "type", "object",
            "properties", Map.of(
              "emoji", Map.of("type", "string"),
              "label", Map.of("type", "string")
            ),
            "required", List.of("emoji", "label")
          )
        )
      ),
      "required", List.of("supportGoal", "question", "options")
    );
  }
}
