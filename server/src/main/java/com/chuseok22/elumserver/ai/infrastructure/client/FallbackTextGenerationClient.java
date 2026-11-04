package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.RoutineTranslationDraft;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.fasterxml.jackson.databind.JsonNode;
import java.util.List;
import java.util.Set;
import java.util.function.Function;
import java.util.function.Predicate;
import lombok.extern.slf4j.Slf4j;

/**
 * 텍스트 제공자 사슬 (#1083): 1번 제공자 > 실패하거나 쓸 수 없는 JSON 이면 같은 요청을 다음 제공자로
 * 각 제공자가 자기 호출을 ai_call_log 에 남겨 어느 제공자·키가 실패·응답했는지 기록에 보임
 * 관리자 시험(ForTest)은 넘기지 않고 1번 제공자만 씀 (다른 제공자 답이 섞이면 시험 결과를 믿을 수 없음)
 */
@Slf4j
final class FallbackTextGenerationClient implements TextGenerationClient {

  // 일과 응답 필수 필드 (파싱 후 상세 검사는 RoutineAiPipeline)
  private static final String ROUTINE_TITLE_FIELD = "title";
  private static final String ROUTINE_STEPS_FIELD = "steps";
  private static final String QUESTIONS_FIELD = "questions";
  private static final String MEMORY_LINES_FIELD = "lines";

  private final List<TextGenerationClient> chain;

  /// @param chain 시도 순서 (쓸 수 있는 제공자만, 1개 이상)
  FallbackTextGenerationClient(List<TextGenerationClient> chain) {
    if (chain.isEmpty()) {
      throw new IllegalArgumentException("텍스트 제공자 사슬이 비어 있음");
    }
    this.chain = List.copyOf(chain);
  }

  @Override
  public TextProvider provider() {
    return chain.get(0).provider();
  }

  @Override
  public boolean available() {
    return true;
  }

  @Override
  public String generateRoutineJson(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> answers,
    boolean includeImagePromptEn
  ) {
    return tryInOrder("routine", FallbackTextGenerationClient::isUsableRoutine,
      client -> client.generateRoutineJson(sanitizedInputText, nickname, supportGoals, answers, includeImagePromptEn));
  }

  @Override
  public String generateQuestionJson(String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText) {
    return tryInOrder("question", FallbackTextGenerationClient::isUsableQuestions,
      client -> client.generateQuestionJson(nickname, supportGoals, sanitizedInputText));
  }

  @Override
  public String pickPictogramJson(String stepTitle, String stepDescription) {
    return tryInOrder("pictogram", JsonNode::isObject, client -> client.pickPictogramJson(stepTitle, stepDescription));
  }

  // 번역: 제목 있음 + 단계 배열 1개 이상이면 넘기지 않음 (단계 수 대조는 RoutineTranslationAi)
  @Override
  public String translateRoutineJson(
    RoutineTranslationDraft draft, AppLocale sourceLanguage, AppLocale targetLanguage
  ) {
    return tryInOrder("translate", FallbackTextGenerationClient::isUsableRoutine,
      client -> client.translateRoutineJson(draft, sourceLanguage, targetLanguage));
  }

  @Override
  public String buildRoutineMemoryJson(String memoryUserContent) {
    return tryInOrder("memory", node -> node.path(MEMORY_LINES_FIELD).isArray(),
      client -> client.buildRoutineMemoryJson(memoryUserContent));
  }

  @Override
  public String generateRoutineJsonForTest(String systemPrompt, String sampleInput) {
    return chain.get(0).generateRoutineJsonForTest(systemPrompt, sampleInput);
  }

  @Override
  public String generateQuestionJsonForTest(String systemPrompt, String sampleInput) {
    return chain.get(0).generateQuestionJsonForTest(systemPrompt, sampleInput);
  }

  /**
   * 사슬 순서대로 호출: 예외 또는 쓸 수 없는 JSON > 다음 제공자
   * 마지막 제공자의 결과·예외는 그대로 돌려줌 (부르는 쪽의 기존 실패 처리·폴백이 그대로 받음)
   */
  private String tryInOrder(String callName, Predicate<JsonNode> isUsable, Function<TextGenerationClient, String> call) {
    for (int stepIndex = 0; stepIndex < chain.size(); stepIndex++) {
      TextGenerationClient client = chain.get(stepIndex);
      boolean isLastStep = stepIndex == chain.size() - 1;
      if (isLastStep) {
        return call.apply(client);
      }
      try {
        String json = call.apply(client);
        if (isUsableJson(json, isUsable)) {
          return json;
        }
        log.warn("[text chain] unusable json, next provider : call={}, provider={}, next={}",
          callName, client.provider(), chain.get(stepIndex + 1).provider());
      } catch (RuntimeException e) {
        log.warn("[text chain] provider failed, next provider : call={}, provider={}, next={}, error={}",
          callName, client.provider(), chain.get(stepIndex + 1).provider(), e.getClass().getSimpleName());
      }
    }
    throw new IllegalStateException("unreachable: chain has a last step");
  }

  private static boolean isUsableJson(String json, Predicate<JsonNode> isUsable) {
    if (json == null || json.isBlank()) {
      return false;
    }
    try {
      JsonNode root = DefaultJsonMapper.SHARED.readTree(json);
      return root != null && isUsable.test(root);
    } catch (Exception e) {
      return false;
    }
  }

  /// 일과: 제목 있음 + 단계 배열 1개 이상
  private static boolean isUsableRoutine(JsonNode root) {
    return root.isObject() && !root.path(ROUTINE_TITLE_FIELD).asText("").isBlank()
      && root.path(ROUTINE_STEPS_FIELD).isArray() && !root.path(ROUTINE_STEPS_FIELD).isEmpty();
  }

  /// 추가 질문: questions 배열 1개 이상
  private static boolean isUsableQuestions(JsonNode root) {
    return root.isObject() && root.path(QUESTIONS_FIELD).isArray() && !root.path(QUESTIONS_FIELD).isEmpty();
  }
}
