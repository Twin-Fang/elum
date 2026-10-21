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
import java.time.LocalDate;
import java.util.ArrayList;
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

  /// 보호자가 직접 고치는 일과 제목 최대 길이 (#804). 홈 카드 한 줄에 들어가는 길이다.
  static final int ROUTINE_TITLE_MAX_LENGTH = 30;

  /**
   * 카드 복사: 제목·언어·보상·단계(글·그림·픽토그램·예시 이미지) > 저장 전 새 일과 (오늘 09:00, CONFIRMED)
   * 복제·보내기·복사하기가 함께 쓴다. AI 를 부르지 않고 원문은 복사하지 않음 (서비스 원칙 5)
   */
  static Routine copyCardsOf(Routine origin, String createdBy) {
    Routine copy = new Routine();
    copy.setProfile(origin.getProfile());
    // 복제본은 복제한 사람의 일과다. 원본을 누가 만들었든 원본은 그대로 남는다.
    copy.setCreatedBy(createdBy);
    copy.setRawInputText(origin.getTitle());
    copy.setSanitizedInputText(origin.getTitle());
    copy.setTitle(origin.getTitle());
    // 카드 글이 원본 그대로이므로 언어도 원본을 따른다 (복제한 사람의 화면 언어가 아니다)
    copy.setLanguage(origin.getLanguage());
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
      // 픽토그램·예시 이미지도 그대로 — 같은 행동이면 같은 그림이고, 복제에서 AI 를 다시 부르지 않는다.
      copied.setPictogramId(step.getPictogramId());
      copied.setExampleImageId(step.getExampleImageId());
      copied.setCompleted(false);
      copiedSteps.add(copied);
    }
    copy.setSteps(copiedSteps);
    return copy;
  }

  /// 복사본 저장 > 커밋 뒤 단계 음성 예약. 음성 열쇠는 단계 폴더에 묶여 복사하지 않고 새로 만듦 (#675)
  static Routine saveWithSpeech(RoutineRepository routineRepository, RoutineStepSpeechQueue routineStepSpeechQueue,
    Routine copy) {
    Routine savedCopy = routineRepository.save(copy);
    routineStepSpeechQueue.enqueueAfterCommit(savedCopy.getSteps().stream().map(RoutineStep::getId).toList());
    return savedCopy;
  }

  /// 일과 행 삭제 > 커밋 뒤 단계 음성 삭제. 일과 삭제·일과관리 지우기가 함께 쓴다 (#804)
  /// 그림은 다른 일과와 공유될 수 있어 지우지 않음
  static void deleteWithSpeech(RoutineRepository routineRepository, RoutineStepSpeechQueue routineStepSpeechQueue,
    Routine routine) {
    List<String> stepIds = routine.getSteps().stream().map(RoutineStep::getId).toList();
    routineRepository.delete(routine);
    routineStepSpeechQueue.deleteStepsAfterCommit(stepIds);
  }

  static int countCompleted(List<RoutineStep> steps) {
    return (int) steps.stream().filter(step -> Boolean.TRUE.equals(step.getCompleted())).count();
  }

  /**
   * 일과 하나를 꺼내며 이 요청자가 이 동작을 해도 되는지 묻는다 (다중 보호자 명세 4-2).
   *
   * <p>판단은 {@link ProfileAccessGuard} 한 곳에서 한다. 보호자가 여럿이면 주인이 하나가 아니고 이룸이 휴대폰은
   * 연결로 이룸이가 정해지므로 "프로필의 주인 = 요청자"를 직접 비교하지 않는다.
   * 어떤 상태 검사보다 먼저 부른다 — 거절될 요청이 무엇도 바꾸지 않게.
   */
  static Routine routineFor(RoutineRepository routineRepository, ProfileAccessGuard profileAccessGuard,
    Caller caller, String routineId, RoutineAction action) {
    Routine routine = routineRepository.findById(routineId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_NOT_FOUND));
    profileAccessGuard.checkRoutine(caller, routine.getProfile().getId(), routine.getCreatedBy(), action);
    // 이룸이 토큰에는 승인 전 일과가 없는 것과 같다 — 존재 여부도 알리지 않는다.
    if (caller.isElumi() && routine.getStatus() == RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_NOT_FOUND);
    }
    return routine;
  }
}
