package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RewardUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.constant.RewardPreset;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.notification.core.event.RoutineSentEvent;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// 보호자가 일과를 승인·편집·정렬·삭제하는 쓰기. 생성·조회·진행은 각 서비스가 맡는다.
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineService {

  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineStepSpeechQueue routineStepSpeechQueue;
  private final RoutineGroupMembership routineGroupMembership;
  private final ApplicationEventPublisher eventPublisher;

  @Transactional
  public RoutineResponse confirm(Caller caller, String routineId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    if (routine.getStatus() != RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    routine.setStatus(RoutineStatus.CONFIRMED);
    // 승인한 날이 곧 그 일과를 하는 날이다.
    // 날짜 선택 UI를 두지 않는 대신, 미리 만들어 둔 일과를 그날 승인하면 그날 일과가 된다.
    // (아이 홈은 scheduledAt이 오늘인 CONFIRMED만 조회하므로 이 갱신이 없으면 미리 만든 일과가 뜨지 않는다)
    routine.setScheduledAt(LocalDate.now().atTime(9, 0));
    publishRoutineSent(caller, routine);
    return RoutineResponse.from(routine);
  }

  /// 보상만 수정한다. 일과를 만든 뒤에도 보호자가 바꿀 수 있어야
  /// "보호자가 관리한다"가 성립한다.
  @Transactional
  public RoutineResponse updateReward(Caller caller, String routineId, RewardUpdateRequest request) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    routine.setRewardText(RoutineRules.trimReward(request.rewardText()));
    routine.setRewardPresetKey(RewardPreset.normalize(request.rewardPresetKey()));
    return RoutineResponse.from(routine);
  }

  /// 지난 일과를 오늘 일과로 복제한다. **AI를 호출하지 않는다** —
  /// 매일 같은 준비를 하는 경우 탭 한 번으로 끝나야 재사용 가치가 있다.
  ///
  /// 원문(`rawInputText`·`sanitizedInputText`)은 복사하지 않는다. 원문을 계속 들고 다니지 않는다는
  /// 서비스 원칙에 맞추고, 복제본은 카드만 있으면 수행에 지장이 없다.
  @Transactional
  public RoutineResponse duplicate(Caller caller, String routineId) {
    Routine origin = getRoutineFor(caller, routineId, RoutineAction.COPY);
    Routine copy = RoutineRules.copyCardsOf(origin, caller.memberId());
    // 다시하기도 보낸 일과다: 맨 처음 원본을 가리켜 일과관리에 복제본이 원본처럼 쌓이지 않게 (#804)
    copy.setSourceRoutineId(origin.getSourceRoutineId() != null ? origin.getSourceRoutineId() : origin.getId());
    Routine savedCopy = RoutineRules.saveWithSpeech(routineRepository, routineStepSpeechQueue, copy);
    publishRoutineSent(caller, savedCopy);
    return RoutineResponse.from(savedCopy);
  }

  /// 일과 보냄 알림 이벤트 (요청자 제외는 보호자 기기일 때만)
  private void publishRoutineSent(Caller caller, Routine sentRoutine) {
    String actorMemberId = caller.isElumi() ? null : caller.memberId();
    eventPublisher.publishEvent(new RoutineSentEvent(sentRoutine.getId(), sentRoutine.getProfile().getId(),
      actorMemberId));
  }

  /// 이룸이가 **아직 시작하지 않은** 일과만 삭제한다.
  ///
  /// 임시저장(`PENDING_REVIEW`)과, 보냈지만 한 단계도 하지 않은 `CONFIRMED` 가 대상이다.
  /// 보호자 홈 `오늘 일과`의 삭제 버튼이 보낸 일과에도 동작해야 해서 임시저장 밖도 허용한다.
  ///
  /// 한 단계라도 한 일과는 지우지 않는다 — 수행률 추이의 원본 데이터이고,
  /// 보호자가 "이 날은 왜 못 했지"를 확인하는 근거다. 받은 별도 그 기록에 묶여 있다.
  @Transactional
  public void delete(Caller caller, String routineId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    if (!isDeletable(routine)) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    // 묶음 구성원이면 묶음에서 빼고 비면 묶음 풀기 (#806)
    routineGroupMembership.leaveGroup(routine);
    RoutineRules.deleteWithSpeech(routineRepository, routineStepSpeechQueue, routine);
  }

  /**
   * 일과 제목 고치기: 권한(만든 사람) > 검증(공백 · 30자) > 이 일과 제목만 교체 (#804)
   * 이 원본으로 보낸 일과의 제목은 그대로 둔다
   */
  @Transactional
  public RoutineResponse rename(Caller caller, String routineId, String title) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    String trimmedTitle = title == null ? "" : title.trim();
    if (trimmedTitle.isEmpty() || trimmedTitle.length() > RoutineRules.ROUTINE_TITLE_MAX_LENGTH) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    routine.setTitle(trimmedTitle);
    return RoutineResponse.from(routine);
  }

  private boolean isDeletable(Routine routine) {
    return switch (routine.getStatus()) {
      case PENDING_REVIEW -> true;
      case CONFIRMED -> RoutineRules.countCompleted(routine.getSteps()) == 0;
      default -> false;
    };
  }

  /**
   * 홈 목록의 순서를 통째로 다시 매긴다.
   *
   * <p>보낸 차례대로 1부터 번호를 붙인다. 일부만 보내 부분 갱신하는 방식이 아니라
   * <b>화면에 보이는 전체를 그대로 보낸다</b> — 부분 갱신은 두 사람이 동시에 순서를
   * 바꿀 때 뒤엉킨다.
   *
   * <p>하나라도 남의 것이거나 없는 것이 섞이면 <b>아무것도 바꾸지 않고</b> 거부한다.
   * 절반만 반영되면 화면과 서버의 순서가 어긋나 더 나쁘다.
   *
   * <p>그사이 목록이 늘거나 줄었으면 409 다 (다중 보호자 E24). 보호자가 여럿이면(또는 한 보호자가 휴대폰
   * 둘로) 옛 목록을 보고 동시에 순서를 보낼 수 있다. 비교 기준은 앱이 실제로 보내는 목록 — 보호자 홈의
   * 오늘 목록(단계가 있는 것)이다.
   */
  @Transactional
  public void reorder(Caller caller, List<String> routineIds) {
    if (routineIds == null || routineIds.isEmpty()) {
      return;
    }
    // 같은 값이 두 번 오면 번호가 겹쳐 순서가 뒤엉킨다.
    if (new HashSet<>(routineIds).size() != routineIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    List<Routine> routines = routineRepository.findAllById(routineIds);
    // 보낸 일과가 그사이 지워졌다 — 화면이 옛 목록이다.
    if (routines.size() != routineIds.size()) {
      throw new CustomException(ErrorCode.ROUTINE_ORDER_CONFLICT);
    }

    Map<String, Routine> byId = new HashMap<>();
    for (Routine routine : routines) {
      if (!routine.getProfile().getId().equals(profile.getId())) {
        throw new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED);
      }
      byId.put(routine.getId(), routine);
    }
    // 그사이 오늘 일과가 늘었다 — 보낸 목록으로는 새 일과의 자리를 알 수 없다.
    if (hasTodayRoutineMissingFrom(profile.getId(), byId.keySet())) {
      throw new CustomException(ErrorCode.ROUTINE_ORDER_CONFLICT);
    }

    for (int i = 0; i < routineIds.size(); i++) {
      byId.get(routineIds.get(i)).setDisplayOrder(i + 1);
    }
  }

  /**
   * 지금 오늘 목록에 있는데 보낸 목록에 없는 일과가 있는가.
   *
   * <p>앱은 오늘 목록 중 단계가 있는 것만 보내고, 방금 저장한 일과를 앞에 더해 보낸다
   * (today_routine_section.dart homeRoutinesProvider). 같은 기준으로 세야 멀쩡한 요청을 409 로 막지 않는다
   * — 보낸 목록에만 있는 일과는 문제가 아니다.
   */
  private boolean hasTodayRoutineMissingFrom(String profileId, Set<String> sent) {
    LocalDate today = LocalDate.now();
    return routineRepository.findTodayOrdered(
        profileId, List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED),
        today.atStartOfDay(), today.atTime(LocalTime.MAX))
      .stream()
      .filter(routine -> !routine.getSteps().isEmpty())
      .anyMatch(routine -> !sent.contains(routine.getId()));
  }

  /**
   * 일과 안의 행동 단계 순서를 바꾼다.
   *
   * <p>{@link #reorder}(일과 순서)와 같은 방식이다 — <b>화면에 보이는 전체를 그대로
   * 받아 통째로 다시 매긴다.</b> 부분 갱신은 두 곳에서 동시에 바꿀 때 뒤엉킨다.
   *
   * <p><b>하나라도 어긋나면 아무것도 바꾸지 않는다.</b> 절반만 반영되면 화면과 서버가
   * 어긋나 더 나쁘다 — 보호자는 자기가 바꾼 순서를 봤는데 이룸이 휴대폰에는 다른
   * 차례로 뜬다.
   */
  @Transactional
  public void reorderSteps(Caller caller, String routineId, List<String> stepIds) {
    if (stepIds == null || stepIds.isEmpty()) {
      return;
    }
    // 같은 값이 두 번 오면 번호가 겹쳐 순서가 뒤엉킨다.
    if (new HashSet<>(stepIds).size() != stepIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    List<RoutineStep> steps = routine.getSteps();

    // 일부만 보내면 빠진 단계의 차례가 어디인지 알 수 없다. 전체가 와야 한다.
    if (steps.size() != stepIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    Map<String, RoutineStep> byId = new HashMap<>();
    for (RoutineStep step : steps) {
      byId.put(step.getId(), step);
    }
    // 남의 일과 단계나 없는 단계가 섞이면 멈춘다.
    for (String stepId : stepIds) {
      if (!byId.containsKey(stepId)) {
        throw new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND);
      }
    }

    for (int i = 0; i < stepIds.size(); i++) {
      byId.get(stepIds.get(i)).setStepOrder(i + 1);
    }
  }

  private Routine getRoutineFor(Caller caller, String routineId, RoutineAction action) {
    return RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, action);
  }
}
