package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.RoutineStepDraft;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
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

  public GeminiGenerateContentResponse generate(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, String answers
  ) {
    String systemPrompt = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_TEXT_PREFIX)
      + buildChildProfileSection(nickname, supportGoals, answers);
    return callGenerateContent(systemPrompt, wrapAsData(sanitizedInputText));
  }

  public GeminiGenerateContentResponse revise(
    List<RoutineStepDraft.StepDraft> previousSteps, String maskedFeedback,
    String nickname, Set<SupportGoal> supportGoals
  ) {
    String systemPrompt = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_TEXT_PREFIX)
      + buildChildProfileSection(nickname, supportGoals, null);
    String previousStepsText = previousSteps.stream()
      .map(step -> step.order() + ". " + step.description())
      .collect(Collectors.joining("\n"));
    String userContent = "이전에 생성된 단계:\n" + previousStepsText
      + "\n\n부모의 수정 요청:\n" + wrapAsData(maskedFeedback);
    return callGenerateContent(systemPrompt, userContent);
  }

  // 도움 목표 기반 추가 질문 생성. supportGoals에 PREPARE_ITEMS/PREPARE_NEW가 없으면
  // 호출하는 쪽(RoutineAiPipeline)에서 아예 이 메서드를 부르지 않는다.
  public GeminiGenerateContentResponse generateQuestion(
    String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText
  ) {
    String systemPrompt = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX)
      + buildChildProfileSection(nickname, supportGoals, null);
    return callGenerateContent(systemPrompt, wrapAsData(sanitizedInputText), questionResponseSchema());
  }

  // 관리자 테스트 전용: DB 조회 없이 전달받은 systemPrompt를 그대로 사용해
  // 저장 전 미리보기/저장된 값 테스트를 동일한 호출 경로로 지원한다.
  public GeminiGenerateContentResponse generateForTest(String systemPrompt, String sampleInput) {
    return callGenerateContent(systemPrompt, wrapAsData(sampleInput));
  }

  // 관리자 테스트 전용(질문 생성 프롬프트): questionResponseSchema를 사용한다는 점만
  // generateForTest와 다르다.
  public GeminiGenerateContentResponse generateQuestionForTest(String systemPrompt, String sampleInput) {
    return callGenerateContent(systemPrompt, wrapAsData(sampleInput), questionResponseSchema());
  }

  // 닉네임/도움 목표/보호자 답변 중 존재하는 것만 시스템 프롬프트 뒤에 이어붙이는
  // "아동 설정" 블록을 만든다. 셋 다 없으면(온보딩 미완료) 빈 문자열을 반환해
  // 프롬프트에 아무 영향도 주지 않는다.
  private String buildChildProfileSection(String nickname, Set<SupportGoal> supportGoals, String answers) {
    boolean hasNickname = nickname != null && !nickname.isBlank();
    boolean hasGoals = supportGoals != null && !supportGoals.isEmpty();
    boolean hasAnswers = answers != null && !answers.isBlank();
    if (!hasNickname && !hasGoals && !hasAnswers) {
      return "";
    }

    StringBuilder section = new StringBuilder("\n\n아동 설정:\n");
    if (hasNickname) {
      section.append("- 호칭: ").append(nickname).append("\n");
    }
    if (hasGoals) {
      section.append("- 선택한 도움 방식:\n");
      int order = 1;
      for (SupportGoal goal : supportGoals) {
        section.append("  ").append(order++).append(". ").append(goal.getLabel()).append("\n");
      }
    }
    if (hasAnswers) {
      section.append("\n보호자가 추가로 알려준 정보: ").append(answers).append("\n");
    }
    return section.toString();
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

    long startedAt = System.currentTimeMillis();
    log.info(
      "Gemini 텍스트 생성 호출 시작: model={}, systemPrompt={}, userContent={}",
      geminiProperties.textModel(), systemPrompt, userContentText
    );
    try {
      GeminiGenerateContentResponse response = geminiRestClient.post()
        .uri("/v1beta/models/{model}:generateContent", geminiProperties.textModel())
        .header("x-goog-api-key", geminiProperties.apiKey())
        .body(request)
        .retrieve()
        .body(GeminiGenerateContentResponse.class);
      log.info(
        "Gemini 텍스트 생성 호출 완료: model={}, elapsedMs={}, response={}",
        geminiProperties.textModel(), System.currentTimeMillis() - startedAt, response
      );
      return response;
    } catch (Exception e) {
      log.warn(
        "Gemini 텍스트 생성 호출 실패: model={}, elapsedMs={}, systemPrompt={}, userContent={}",
        geminiProperties.textModel(), System.currentTimeMillis() - startedAt, systemPrompt, userContentText, e
      );
      throw e;
    }
  }

  private String wrapAsData(String text) {
    return "<text>" + text + "</text>";
  }

  private Map<String, Object> generationConfig(Map<String, Object> schema) {
    return Map.of(
      "responseMimeType", "application/json",
      "responseSchema", schema,
      "temperature", 0
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
              "description", Map.of("type", "string")
            ),
            "required", List.of("order", "description")
          )
        )
      ),
      "required", List.of("title", "steps")
    );
  }

  private Map<String, Object> questionResponseSchema() {
    return Map.of(
      "type", "object",
      "properties", Map.of(
        "questions", Map.of(
          "type", "array",
          "items", Map.of(
            "type", "object",
            "properties", Map.of(
              "question", Map.of("type", "string"),
              "options", Map.of(
                "type", "array",
                "items", Map.of("type", "string")
              )
            ),
            "required", List.of("question", "options")
          )
        )
      ),
      "required", List.of("questions")
    );
  }
}
