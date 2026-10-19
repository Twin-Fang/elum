package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.member.application.service.ProfileGuardianService;
import com.chuseok22.elumserver.notice.application.service.NoticeHistoryService;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationItemResponse;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationPageResponse;
import com.chuseok22.elumserver.notification.application.dto.response.UnreadSummaryResponse;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 알림 조회: 목록 한 쪽, 안 읽음 요약
 * 목록은 (마지막 발생 시각, id) 내림차순 키셋 커서 > 이름·일과 제목은 한 번에 묶어 조회
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationQueryService {

  static final int DEFAULT_PAGE_SIZE = 20;
  static final int MAX_PAGE_SIZE = 50;

  /** cursor 구분자: "{lastOccurredAt ISO-8601}|{id}" */
  private static final String CURSOR_DELIMITER = "|";
  private static final String SUBJECT_ID_DELIMITER = ",";

  private final NotificationRepository notificationRepository;
  private final ProfileGuardianService profileGuardianService;
  private final RoutineQueryService routineQueryService;
  private final NoticeHistoryService noticeHistoryService;

  /**
   * 알림 목록 한 쪽: size+1 개 조회 > 이름·일과 제목 일괄 조회 > 응답 변환
   * cursor 형식이 틀리면 첫 쪽으로 본다
   */
  public NotificationPageResponse page(String memberId, String cursor, Integer size) {
    int pageSize = size == null ? DEFAULT_PAGE_SIZE : Math.clamp(size, 1, MAX_PAGE_SIZE);
    List<Notification> fetched = fetchAfter(memberId, parseCursor(cursor), pageSize + 1);

    // 다음 쪽 여부 (size+1 번째 행이 있으면 더 있음)
    boolean hasNext = fetched.size() > pageSize;
    List<Notification> rows = hasNext ? fetched.subList(0, pageSize) : fetched;
    String nextCursor = hasNext ? toCursor(rows.get(rows.size() - 1)) : null;

    return new NotificationPageResponse(toItems(memberId, rows), nextCursor);
  }

  /**
   * 안 읽음 요약: 알림 개수 + 안 읽은 공지 여부
   * platform 이 틀려도 요약은 실패하지 않고 공지만 없음으로 본다
   */
  public UnreadSummaryResponse unreadSummary(String memberId, String platform) {
    long unreadCount = notificationRepository.countByRecipientMemberIdAndReadAtIsNull(memberId);
    return new UnreadSummaryResponse(unreadCount > 0, unreadCount, hasUnseenNoticeSafely(memberId, platform));
  }

  private boolean hasUnseenNoticeSafely(String memberId, String platform) {
    try {
      // 언어는 요청 스레드에서 정한다
      return noticeHistoryService.hasUnseenNotice(memberId, platform, CurrentLocale.get());
    } catch (CustomException e) {
      if (e.getErrorCode() != ErrorCode.NOTICE_PLATFORM_INVALID) {
        throw e;
      }
      log.warn("[notification summary] notice skipped : platform is invalid");
      return false;
    }
  }

  private List<Notification> fetchAfter(String memberId, CursorPosition position, int limit) {
    PageRequest limitOnly = PageRequest.of(0, limit);
    if (position == null) {
      return notificationRepository.findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(memberId, limitOnly);
    }
    return notificationRepository.findPageAfter(memberId, position.lastOccurredAt(), position.id(), limitOnly);
  }

  private List<NotificationItemResponse> toItems(String memberId, List<Notification> rows) {
    // 이룸이 이름 (접근 가능한 이룸이만)
    Set<String> profileIds = new HashSet<>();
    for (Notification row : rows) {
      if (row.getProfileId() != null) {
        profileIds.add(row.getProfileId());
      }
    }
    Map<String, String> profileNameById = profileGuardianService.profileNamesOf(memberId, profileIds);

    // 일과 제목 (접근 가능한 이룸이의 일과만)
    Set<String> routineIds = new HashSet<>();
    for (Notification row : rows) {
      String routineId = routineIdOf(row);
      if (routineId != null) {
        routineIds.add(routineId);
      }
    }
    Map<String, String> routineTitleById = routineQueryService.titlesOf(routineIds, profileNameById.keySet());

    return rows.stream().map(row -> {
      String routineId = routineIdOf(row);
      return new NotificationItemResponse(
        row.getId(), row.getType(), row.getProfileId(),
        profileNameById.get(row.getProfileId()), row.getTargetId(),
        routineId == null ? null : routineTitleById.get(routineId),
        row.getCount(), row.getLastOccurredAt(), row.getReadAt() != null);
    }).toList();
  }

  /** 제목을 보여줄 일과 id: 일과 완료는 subjectIds 마지막(가장 최근), 공동 보호자가 보낸 일과는 targetId */
  private static String routineIdOf(Notification row) {
    if (row.getType() == NotificationType.ROUTINE_SENT_BY_CO_GUARDIAN) {
      return row.getTargetId();
    }
    if (row.getType() != NotificationType.ROUTINE_COMPLETED || row.getSubjectIds() == null
      || row.getSubjectIds().isBlank()) {
      return null;
    }
    String[] subjectIds = row.getSubjectIds().split(SUBJECT_ID_DELIMITER);
    String lastSubjectId = subjectIds[subjectIds.length - 1].strip();
    return lastSubjectId.isEmpty() ? null : lastSubjectId;
  }

  private record CursorPosition(LocalDateTime lastOccurredAt, String id) {

  }

  /** "lastOccurredAt|id" > 위치. 비었거나 형식이 틀리면 null */
  private static CursorPosition parseCursor(String cursor) {
    if (cursor == null || cursor.isBlank()) {
      return null;
    }
    int delimiterIndex = cursor.indexOf(CURSOR_DELIMITER);
    if (delimiterIndex <= 0 || delimiterIndex == cursor.length() - 1) {
      return null;
    }
    try {
      return new CursorPosition(
        LocalDateTime.parse(cursor.substring(0, delimiterIndex)), cursor.substring(delimiterIndex + 1));
    } catch (DateTimeParseException e) {
      return null;
    }
  }

  private static String toCursor(Notification row) {
    return row.getLastOccurredAt() + CURSOR_DELIMITER + row.getId();
  }
}
