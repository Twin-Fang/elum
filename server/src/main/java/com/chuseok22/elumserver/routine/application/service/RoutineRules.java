package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.List;

/// 일과 서비스들이 함께 쓰는 규칙. 상태가 없어 정적 메서드로 둔다.
final class RoutineRules {

  private RoutineRules() {
  }

  /// 보상 텍스트 최대 길이. 아동 화면에 한 줄로 들어가야 하고,
  /// 길어질수록 글을 읽는 사용자에게도 부담이 된다.
  private static final int REWARD_TEXT_MAX_LENGTH = 100;

  /// 보상 텍스트 정리. 공백만 남으면 없는 것으로 본다.
  /// 길이는 화면에서 막지만 서버도 잘라둔다 — 클라이언트만 믿지 않는다.
  static String trimReward(String text) {
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

  static int countCompleted(List<RoutineStep> steps) {
    return (int) steps.stream().filter(step -> Boolean.TRUE.equals(step.getCompleted())).count();
  }

  /**
   * 일과 하나를 꺼내며 이 요청자가 이 동작을 해도 되는지 묻는다 (다중 보호자 명세 4-2).
   *
   * <p>판단은 {@link ProfileAccessGuard} 한 곳에서 한다. 예전에는 "프로필의 주인 = 요청자"를 여기서 직접
   * 비교했는데, 보호자가 여럿이 되면 주인이 하나가 아니고 이룸이 휴대폰은 연결로 이룸이가 정해진다.
   * 어떤 상태 검사보다 먼저 부른다 — 거절될 요청이 무엇도 바꾸지 않게.
   */
  static Routine routineFor(RoutineRepository routineRepository, ProfileAccessGuard profileAccessGuard,
    Caller caller, String routineId, RoutineAction action) {
    Routine routine = routineRepository.findById(routineId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_NOT_FOUND));
    profileAccessGuard.checkRoutine(caller, routine.getProfile().getId(), routine.getCreatedBy(), action);
    // 이룸이 토큰에는 승인 전 일과가 없는 것과 같다 — 존재 여부도 알리지 않는다 (#356).
    if (caller.isElumi() && routine.getStatus() == RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_NOT_FOUND);
    }
    return routine;
  }
}
