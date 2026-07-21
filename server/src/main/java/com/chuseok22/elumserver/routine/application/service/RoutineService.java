package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineSuggestionCatalog;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineRequestCooldownGuard;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
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
  private final RoutineRequestCooldownGuard routineRequestCooldownGuard;

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
      .map(item -> new RoutineQuestionResponse.QuestionItem(item.question(), toOptionItems(item.options())))
      .toList();
    return new RoutineQuestionResponse(true, questions);
  }

  private List<RoutineQuestionResponse.QuestionItem.OptionItem> toOptionItems(
    List<RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult> options
  ) {
    return options.stream()
      .map(option -> new RoutineQuestionResponse.QuestionItem.OptionItem(option.emoji(), option.label()))
      .toList();
  }

  // Gemini 호출(수십 초 소요 가능) 동안 DB 커넥션을 점유하지 않도록 클래스 레벨
  // readOnly 트랜잭션을 이 메서드에서만 명시적으로 중단시킨다. routine은 신규 엔티티라
  // 지연 로딩 걱정이 없으므로 안전하다.
  @Transactional(propagation = Propagation.NOT_SUPPORTED)
  public RoutineResponse create(String memberId, RoutineCreateRequest request) {
    routineRequestCooldownGuard.guard(memberId);

    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    SensitiveInfoCheckResult checkResult = sensitiveInfoGuardService.check(request.rawInputText());
    List<String> maskedAnswers = maskAnswers(request.answers());
    RoutineAiPipeline.RoutineGenerationResult generation = routineAiPipeline.generateForCreate(
      checkResult.sanitizedText(), member.getNickname(), member.getSupportGoals(), maskedAnswers,
      member.getCharacter()
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
  public RoutineResponse updateStep(
    String memberId, String routineId, String stepId, RoutineStepUpdateRequest request
  ) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    if (routine.getStatus() != RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }

    RoutineStep targetStep = routine.getSteps().stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    targetStep.setTitle(request.title());
    targetStep.setDescription(request.description());

    return RoutineResponse.from(routine);
  }

  @Transactional
  public RoutineResponse deleteStep(String memberId, String routineId, String stepId) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    if (routine.getStatus() != RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }

    List<RoutineStep> steps = routine.getSteps();
    if (steps.size() <= 1) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_MIN_COUNT);
    }

    RoutineStep targetStep = steps.stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    steps.remove(targetStep);
    renumberSteps(steps);

    return RoutineResponse.from(routine);
  }

  // 삭제 후 남은 단계들의 stepOrder를 1..N으로 다시 채운다. PENDING_REVIEW 단계는 완료 이력이
  // 전혀 없어 재채번이 완료/취소 순서 검증 로직과 충돌하지 않는다.
  private void renumberSteps(List<RoutineStep> steps) {
    List<RoutineStep> ordered = steps.stream()
      .sorted(Comparator.comparingInt(RoutineStep::getStepOrder))
      .toList();
    for (int i = 0; i < ordered.size(); i++) {
      ordered.get(i).setStepOrder(i + 1);
    }
  }

  public RoutineResponse getRoutine(String memberId, String routineId) {
    return RoutineResponse.from(getOwnedRoutine(memberId, routineId));
  }

  public List<RoutineResponse> getMyRoutines(String memberId) {
    return routineRepository.findAllByMemberId(memberId).stream()
      .map(RoutineResponse::from)
      .toList();
  }

  // 아이 홈 화면 "오늘 할 일" 리스트용. 보호자 승인 전(PENDING_REVIEW) 일과는 제외하고,
  // scheduledAt이 오늘(KST) 안에 있는 CONFIRMED/COMPLETED 일과만 예정 시각 순으로 반환한다.
  public List<RoutineResponse> getTodayRoutines(String memberId) {
    LocalDate today = LocalDate.now();
    LocalDateTime startOfDay = today.atStartOfDay();
    LocalDateTime endOfDay = today.atTime(LocalTime.MAX);
    List<Routine> routines = routineRepository.findAllByMemberIdAndStatusInAndScheduledAtBetweenOrderByScheduledAtAsc(
      memberId, List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED), startOfDay, endOfDay
    );
    return routines.stream().map(RoutineResponse::from).toList();
  }

  // count는 프론트가 요청한 반환 개수다. 1 미만이거나 카탈로그 전체 개수를 초과하면
  // 항상 이 범위 안에서만 뽑을 수 있으므로 잘못된 요청으로 간주해 거부한다.
  public List<RoutineSuggestionResponse> getSuggestions(int count) {
    if (count < 1 || count > RoutineSuggestionCatalog.ALL.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    List<RoutineSuggestionResponse> pool = new ArrayList<>(RoutineSuggestionCatalog.ALL);
    Collections.shuffle(pool);
    return List.copyOf(pool.subList(0, count));
  }

  public RoutineImageStorage.ImageContent getStepImage(String memberId, String routineId, String stepId) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    RoutineStep targetStep = routine.getSteps().stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
    // 이미지 생성에 실패해 imagePath가 null인 단계는 이미지가 없다. Path.of(null) NPE 대신
    // 404로 명확히 응답한다(클라이언트는 이미지 자리를 비워 렌더링).
    if (targetStep.getImagePath() == null) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND);
    }
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
        entity.setTitle(step.title());
        entity.setImagePath(step.imagePath());
        return entity;
      })
      .toList();
  }

  // 답변(answers)도 rawInputText와 동일한 로컬 LLM 마스킹 게이트를 거치게 한다. 항목별로
  // 개별 마스킹해 배열 구조를 유지해야 Gemini에 additionalAnswers 배열 그대로 전달할 수
  // 있다(마스킹 전 하나로 합쳐버리면 Gemini 쪽에서 배열 구조를 잃는다, fable5 검토에서
  // 발견 — 이전에는 answers를 comma로 합친 뒤 한 번에 마스킹해 문자열 하나로 전달했다).
  // 로컬 LLM 호출을 답변 개수만큼 순차로 하면 fail-open 타임아웃이 그대로 누적되므로,
  // RoutineAiPipeline의 이미지 생성 병렬화와 동일하게 가상 스레드로 병렬 호출해 지연을 1회
  // 타임아웃 수준으로 묶는다(fable5 검토에서 발견).
  private List<String> maskAnswers(List<String> answers) {
    if (answers == null || answers.isEmpty()) {
      return List.of();
    }
    ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
    try {
      List<CompletableFuture<String>> futures = answers.stream()
        .map(answer -> CompletableFuture.supplyAsync(
          () -> sensitiveInfoGuardService.check(answer).sanitizedText(), executor
        ))
        .toList();
      return futures.stream().map(CompletableFuture::join).toList();
    } finally {
      executor.shutdown();
    }
  }
}
