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
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;
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

  // 옛 호출부(RoutineService)가 Task 6에서 새 오버로드로 옮겨갈 때까지 남겨두는 임시 위임
  // 메서드. Task 6 완료 후에는 더 이상 쓰이지 않는다.
  public RoutineGenerationResult generateForCreate(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, String maskedAnswers
  ) {
    return generateForCreate(sanitizedInputText, nickname, supportGoals, maskedAnswers, null);
  }

  public RoutineGenerationResult generateForCreate(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, String maskedAnswers,
    CharacterType characterType
  ) {
    RoutineStepDraft draft = parseDraft(
      () -> geminiTextClient.generate(sanitizedInputText, nickname, supportGoals, maskedAnswers)
    );
    return buildResult(draft, characterType);
  }

  // 옛 호출부(RoutineService)가 Task 6에서 새 오버로드로 옮겨갈 때까지 남겨두는 임시 위임
  // 메서드. Task 6 완료 후에는 더 이상 쓰이지 않는다.
  public RoutineGenerationResult generateForRevise(
    List<RoutineStepDraft.StepDraft> previousSteps, String maskedFeedback,
    String nickname, Set<SupportGoal> supportGoals
  ) {
    return generateForRevise(previousSteps, maskedFeedback, nickname, supportGoals, null);
  }

  public RoutineGenerationResult generateForRevise(
    List<RoutineStepDraft.StepDraft> previousSteps, String maskedFeedback,
    String nickname, Set<SupportGoal> supportGoals, CharacterType characterType
  ) {
    RoutineStepDraft draft =
      parseDraft(() -> geminiTextClient.revise(previousSteps, maskedFeedback, nickname, supportGoals));
    return buildResult(draft, characterType);
  }

  // 도움 목표 기반 추가 질문 생성. Gemini 호출/파싱이 실패하면 예외를 던지지 않고
  // 목표 조합별 고정 매핑으로 대체한다(fail-open) — 다른 생성 메서드와 달리 이 흐름은
  // 실패해도 사용자에게 에러를 노출하지 않기로 설계에서 결정했다.
  public RoutineQuestionResult generateQuestion(
    String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText
  ) {
    try {
      GeminiGenerateContentResponse response =
        geminiTextClient.generateQuestion(nickname, supportGoals, sanitizedInputText);
      String json = response.candidates().get(0).content().parts().get(0).text();
      RoutineQuestionDraft draft = objectMapper.readValue(json, RoutineQuestionDraft.class);
      if (draft.questions() == null || draft.questions().isEmpty()) {
        throw new IllegalStateException("Gemini가 questions 없이 응답함");
      }
      List<RoutineQuestionResult.QuestionResultItem> questions = draft.questions().stream()
        .filter(item -> item.question() != null && !item.question().isBlank()
          && item.options() != null && !item.options().isEmpty())
        .map(item -> new RoutineQuestionResult.QuestionResultItem(item.question(), item.options()))
        .toList();
      if (questions.isEmpty()) {
        throw new IllegalStateException("Gemini가 유효한 question/options 없이 응답함");
      }
      return new RoutineQuestionResult(questions);
    } catch (Exception e) {
      log.warn("Gemini 추가 질문 생성 실패, 고정 매핑으로 대체", e);
      return fallbackQuestion(supportGoals);
    }
  }

  // 선택한 도움 목표 각각에 대해 개별 질문을 만든다(여러 목표를 하나로 합치지 않음).
  private RoutineQuestionResult fallbackQuestion(Set<SupportGoal> supportGoals) {
    List<RoutineQuestionResult.QuestionResultItem> questions = new ArrayList<>();
    if (supportGoals.contains(SupportGoal.PREPARE_ITEMS)) {
      questions.add(new RoutineQuestionResult.QuestionResultItem(
        "꼭 챙겨야 하는 준비물이 있나요?",
        List.of("우산", "우비", "장화", "여벌 양말", "작은 수건")
      ));
    }
    if (supportGoals.contains(SupportGoal.PREPARE_NEW)) {
      questions.add(new RoutineQuestionResult.QuestionResultItem(
        "평소와 다르게 준비해야 하는 점이 있나요?",
        List.of("시간 변경", "장소 변경", "동행자 변경", "날씨/환경 변화", "직접 입력")
      ));
    }
    return new RoutineQuestionResult(questions);
  }

  // Gemini 호출 자체(RestClient의 RestClientResponseException/ResourceAccessException 등)와
  // 응답 파싱을 하나의 try 블록에서 함께 처리한다. 호출과 파싱을 분리해두면 호출 실패가
  // 이 메서드 밖으로 그대로 전파돼 GlobalExceptionHandler의 범용 500 처리로 새어나가
  // ROUTINE_AI_GENERATION_FAILED(502)로 변환되지 않는 문제가 있었다(fable5 검토에서 발견).
  private RoutineStepDraft parseDraft(Supplier<GeminiGenerateContentResponse> call) {
    try {
      GeminiGenerateContentResponse response = call.get();
      String json = response.candidates().get(0).content().parts().get(0).text();
      RoutineStepDraft draft = objectMapper.readValue(json, RoutineStepDraft.class);
      // title은 Routine.title이 NOT NULL이라, 스키마 위반으로 누락되면 DB 제약 위반(500)이
      // 아니라 여기서 먼저 502로 처리한다(fable5 검토에서 발견).
      if (draft.title() == null || draft.title().isBlank()) {
        log.warn("Gemini가 title 없이 응답함");
        throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
      }
      if (draft.steps() == null || draft.steps().isEmpty() || draft.steps().size() > MAX_STEPS) {
        log.warn("Gemini가 반환한 단계 수가 허용 범위를 벗어남: {}",
          draft.steps() == null ? 0 : draft.steps().size());
        throw new CustomException(ErrorCode.ROUTINE_STEP_LIMIT_EXCEEDED);
      }
      return normalizeOrder(draft);
    } catch (CustomException e) {
      throw e;
    } catch (Exception e) {
      log.warn("Gemini 텍스트 생성/응답 파싱 실패", e);
      throw new CustomException(ErrorCode.ROUTINE_AI_GENERATION_FAILED);
    }
  }

  // 모델이 order를 중복/누락되게 반환해도(예: 1,1,2) 이미지 파일 경로가 충돌하지 않도록,
  // 배열 순서를 유일한 기준으로 삼아 order를 1부터 다시 채번한다(fable5 검토에서 발견).
  private RoutineStepDraft normalizeOrder(RoutineStepDraft draft) {
    List<RoutineStepDraft.StepDraft> normalized = new ArrayList<>();
    for (int i = 0; i < draft.steps().size(); i++) {
      normalized.add(new RoutineStepDraft.StepDraft(i + 1, draft.steps().get(i).description()));
    }
    return new RoutineStepDraft(draft.title(), normalized);
  }

  private RoutineGenerationResult buildResult(RoutineStepDraft draft, CharacterType characterType) {
    String batchId = UUID.randomUUID().toString();
    ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
    try {
      List<CompletableFuture<StepImage>> futures = draft.steps().stream()
        .map(stepDraft -> CompletableFuture.supplyAsync(
          () -> new StepImage(
            stepDraft, geminiImageClient.generateImage(stepDraft.description(), characterType)
          ), executor
        ))
        .toList();

      // 이미지 생성(HTTP 호출)까지만 병렬로 완료시키고, 파일 저장은 전부 성공한 뒤에만
      // 수행한다 — 일부 단계만 실패해도 이미 디스크에 쓰인 고아 이미지가 남지 않도록
      // 하기 위함(스펙: "모든 단계가 성공적으로 생성된 뒤에만 저장", fable5 검토에서 발견).
      // futures는 draft.steps() 순서 그대로이고 normalizeOrder가 이미 1..N으로 정렬해뒀으므로
      // 별도 정렬 없이도 steps는 순서대로 나온다.
      List<StepImage> stepImages = futures.stream().map(CompletableFuture::join).toList();

      List<GeneratedStep> steps = stepImages.stream()
        .map(stepImage -> new GeneratedStep(
          stepImage.stepDraft().order(),
          stepImage.stepDraft().description(),
          routineImageStorage.save(batchId, stepImage.stepDraft().order(), stepImage.image())
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

  private record StepImage(RoutineStepDraft.StepDraft stepDraft, GeminiImageClient.GeneratedImage image) {

  }

  public record RoutineGenerationResult(String title, List<GeneratedStep> steps) {

  }

  public record GeneratedStep(Integer order, String description, String imagePath) {

  }

  public record RoutineQuestionResult(List<QuestionResultItem> questions) {

    public record QuestionResultItem(String question, List<String> options) {

    }
  }
}
