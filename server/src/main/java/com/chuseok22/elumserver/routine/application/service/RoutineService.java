package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.RoutineStepDraft;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineReviseRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineSuggestionCatalog;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineService {

  private final RoutineRepository routineRepository;
  private final MemberRepository memberRepository;
  private final SensitiveInfoGuardService sensitiveInfoGuardService;
  private final RoutineAiPipeline routineAiPipeline;
  private final RoutineImageStorage routineImageStorage;

  private static final int SUGGESTION_COUNT = 4;

  // 질문 생성은 실패해도 항상 200을 반환한다(fail-open, RoutineAiPipeline.generateQuestion 참고).
  // Gemini 호출(수 초 소요 가능) 동안 DB 커넥션을 점유하지 않도록 create()와 동일하게
  // 클래스 레벨 readOnly 트랜잭션을 중단시킨다.
  @Transactional(propagation = Propagation.NOT_SUPPORTED)
  public RoutineQuestionResponse generateQuestion(String memberId, RoutineQuestionRequest request) {
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    Set<SupportGoal> goals = member.getSupportGoals();
    boolean needsQuestion = goals.contains(SupportGoal.PREPARE_ITEMS) || goals.contains(SupportGoal.PREPARE_NEW);
    if (!needsQuestion) {
      return new RoutineQuestionResponse(false, List.of());
    }

    SensitiveInfoCheckResult checkResult = sensitiveInfoGuardService.check(request.rawInputText());
    RoutineAiPipeline.RoutineQuestionResult result =
      routineAiPipeline.generateQuestion(member.getNickname(), goals, checkResult.sanitizedText());
    List<RoutineQuestionResponse.QuestionItem> questions = result.questions().stream()
      .map(item -> new RoutineQuestionResponse.QuestionItem(item.question(), item.options()))
      .toList();
    return new RoutineQuestionResponse(true, questions);
  }

  // Gemini 호출(수십 초 소요 가능) 동안 DB 커넥션을 점유하지 않도록 클래스 레벨
  // readOnly 트랜잭션을 이 메서드에서만 명시적으로 중단시킨다. routine은 신규 엔티티라
  // 지연 로딩 걱정이 없으므로 안전하다.
  @Transactional(propagation = Propagation.NOT_SUPPORTED)
  public RoutineResponse create(String memberId, RoutineCreateRequest request) {
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    SensitiveInfoCheckResult checkResult = sensitiveInfoGuardService.check(request.rawInputText());
    String maskedAnswers = maskAnswers(request.answers());
    RoutineAiPipeline.RoutineGenerationResult generation = routineAiPipeline.generateForCreate(
      checkResult.sanitizedText(), member.getNickname(), member.getSupportGoals(), maskedAnswers
    );

    Routine routine = new Routine();
    routine.setMember(member);
    routine.setRawInputText(request.rawInputText());
    routine.setSanitizedInputText(checkResult.sanitizedText());
    routine.setTitle(generation.title());
    routine.setScheduledAt(request.scheduledAt());
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    routine.setSteps(toStepEntities(routine, generation.steps()));

    return RoutineResponse.from(routineRepository.save(routine));
  }

  @Transactional
  public RoutineResponse revise(String memberId, String routineId, RoutineReviseRequest request) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    Member member = routine.getMember();

    SensitiveInfoCheckResult checkResult = sensitiveInfoGuardService.check(request.feedback());
    List<RoutineStepDraft.StepDraft> previousSteps = maskPreviousSteps(routine.getSteps());
    RoutineAiPipeline.RoutineGenerationResult generation = routineAiPipeline.generateForRevise(
      previousSteps, checkResult.sanitizedText(), member.getNickname(), member.getSupportGoals()
    );

    // orphanRemoval이 정상 동작하려면 컬렉션 참조를 새로 바꾸지 않고(setSteps) 기존
    // 영속 컬렉션을 clear() 후 addAll()로 채워야 한다.
    routine.getSteps().clear();
    routine.getSteps().addAll(toStepEntities(routine, generation.steps()));
    routine.setTitle(generation.title());
    routine.setRevisionFeedback(request.feedback());
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    routine.setCompletedAt(null);

    // routine은 이미 영속 상태라 save()는 불필요하지만, flush 없이는 cascade=ALL로
    // 추가된 신규 RoutineStep들의 UUID가 커밋 전까지 채워지지 않아 응답에 id:null이
    // 노출된다(수동 검증 중 발견).
    routineRepository.flush();
    return RoutineResponse.from(routine);
  }

  @Transactional
  public RoutineResponse confirm(String memberId, String routineId) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    if (routine.getStatus() != RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    routine.setStatus(RoutineStatus.CONFIRMED);
    return RoutineResponse.from(routine);
  }

  @Transactional
  public RoutineResponse completeStep(String memberId, String routineId, String stepId) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    if (routine.getStatus() != RoutineStatus.CONFIRMED) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }

    List<RoutineStep> steps = routine.getSteps();
    RoutineStep targetStep = steps.stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    if (Boolean.TRUE.equals(targetStep.getCompleted())) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_ALREADY_COMPLETED);
    }

    boolean hasIncompletePriorStep = steps.stream()
      .filter(step -> step.getStepOrder() < targetStep.getStepOrder())
      .anyMatch(step -> !Boolean.TRUE.equals(step.getCompleted()));
    if (hasIncompletePriorStep) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_ORDER_VIOLATION);
    }

    LocalDateTime now = LocalDateTime.now();
    targetStep.setCompleted(true);
    targetStep.setCompletedAt(now);
    routine.getMember().setTotalStars(routine.getMember().getTotalStars() + 1);

    boolean allCompleted = steps.stream().allMatch(step -> Boolean.TRUE.equals(step.getCompleted()));
    if (allCompleted) {
      routine.setStatus(RoutineStatus.COMPLETED);
      routine.setCompletedAt(now);
    }

    return RoutineResponse.from(routine);
  }

  @Transactional
  public RoutineResponse cancelStep(String memberId, String routineId, String stepId) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    if (routine.getStatus() != RoutineStatus.CONFIRMED && routine.getStatus() != RoutineStatus.COMPLETED) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }

    List<RoutineStep> steps = routine.getSteps();
    RoutineStep targetStep = steps.stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    if (!Boolean.TRUE.equals(targetStep.getCompleted())) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_NOT_COMPLETED);
    }

    boolean hasLaterCompletedStep = steps.stream()
      .filter(step -> step.getStepOrder() > targetStep.getStepOrder())
      .anyMatch(step -> Boolean.TRUE.equals(step.getCompleted()));
    if (hasLaterCompletedStep) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_CANCEL_ORDER_VIOLATION);
    }

    targetStep.setCompleted(false);
    targetStep.setCompletedAt(null);
    routine.getMember().setTotalStars(routine.getMember().getTotalStars() - 1);

    if (routine.getStatus() == RoutineStatus.COMPLETED) {
      routine.setStatus(RoutineStatus.CONFIRMED);
      routine.setCompletedAt(null);
    }

    return RoutineResponse.from(routine);
  }

  @Transactional
  public RoutineResponse updateStepDescription(
    String memberId, String routineId, String stepId, RoutineStepUpdateRequest request
  ) {
    Routine routine = getOwnedRoutine(memberId, routineId);

    RoutineStep targetStep = routine.getSteps().stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    targetStep.setDescription(request.description());

    return RoutineResponse.from(routine);
  }

  public RoutineResponse getRoutine(String memberId, String routineId) {
    return RoutineResponse.from(getOwnedRoutine(memberId, routineId));
  }

  public List<RoutineResponse> getMyRoutines(String memberId) {
    return routineRepository.findAllByMemberId(memberId).stream()
      .map(RoutineResponse::from)
      .toList();
  }

  public List<RoutineSuggestionResponse> getSuggestions() {
    List<RoutineSuggestionResponse> pool = new ArrayList<>(RoutineSuggestionCatalog.ALL);
    Collections.shuffle(pool);
    return List.copyOf(pool.subList(0, SUGGESTION_COUNT));
  }

  public RoutineImageStorage.ImageContent getStepImage(String memberId, String routineId, String stepId) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    RoutineStep targetStep = routine.getSteps().stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
    return routineImageStorage.read(targetStep.getImagePath());
  }

  private Routine getOwnedRoutine(String memberId, String routineId) {
    Routine routine = routineRepository.findById(routineId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_NOT_FOUND));
    if (!routine.getMember().getId().equals(memberId)) {
      throw new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED);
    }
    return routine;
  }

  private List<RoutineStep> toStepEntities(Routine routine, List<RoutineAiPipeline.GeneratedStep> steps) {
    return steps.stream()
      .map(step -> {
        RoutineStep entity = new RoutineStep();
        entity.setRoutine(routine);
        entity.setStepOrder(step.order());
        entity.setDescription(step.description());
        entity.setImagePath(step.imagePath());
        return entity;
      })
      .toList();
  }

  // 답변(answers)도 rawInputText와 동일한 로컬 LLM 마스킹 게이트를 거치게 한다.
  // 마스킹 없이 그대로 Gemini로 보내면 보호자가 답변에 직접 입력한 민감정보가
  // 새어나갈 수 있다(fable5 최종 검토에서 발견).
  private String maskAnswers(List<String> answers) {
    if (answers == null || answers.isEmpty()) {
      return null;
    }
    String joined = String.join(", ", answers);
    return sensitiveInfoGuardService.check(joined).sanitizedText();
  }

  // description은 이제 보호자가 PATCH .../steps/{stepId}로 직접 입력한 원문일 수 있으므로
  // feedback과 동일하게 마스킹 게이트를 거친 뒤에야 Gemini로 보낸다(fable5 검토에서 발견 —
  // 이전에는 항상 AI가 생성한 텍스트라 마스킹이 없었다). 단계마다 순차 호출하면 로컬 LLM이
  // 느리거나 응답이 없을 때(fail-open 타임아웃) 단계 수만큼 지연이 누적되므로,
  // RoutineAiPipeline의 이미지 생성과 동일하게 가상 스레드로 병렬 호출해 지연을 1회
  // 타임아웃 수준으로 묶는다(수동 검증 중 발견).
  private List<RoutineStepDraft.StepDraft> maskPreviousSteps(List<RoutineStep> steps) {
    ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
    try {
      List<CompletableFuture<RoutineStepDraft.StepDraft>> futures = steps.stream()
        .map(step -> CompletableFuture.supplyAsync(
          () -> new RoutineStepDraft.StepDraft(
            step.getStepOrder(), sensitiveInfoGuardService.check(step.getDescription()).sanitizedText()
          ),
          executor
        ))
        .toList();
      return futures.stream().map(CompletableFuture::join).toList();
    } finally {
      executor.shutdown();
    }
  }
}
