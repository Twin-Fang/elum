package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.notification.core.event.RoutineCompletedEvent;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// 이룸이 카드 진행 맞추기 (완료 집합 통째 동기화).
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineProgressService {

  private final RoutineRepository routineRepository;
  private final ProfileRepository profileRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final ApplicationEventPublisher eventPublisher;

  // 오프라인 퍼스트 클라이언트가 "이 일과의 완료 집합은 이것이다"를 통째로 보낸다.
  // **순서를 검사하지 않고** 최종 상태로 맞춘다 —
  // 오프라인 재전송에서 요청 하나가 거부돼 뒤가 연쇄로 무너지는 문제를
  // 구조적으로 없애기 위함. 별은 완료 수의 차이만큼만 움직여 같은 요청을 여러 번
  // 보내도 결과가 같다(멱등).
  @Transactional
  public RoutineResponse syncProgress(Caller caller, String routineId, List<String> completedStepIds) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.PROGRESS);
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
    int before = RoutineRules.countCompleted(steps);
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
    int after = RoutineRules.countCompleted(steps);

    // 완료 수의 차이만큼만 움직인다(멱등). 변화가 없으면 쿼리도 보내지 않는다.
    if (after != before) {
      profileRepository.addStars(routine.getProfile().getId(), after - before);
    }

    boolean allCompleted = !steps.isEmpty() && after == steps.size();
    if (allCompleted) {
      if (routine.getStatus() != RoutineStatus.COMPLETED) {
        routine.setStatus(RoutineStatus.COMPLETED);
        routine.setCompletedAt(now);
        // 이미 완료였던 일과의 재전송은 발행하지 않음
        publishRoutineCompleted(caller, routine);
      }
    } else {
      routine.setStatus(RoutineStatus.CONFIRMED);
      routine.setCompletedAt(null);
    }

    return RoutineResponse.from(routine);
  }

  /// 일과 완료 알림 이벤트 (요청자 제외는 보호자 기기일 때만: 이룸이 기기의 memberId 는 연결해 준 보호자)
  private void publishRoutineCompleted(Caller caller, Routine routine) {
    String actorMemberId = caller.isElumi() ? null : caller.memberId();
    eventPublisher.publishEvent(new RoutineCompletedEvent(routine.getId(), routine.getProfile().getId(),
      routine.getScheduledAt().toLocalDate(), actorMemberId));
  }

  private Routine getRoutineFor(Caller caller, String routineId, RoutineAction action) {
    return RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, action);
  }
}
