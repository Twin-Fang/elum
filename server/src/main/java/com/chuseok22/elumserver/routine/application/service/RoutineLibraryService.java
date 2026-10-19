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
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 일과관리(원본 보관함) 쓰기: 보내기, 복사하기, 지우기 (#804)
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
    Routine copy = RoutineRules.copyCardsOf(original, caller.memberId());
    copy.setSourceRoutineId(original.getId());
    copy.setLibraryOnly(false);
    return RoutineResponse.from(RoutineRules.saveWithSpeech(routineRepository, routineStepSpeechQueue, copy));
  }

  /**
   * 복사하기: 권한(복제와 같음) > 원본·보낸 상태 확인 > 카드 복사 > "제목 복사" 새 원본 (일과관리에만, 홈에 안 뜸)
   * 보유 일과 한도는 보지 않음 — 복제(duplicate)와 같다
   */
  @Transactional
  public RoutineResponse copy(Caller caller, String routineId) {
    Routine original = getRoutineFor(caller, routineId, RoutineAction.COPY);
    validateLibraryOriginal(original);
    Routine copy = RoutineRules.copyCardsOf(original, caller.memberId());
    copy.setTitle(toCopyTitle(original));
    copy.setSourceRoutineId(null);
    copy.setLibraryOnly(true);
    copy.setScheduledAt(LocalDateTime.now());
    return RoutineResponse.from(RoutineRules.saveWithSpeech(routineRepository, routineStepSpeechQueue, copy));
  }

  /**
   * 일과관리에서 지우기: 권한(만든 사람) > 흔적 없는 복사본이면 삭제, 아니면 목록에서만 숨김
   * 흔적 = 완료한 단계 · 이 원본으로 보낸 일과. 남아 있으면 수행 기록이라 행을 지우지 않는다
   */
  @Transactional
  public void removeFromLibrary(Caller caller, String routineId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
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

  /// 오늘 이미 보냈는가: 원본 자체가 오늘 홈 일과이거나(복사본 제외), 이 원본으로 보낸 일과가 오늘 있음
  private boolean isAlreadySentToday(Routine original) {
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

  /// 원본 제목 > "원본 제목 복사" (일과 언어, 100자 제한 — 넘으면 원본 제목 쪽을 자름)
  private String toCopyTitle(Routine original) {
    String suffix = RoutinePhrases.standard()
      .copyTitleSuffix(original.getLanguage() == null ? AppLocale.KO : original.getLanguage());
    String title = original.getTitle();
    if (suffix == null || suffix.isBlank()) {
      return title.length() > COPY_TITLE_MAX_LENGTH ? title.substring(0, COPY_TITLE_MAX_LENGTH) : title;
    }
    String tail = COPY_TITLE_SEPARATOR + suffix;
    int titleRoom = COPY_TITLE_MAX_LENGTH - tail.length();
    return (title.length() > titleRoom ? title.substring(0, titleRoom) : title) + tail;
  }

  private Routine getRoutineFor(Caller caller, String routineId, RoutineAction action) {
    return RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, action);
  }
}
