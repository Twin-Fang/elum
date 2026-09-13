package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RewardUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RecentRewardResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.constant.RewardPreset;
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
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
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

  /// 보상 설정 화면 상단에 띄울 "최근에 정한 보상" 개수.
  /// 많이 보여줘도 고르는 부담만 늘어난다.
  private static final int RECENT_REWARD_LIMIT = 3;

  /// 보호자 홈 "지난 일과" 노출 개수. 전부 내려주면 오늘 할 일이 묻힌다.
  private static final int PAST_ROUTINE_LIMIT = 10;

  /// 보상 텍스트 최대 길이. 아동 화면에 한 줄로 들어가야 하고,
  /// 길어질수록 글을 읽는 사용자에게도 부담이 된다.
  private static final int REWARD_TEXT_MAX_LENGTH = 100;

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

    // AI 호출 로그에 요청 회원을 연결한다. finally에서 반드시 비워 스레드 재사용 시
    // 다른 회원에게 새어 들어가지 않게 한다.
    AiCallContext.setMemberId(memberId);
    try {
      SensitiveInfoCheckResult checkResult = sensitiveInfoGuardService.check(request.rawInputText());
      RoutineAiPipeline.RoutineQuestionResult result =
        routineAiPipeline.generateQuestion(member.getNickname(), goals, checkResult.sanitizedText());
      List<RoutineQuestionResponse.QuestionItem> questions = result.questions().stream()
        .map(item -> new RoutineQuestionResponse.QuestionItem(item.question(), toOptionItems(item.options())))
        .toList();
      return new RoutineQuestionResponse(true, questions);
    } finally {
      AiCallContext.clear();
    }
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

    // AI 호출 로그에 요청 회원을 연결한다 (DLP·텍스트·이미지 병렬 생성까지 전파).
    SensitiveInfoCheckResult checkResult;
    RoutineAiPipeline.RoutineGenerationResult generation;
    AiCallContext.setMemberId(memberId);
    try {
      checkResult = sensitiveInfoGuardService.check(request.rawInputText());
      List<String> maskedAnswers = maskAnswers(request.answers());
      generation = routineAiPipeline.generateForCreate(
        checkResult.sanitizedText(), member.getNickname(), member.getSupportGoals(), maskedAnswers,
        member.getCharacter()
      );
    } finally {
      AiCallContext.clear();
    }

    Routine routine = new Routine();
    routine.setMember(member);
    routine.setRawInputText(request.rawInputText());
    routine.setSanitizedInputText(checkResult.sanitizedText());
    routine.setTitle(generation.title());
    routine.setScheduledAt(request.scheduledAt());
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    // 보상은 선택 항목이다. 보호자가 건너뛰면 null로 남고 아동 화면에서 보상 UI를 띄우지 않는다.
    routine.setRewardText(trimReward(request.rewardText()));
    routine.setRewardPresetKey(RewardPreset.normalize(request.rewardPresetKey()));
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
    // 승인한 날이 곧 그 일과를 하는 날이다.
    // 날짜 선택 UI를 두지 않는 대신, 미리 만들어 둔 일과를 그날 승인하면 그날 일과가 된다.
    // (아이 홈은 scheduledAt이 오늘인 CONFIRMED만 조회하므로 이 갱신이 없으면 미리 만든 일과가 뜨지 않는다)
    routine.setScheduledAt(LocalDate.now().atTime(9, 0));
    return RoutineResponse.from(routine);
  }

  /// 보상만 수정한다. 일과를 만든 뒤에도 보호자가 바꿀 수 있어야
  /// "보호자가 관리한다"가 성립한다 (2026-09-13 자문).
  @Transactional
  public RoutineResponse updateReward(String memberId, String routineId, RewardUpdateRequest request) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    routine.setRewardText(trimReward(request.rewardText()));
    routine.setRewardPresetKey(RewardPreset.normalize(request.rewardPresetKey()));
    return RoutineResponse.from(routine);
  }

  /// 최근에 사용한 보상 최대 3개. 보상 설정 화면 상단에 띄워 두 번째 일과부터는
  /// 탭 한 번으로 끝나게 한다 — 온보딩을 늘리지 않고 입력 부담을 줄이는 방법이다.
  public List<RecentRewardResponse> getRecentRewards(String memberId) {
    LinkedHashMap<String, RecentRewardResponse> unique = new LinkedHashMap<>();
    for (Routine routine : routineRepository
      .findTop30ByMemberIdAndRewardTextIsNotNullOrderByCreatedAtDesc(memberId)) {
      String text = routine.getRewardText();
      if (text == null || text.isBlank()) {
        continue;
      }
      // 같은 보상이 여러 일과에 쓰였으면 가장 최근 것 하나만 남긴다.
      unique.putIfAbsent(text, new RecentRewardResponse(text, routine.getRewardPresetKey()));
      if (unique.size() >= RECENT_REWARD_LIMIT) {
        break;
      }
    }
    return List.copyOf(unique.values());
  }

  /// 지난 일과를 오늘 일과로 복제한다. **AI를 호출하지 않는다** —
  /// 매일 같은 준비를 하는 경우 탭 한 번으로 끝나야 재사용 가치가 있다.
  ///
  /// 원문(`rawInputText`·`sanitizedInputText`)은 복사하지 않는다. 원문을 계속 들고 다니지 않는다는
  /// 서비스 원칙에 맞추고, 복제본은 카드만 있으면 수행에 지장이 없다.
  @Transactional
  public RoutineResponse duplicate(String memberId, String routineId) {
    Routine origin = getOwnedRoutine(memberId, routineId);

    Routine copy = new Routine();
    copy.setMember(origin.getMember());
    copy.setRawInputText(origin.getTitle());
    copy.setSanitizedInputText(origin.getTitle());
    copy.setTitle(origin.getTitle());
    copy.setScheduledAt(LocalDate.now().atTime(9, 0));
    // 이미 검토를 거친 카드라 다시 승인받지 않는다. 바로 오늘 할 일이 된다.
    copy.setStatus(RoutineStatus.CONFIRMED);
    copy.setRewardText(origin.getRewardText());
    copy.setRewardPresetKey(origin.getRewardPresetKey());

    List<RoutineStep> copiedSteps = new ArrayList<>();
    for (RoutineStep step : origin.getSteps()) {
      RoutineStep copied = new RoutineStep();
      copied.setRoutine(copy);
      copied.setStepOrder(step.getStepOrder());
      copied.setTitle(step.getTitle());
      copied.setDescription(step.getDescription());
      // 이미지는 새로 만들지 않고 그대로 쓴다 — 재생성은 비용이고 같은 행동이면 같은 그림이면 된다.
      copied.setImagePath(step.getImagePath());
      copied.setCompleted(false);
      copiedSteps.add(copied);
    }
    copy.setSteps(copiedSteps);

    return RoutineResponse.from(routineRepository.save(copy));
  }

  /// 임시저장(`PENDING_REVIEW`) 일과만 삭제한다.
  ///
  /// 승인된 일과는 지우지 않는다 — 수행률 추이의 원본 데이터이고,
  /// 보호자가 "이 날은 왜 못 했지"를 확인하는 근거다.
  @Transactional
  public void delete(String memberId, String routineId) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    if (routine.getStatus() != RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    routineRepository.delete(routine);
  }

  /// 보호자 홈 "지난 일과" — 오늘 이전 것만 최신순 10개.
  /// 전부 내려주면 목록이 계속 쌓여 오늘 할 일이 묻힌다.
  public List<RoutineResponse> getPastRoutines(String memberId) {
    return routineRepository
      .findAllByMemberIdAndScheduledAtBeforeOrderByScheduledAtDesc(
        memberId, LocalDate.now().atStartOfDay())
      .stream()
      .limit(PAST_ROUTINE_LIMIT)
      .map(RoutineResponse::from)
      .toList();
  }

  /// 보호자 홈 "임시저장" — 카드는 만들었지만 아직 아이에게 보내지 않은 일과.
  public List<RoutineResponse> getDraftRoutines(String memberId) {
    return routineRepository
      .findAllByMemberIdAndStatusOrderByCreatedAtDesc(memberId, RoutineStatus.PENDING_REVIEW)
      .stream()
      .map(RoutineResponse::from)
      .toList();
  }

  /// 보상 텍스트 정리. 공백만 남으면 없는 것으로 본다.
  /// 길이는 화면에서 막지만 서버도 잘라둔다 — 클라이언트만 믿지 않는다.
  private String trimReward(String text) {
    if (text == null) {
      return null;
    }
    String trimmed = text.trim();
    if (trimmed.isEmpty()) {
      return null;
    }
    return trimmed.length() > REWARD_TEXT_MAX_LENGTH
      ? trimmed.substring(0, REWARD_TEXT_MAX_LENGTH)
      : trimmed;
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

  // 오프라인 퍼스트 클라이언트가 "이 일과의 완료 집합은 이것이다"를 통째로 보낸다.
  // 단계별 complete/cancel과 달리 **순서를 검사하지 않고** 최종 상태로 맞춘다 —
  // 오프라인 재전송에서 요청 하나가 거부돼 뒤가 연쇄로 무너지는 문제(이슈 #139)를
  // 구조적으로 없애기 위함. 별은 완료 수의 차이만큼만 움직여 같은 요청을 여러 번
  // 보내도 결과가 같다(멱등).
  @Transactional
  public RoutineResponse syncProgress(String memberId, String routineId, List<String> completedStepIds) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    if (routine.getStatus() != RoutineStatus.CONFIRMED && routine.getStatus() != RoutineStatus.COMPLETED) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }

    List<RoutineStep> steps = routine.getSteps();
    Set<String> target = new HashSet<>(completedStepIds);
    Set<String> known = steps.stream().map(RoutineStep::getId).collect(Collectors.toSet());
    if (!known.containsAll(target)) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND);
    }

    LocalDateTime now = LocalDateTime.now();
    int before = countCompleted(steps);
    for (RoutineStep step : steps) {
      boolean shouldComplete = target.contains(step.getId());
      boolean isCompleted = Boolean.TRUE.equals(step.getCompleted());
      if (shouldComplete && !isCompleted) {
        step.setCompleted(true);
        step.setCompletedAt(now);
      } else if (!shouldComplete && isCompleted) {
        step.setCompleted(false);
        step.setCompletedAt(null);
      }
      // 이미 완료였고 여전히 완료면 completedAt을 건드리지 않는다 — 처음 완료한 시각이 기록이다.
    }
    int after = countCompleted(steps);

    Member member = routine.getMember();
    member.setTotalStars(Math.max(0, member.getTotalStars() + (after - before)));

    boolean allCompleted = !steps.isEmpty() && after == steps.size();
    if (allCompleted) {
      if (routine.getStatus() != RoutineStatus.COMPLETED) {
        routine.setStatus(RoutineStatus.COMPLETED);
        routine.setCompletedAt(now);
      }
    } else {
      routine.setStatus(RoutineStatus.CONFIRMED);
      routine.setCompletedAt(null);
    }

    return RoutineResponse.from(routine);
  }

  private int countCompleted(List<RoutineStep> steps) {
    return (int) steps.stream().filter(step -> Boolean.TRUE.equals(step.getCompleted())).count();
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
