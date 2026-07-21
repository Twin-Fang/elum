package com.chuseok22.elumserver.routine.infrastructure.ai;

import com.chuseok22.elumserver.ai.core.RoutineQuestionDraft;
import com.chuseok22.elumserver.ai.core.RoutineStepDraft;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineAiPipeline {

  private static final int MAX_STEPS = 10;

  // Spring Boot 4.1은 Jackson 3 기반이라 Jackson 2 ObjectMapper 빈이 자동 구성되지 않으므로
  // SensitiveInfoGuardService와 동일하게 직접 생성해서 쓴다.
  private final ObjectMapper objectMapper = new ObjectMapper();

  private final GeminiTextClient geminiTextClient;
  private final GeminiImageClient geminiImageClient;
  private final RoutineImageStorage routineImageStorage;

  public RoutineGenerationResult generateForCreate(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> maskedAnswers,
    CharacterType characterType
  ) {
    RoutineStepDraft draft = parseDraft(
      () -> geminiTextClient.generate(sanitizedInputText, nickname, supportGoals, maskedAnswers)
    );
    return buildResult(draft, characterType, Map.of());
  }

  public RoutineGenerationResult generateForRevise(
    String previousTitle, List<RoutineStepDraft.StepDraft> previousSteps,
    Map<Integer, String> previousImagePathsByOrder, String maskedFeedback,
    String nickname, Set<SupportGoal> supportGoals, CharacterType characterType
  ) {
    RoutineStepDraft draft = parseDraft(() ->
      geminiTextClient.revise(previousTitle, previousSteps, maskedFeedback, nickname, supportGoals)
    );
    return buildResult(draft, characterType, reusableImagePaths(previousSteps, previousImagePathsByOrder, draft));
  }

  // 새 단계 설명이 기존 단계(같은 order)와 완전히 같으면 이미지를 다시 생성하지 않고
  // 기존 경로를 그대로 쓴다 — Gemini 호출과 이미지 생성 비용을 줄이고, 보호자가 요청하지
  // 않은 단계의 그림이 재생성 때마다 미묘하게 달라지는 것도 막는다.
  private Map<Integer, String> reusableImagePaths(
    List<RoutineStepDraft.StepDraft> previousSteps, Map<Integer, String> previousImagePathsByOrder,
    RoutineStepDraft newDraft
  ) {
    Map<Integer, String> previousDescriptionByOrder = previousSteps.stream()
      .collect(Collectors.toMap(RoutineStepDraft.StepDraft::order, RoutineStepDraft.StepDraft::description));
    return newDraft.steps().stream()
      .filter(step -> step.description().equals(previousDescriptionByOrder.get(step.order()))
        && previousImagePathsByOrder.containsKey(step.order()))
      .collect(Collectors.toMap(RoutineStepDraft.StepDraft::order, step -> previousImagePathsByOrder.get(step.order())));
  }

  private static final int MIN_OPTIONS = 3;

  // 도움 목표 기반 추가 질문 생성. 선택된 각 SupportGoal(PREPARE_ITEMS, PREPARE_NEW)마다
  // Gemini 응답에서 supportGoal이 일치하고 옵션이 3개 이상 남는 질문을 찾아 쓰고, 없으면
  // 그 목표만 fallbackQuestion(goal)로 대체한다 — 목표 하나가 무효여도 나머지 목표까지
  // 통째로 fallback 처리되던 이전 동작을 목표 단위로 좁혔다.
  public RoutineQuestionResult generateQuestion(
    String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText
  ) {
    Map<String, RoutineQuestionResult.QuestionResultItem> validQuestionsByGoal = fetchValidQuestionsByGoal(
      nickname, supportGoals, sanitizedInputText
    );

    List<RoutineQuestionResult.QuestionResultItem> questions = new ArrayList<>();
    for (SupportGoal goal : List.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW)) {
      if (!supportGoals.contains(goal)) {
        continue;
      }
      RoutineQuestionResult.QuestionResultItem valid = validQuestionsByGoal.get(goal.name());
      questions.add(valid != null ? valid : fallbackQuestionItem(goal));
    }
    return new RoutineQuestionResult(questions);
  }

  // Gemini 호출/파싱이 아예 실패하면 빈 맵을 반환해 모든 목표가 fallback을 쓰게 한다
  // (기존의 "전체 실패 시 전체 fallback"과 동일한 결과가 되지만, 응답이 왔는데 일부
  // 목표만 무효인 경우와 같은 경로로 처리한다).
  private Map<String, RoutineQuestionResult.QuestionResultItem> fetchValidQuestionsByGoal(
    String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText
  ) {
    String json = null;
    try {
      GeminiGenerateContentResponse response =
        geminiTextClient.generateQuestion(nickname, supportGoals, sanitizedInputText);
      json = response.candidates().get(0).content().parts().get(0).text();
      RoutineQuestionDraft draft = objectMapper.readValue(json, RoutineQuestionDraft.class);
      if (draft.questions() == null) {
        return Map.of();
      }
      return draft.questions().stream()
        .filter(this::isValidQuestionItem)
        .collect(Collectors.toMap(
          RoutineQuestionDraft.QuestionItem::supportGoal,
          item -> new RoutineQuestionResult.QuestionResultItem(item.question(), toOptionResults(item.options())),
          (first, second) -> first // 같은 supportGoal이 중복되면 먼저 나온 것만 채택한다.
        ));
    } catch (Exception e) {
      log.warn("Gemini 추가 질문 생성 실패, 목표별 고정 매핑으로 대체: response={}", json, e);
      return Map.of();
    }
  }

  // supportGoal이 PREPARE_ITEMS/PREPARE_NEW 중 하나이고, question이 비어있지 않고, 라벨이
  // 있는 옵션이 3개 이상 남아야 유효한 질문으로 인정한다.
  private boolean isValidQuestionItem(RoutineQuestionDraft.QuestionItem item) {
    boolean hasKnownGoal = "PREPARE_ITEMS".equals(item.supportGoal()) || "PREPARE_NEW".equals(item.supportGoal());
    boolean hasQuestion = item.question() != null && !item.question().isBlank();
    long validOptionCount = item.options() == null ? 0 : item.options().stream()
      .filter(option -> option.label() != null && !option.label().isBlank())
      .count();
    return hasKnownGoal && hasQuestion && validOptionCount >= MIN_OPTIONS;
  }

  // label이 없는 옵션은 아동에게 보여줄 수 없는 빈 버튼이 되므로 제외한다. emoji만 없으면
  // label은 유효하므로 옵션 자체를 버리지 않고 빈 문자열로 완화한다.
  private List<RoutineQuestionResult.QuestionResultItem.OptionResult> toOptionResults(
    List<RoutineQuestionDraft.QuestionItem.Option> options
  ) {
    return options.stream()
      .filter(option -> option.label() != null && !option.label().isBlank())
      .map(option -> new RoutineQuestionResult.QuestionResultItem.OptionResult(
        option.emoji() == null ? "" : option.emoji(), option.label()
      ))
      .toList();
  }

  // 목표 하나에 대한 고정 대체 질문. "직접 입력"은 보호자가 자유 텍스트를 입력하도록
  // 유도하는 항목이라 추천 답변 목록에 절대 포함하지 않는다(서비스 정책).
  private RoutineQuestionResult.QuestionResultItem fallbackQuestionItem(SupportGoal goal) {
    if (goal == SupportGoal.PREPARE_ITEMS) {
      return new RoutineQuestionResult.QuestionResultItem(
        "꼭 챙겨야 하는 준비물이 있나요?",
        List.of(
          option("☔", "우산"), option("🧥", "우비"), option("👖", "장화"),
          option("🧦", "여벌 양말"), option("🧻", "작은 수건")
        )
      );
    }
    return new RoutineQuestionResult.QuestionResultItem(
      "평소와 다르게 준비해야 하는 점이 있나요?",
      List.of(
        option("⏰", "시간 변경"), option("📍", "장소 변경"),
        option("🧑‍🤝‍🧑", "동행자 변경"), option("🌦️", "날씨/환경 변화")
      )
    );
  }

  private RoutineQuestionResult.QuestionResultItem.OptionResult option(String emoji, String label) {
    return new RoutineQuestionResult.QuestionResultItem.OptionResult(emoji, label);
  }

  // Gemini 호출 자체(RestClient의 RestClientResponseException/ResourceAccessException 등)와
  // 응답 파싱을 하나의 try 블록에서 함께 처리한다. 호출과 파싱을 분리해두면 호출 실패가
  // 이 메서드 밖으로 그대로 전파돼 GlobalExceptionHandler의 범용 500 처리로 새어나가
  // ROUTINE_AI_GENERATION_FAILED(502)로 변환되지 않는 문제가 있었다(fable5 검토에서 발견).
  private RoutineStepDraft parseDraft(Supplier<GeminiGenerateContentResponse> call) {
    String json = null;
    try {
      GeminiGenerateContentResponse response = call.get();
      json = response.candidates().get(0).content().parts().get(0).text();
      RoutineStepDraft draft = objectMapper.readValue(json, RoutineStepDraft.class);
      // title은 Routine.title이 NOT NULL이라, 스키마 위반으로 누락되면 DB 제약 위반(500)이
      // 아니라 여기서 먼저 502로 처리한다(fable5 검토에서 발견).
      if (draft.title() == null || draft.title().isBlank()) {
        log.warn("Gemini가 title 없이 응답함: response={}", json);
        throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
      }
      if (draft.steps() == null || draft.steps().isEmpty() || draft.steps().size() > MAX_STEPS) {
        log.warn("Gemini가 반환한 단계 수가 허용 범위를 벗어남: count={}, response={}",
          draft.steps() == null ? 0 : draft.steps().size(), json);
        throw new CustomException(ErrorCode.ROUTINE_STEP_LIMIT_EXCEEDED);
      }
      if (draft.steps().stream().anyMatch(step -> step.title() == null || step.title().isBlank())) {
        log.warn("Gemini가 일부 단계에 title 없이 응답함: response={}", json);
        throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
      }
      return normalizeOrder(draft);
    } catch (CustomException e) {
      throw e;
    } catch (Exception e) {
      log.warn("Gemini 텍스트 생성/응답 파싱 실패: response={}", json, e);
      throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
    }
  }

  // 모델이 order를 중복/누락되게 반환해도(예: 1,1,2) 이미지 파일 경로가 충돌하지 않도록,
  // 배열 순서를 유일한 기준으로 삼아 order를 1부터 다시 채번한다(fable5 검토에서 발견).
  private RoutineStepDraft normalizeOrder(RoutineStepDraft draft) {
    List<RoutineStepDraft.StepDraft> normalized = new ArrayList<>();
    for (int i = 0; i < draft.steps().size(); i++) {
      RoutineStepDraft.StepDraft step = draft.steps().get(i);
      normalized.add(new RoutineStepDraft.StepDraft(i + 1, step.title(), step.description()));
    }
    return new RoutineStepDraft(draft.title(), normalized);
  }

  private RoutineGenerationResult buildResult(
    RoutineStepDraft draft, CharacterType characterType, Map<Integer, String> reusableImagePathsByOrder
  ) {
    String batchId = UUID.randomUUID().toString();
    ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
    try {
      List<CompletableFuture<StepResult>> futures = draft.steps().stream()
        .map(stepDraft -> CompletableFuture.supplyAsync(
          () -> resolveStepResult(stepDraft, characterType, reusableImagePathsByOrder), executor
        ))
        .toList();

      // 이미지 생성(HTTP 호출)까지만 병렬로 완료시키고, 파일 저장은 전부 성공한 뒤에만
      // 수행한다 — 일부 단계만 실패해도 이미 디스크에 쓰인 고아 이미지가 남지 않도록
      // 하기 위함(스펙: "모든 단계가 성공적으로 생성된 뒤에만 저장", fable5 검토에서 발견).
      // futures는 draft.steps() 순서 그대로이고 normalizeOrder가 이미 1..N으로 정렬해뒀으므로
      // 별도 정렬 없이도 steps는 순서대로 나온다.
      List<StepResult> stepResults = futures.stream().map(CompletableFuture::join).toList();

      List<GeneratedStep> steps = stepResults.stream()
        .map(result -> new GeneratedStep(
          result.stepDraft().order(),
          result.stepDraft().title(),
          result.stepDraft().description(),
          result.reusedImagePath() != null
            ? result.reusedImagePath()
            : routineImageStorage.save(batchId, result.stepDraft().order(), result.generatedImage())
        ))
        .toList();

      return new RoutineGenerationResult(draft.title(), steps);
    } catch (CompletionException e) {
      log.warn("단계별 이미지 생성 실패", e);
      throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
    } finally {
      executor.shutdown();
    }
  }

  private StepResult resolveStepResult(
    RoutineStepDraft.StepDraft stepDraft, CharacterType characterType,
    Map<Integer, String> reusableImagePathsByOrder
  ) {
    String reusablePath = reusableImagePathsByOrder.get(stepDraft.order());
    if (reusablePath != null) {
      return new StepResult(stepDraft, null, reusablePath);
    }
    return new StepResult(stepDraft, generateImageWithRetry(stepDraft.description(), characterType), null);
  }

  // 이미지 단계 하나가 일시적으로 실패해도 전체 루틴 생성을 곧바로 포기하지 않도록, 실패한
  // 단계만 1회 재시도한다(루트 CLAUDE.md 서비스 원칙 6 — "AI 실패 시 fallback 필수" — 반영).
  // 재시도까지 실패하면 이 메서드가 던지는 예외가 CompletableFuture를 통해 CompletionException으로
  // 감싸져 buildResult()의 catch에서 잡힌다.
  private GeminiImageClient.GeneratedImage generateImageWithRetry(String description, CharacterType characterType) {
    try {
      return geminiImageClient.generateImage(description, characterType);
    } catch (Exception e) {
      log.warn("이미지 생성 1차 실패, 1회 재시도: description={}", description, e);
      return geminiImageClient.generateImage(description, characterType);
    }
  }

  private record StepResult(
    RoutineStepDraft.StepDraft stepDraft, GeminiImageClient.GeneratedImage generatedImage, String reusedImagePath
  ) {

  }

  public record RoutineGenerationResult(String title, List<GeneratedStep> steps) {

  }

  public record GeneratedStep(Integer order, String title, String description, String imagePath) {

  }

  public record RoutineQuestionResult(List<QuestionResultItem> questions) {

    public record QuestionResultItem(String question, List<OptionResult> options) {

      public record OptionResult(String emoji, String label) {

      }
    }
  }
}
