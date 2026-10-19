package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.notification.core.event.RoutineSentEvent;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 일과관리(원본 보관함) 쓰기: 보내기, 복사하기, 지우기 (#804). 묶음째 보내기·복사도 여기 카드 복사를 씀 (#806)
 * 원본 = sourceRoutineId 가 null 인 일과. 보내기는 원본의 카드를 복사해 오늘 일과를 만든다 (AI 호출 없음)
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineLibraryService {

  /// 복사본 제목 최대 길이. routine.title 컬럼(255)보다 넉넉히 짧게 자른다
  private static final int COPY_TITLE_MAX_LENGTH = 100;
  /// 원본 제목과 "복사" 사이
  private static final String COPY_TITLE_SEPARATOR = " ";

  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineStepSpeechQueue routineStepSpeechQueue;
  private final RoutineGroupMembership routineGroupMembership;
  private final ApplicationEventPublisher eventPublisher;

  /**
   * 보내기: 권한(복제와 같음) > 원본·보낸 상태 확인 > 오늘 이미 보냈는지 > 카드 복사 (오늘 09:00, 원본 ID 기록)
   */
  @Transactional
  public RoutineResponse send(Caller caller, String routineId) {
    Routine original = getRoutineFor(caller, routineId, RoutineAction.COPY);
    validateLibraryOriginal(original);
    if (isAlreadySentToday(original)) {
      log.info("[routine library] send rejected 409 : already sent today, routineId={}", routineId);
      throw new CustomException(ErrorCode.ROUTINE_ALREADY_SENT_TODAY);
    }
    Routine sentRoutine = saveCopy(newTodayCopyOf(original, caller.memberId()));
    // 새로 만든 오늘 일과가 알림 대상 (요청자 제외는 보호자 기기일 때만)
    String actorMemberId = caller.isElumi() ? null : caller.memberId();
    eventPublisher.publishEvent(new RoutineSentEvent(sentRoutine.getId(), sentRoutine.getProfile().getId(),
      actorMemberId));
    return RoutineResponse.from(sentRoutine);
  }

  /**
   * 복사하기: 권한(복제와 같음) > 원본·보낸 상태 확인 > 카드 복사 > "제목 복사" 새 원본 (일과관리에만, 홈에 안 뜸)
   * 보유 일과 한도는 보지 않음 — 복제(duplicate)와 같다
   */
  @Transactional
  public RoutineResponse copy(Caller caller, String routineId) {
    Routine original = getRoutineFor(caller, routineId, RoutineAction.COPY);
    validateLibraryOriginal(original);
    return RoutineResponse.from(saveCopy(newLibraryCopyOf(original, caller.memberId(), true)));
  }

  /**
   * 일과관리에서 지우기: 권한(만든 사람) > 묶음에서 빼기(2개 미만이면 묶음 풀기) > 흔적 없는 복사본이면 삭제, 아니면 목록에서만 숨김
   * 흔적 = 완료한 단계 · 이 원본으로 보낸 일과. 남아 있으면 수행 기록이라 행을 지우지 않는다
   */
  @Transactional
  public void removeFromLibrary(Caller caller, String routineId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    routineGroupMembership.leaveGroup(routine);
    if (isDeletableLibraryCopy(routine)) {
      RoutineRules.deleteWithSpeech(routineRepository, routineStepSpeechQueue, routine);
      return;
    }
    routine.setLibraryHidden(true);
  }

  /// 일과관리 원본 조건 2개: 보내기로 만든 일과가 아님, 보낸 상태(임시저장은 승인 전이라 복사하면 승인을 건너뜀)
  private void validateLibraryOriginal(Routine routine) {
    if (routine.getSourceRoutineId() != null || routine.getStatus() == RoutineStatus.PENDING_REVIEW) {
      log.info("[routine library] rejected 409 : not a library original, routineId={}, status={}",
        routine.getId(), routine.getStatus());
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
  }

  /// 원본 카드 > 오늘 일과 (저장 전, 원본 ID 기록). 낱개·묶음째 보내기가 함께 씀
  Routine newTodayCopyOf(Routine original, String createdBy) {
    Routine copy = RoutineRules.copyCardsOf(original, createdBy);
    copy.setSourceRoutineId(original.getId());
    copy.setLibraryOnly(false);
    return copy;
  }

  /**
   * 원본 카드 > 일과관리에만 있는 새 원본 (저장 전). 낱개 복사는 "제목 복사", 묶음 복사는 제목 그대로
   * 묶음 복사는 묶음 이름에 "복사"가 붙어 일과마다 붙이면 중복이다
   */
  Routine newLibraryCopyOf(Routine original, String createdBy, boolean shouldAddCopySuffix) {
    Routine copy = RoutineRules.copyCardsOf(original, createdBy);
    if (shouldAddCopySuffix) {
      copy.setTitle(toCopyName(original.getTitle(), original.getLanguage(), COPY_TITLE_MAX_LENGTH));
    }
    copy.setSourceRoutineId(null);
    copy.setLibraryOnly(true);
    copy.setScheduledAt(LocalDateTime.now());
    return copy;
  }

  /// 복사본 저장 > 커밋 뒤 단계 음성 예약
  Routine saveCopy(Routine copy) {
    return RoutineRules.saveWithSpeech(routineRepository, routineStepSpeechQueue, copy);
  }

  /// 오늘 이미 보냈는가: 원본 자체가 오늘 홈 일과이거나(복사본 제외), 이 원본으로 보낸 일과가 오늘 있음
  boolean isAlreadySentToday(Routine original) {
    LocalDate today = LocalDate.now();
    LocalDateTime startOfDay = today.atStartOfDay();
    LocalDateTime endOfDay = today.atTime(LocalTime.MAX);
    boolean isOriginalOnTodayHome = !original.isLibraryOnly()
      && !original.getScheduledAt().isBefore(startOfDay)
      && !original.getScheduledAt().isAfter(endOfDay);
    return isOriginalOnTodayHome
      || routineRepository.existsBySourceRoutineIdAndScheduledAtBetween(original.getId(), startOfDay, endOfDay);
  }

  /// 지워도 되는 복사본인가: 복사하기로 만든 일과 · 완료한 단계 0 · 이 일과로 보낸 일과 없음
  private boolean isDeletableLibraryCopy(Routine routine) {
    return routine.isLibraryOnly()
      && RoutineRules.countCompleted(routine.getSteps()) == 0
      && !routineRepository.existsBySourceRoutineId(routine.getId());
  }

  /// 이름 > "이름 복사" (언어별 문구, maxLength 제한 — 넘으면 원래 이름 쪽을 자름). 일과 제목·묶음 이름이 함께 씀
  static String toCopyName(String name, AppLocale language, int maxLength) {
    String suffix = RoutinePhrases.standard().copyTitleSuffix(language == null ? AppLocale.KO : language);
    if (suffix == null || suffix.isBlank()) {
      return name.length() > maxLength ? name.substring(0, maxLength) : name;
    }
    String tail = COPY_TITLE_SEPARATOR + suffix;
    int nameRoom = Math.max(0, maxLength - tail.length());
    // 자른 자리가 공백이면 "아침 " + " 복사" 처럼 공백이 겹쳐 끝 공백을 지움
    return (name.length() > nameRoom ? name.substring(0, nameRoom).stripTrailing() : name) + tail;
  }

  private Routine getRoutineFor(Caller caller, String routineId, RoutineAction action) {
    return RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, action);
  }
}
