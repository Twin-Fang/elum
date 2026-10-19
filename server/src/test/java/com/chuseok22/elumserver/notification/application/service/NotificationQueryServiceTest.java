package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
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
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Pageable;

/// 목록 순서·커서가 틀리면 알림이 중복되거나 빠지고, 접근 못 하는 이룸이 이름·지운 일과 제목이 새면 정보가 샌다
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NotificationQueryServiceTest {

  private static final String MEMBER_ID = "m1";
  private static final LocalDateTime NEWER = LocalDateTime.of(2026, 10, 19, 12, 0, 0);
  private static final LocalDateTime OLDER = LocalDateTime.of(2026, 10, 19, 9, 0, 0);

  @Mock
  private NotificationRepository notificationRepository;
  @Mock
  private ProfileGuardianService profileGuardianService;
  @Mock
  private RoutineQueryService routineQueryService;
  @Mock
  private NoticeHistoryService noticeHistoryService;

  private NotificationQueryService notificationQueryService;

  @BeforeEach
  void setUp() {
    notificationQueryService = new NotificationQueryService(
      notificationRepository, profileGuardianService, routineQueryService, noticeHistoryService);
    when(profileGuardianService.profileNamesOf(anyString(), anyCollection())).thenReturn(Map.of());
    when(routineQueryService.titlesOf(anyCollection(), anyCollection())).thenReturn(Map.of());
  }

  @Test
  @DisplayName("최신순으로 주고, size 보다 한 건 더 있으면 마지막 행 위치로 nextCursor 를 준다")
  void page_ordersByLastOccurredDesc_andReturnsNextCursor() {
    Notification newer = routineCompleted("n-new", "p1", "r1,r2", NEWER);
    Notification older = routineCompleted("n-old", "p1", "r3", OLDER);
    Notification oldest = routineCompleted("n-oldest", "p1", "r4", OLDER.minusHours(1));
    when(notificationRepository.findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(eq(MEMBER_ID), any(Pageable.class)))
      .thenReturn(List.of(newer, older, oldest));

    NotificationPageResponse page = notificationQueryService.page(MEMBER_ID, null, 2);

    assertThat(page.items()).extracting(NotificationItemResponse::id).containsExactly("n-new", "n-old");
    assertThat(page.nextCursor()).isEqualTo(OLDER + "|n-old");
  }

  @Test
  @DisplayName("size+1 보다 적게 오면 마지막 쪽이라 nextCursor 가 null 이다")
  void page_lastPage_nextCursorNull() {
    when(notificationRepository.findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(eq(MEMBER_ID), any(Pageable.class)))
      .thenReturn(List.of(routineCompleted("n1", "p1", "r1", NEWER)));

    assertThat(notificationQueryService.page(MEMBER_ID, null, 2).nextCursor()).isNull();
  }

  @Test
  @DisplayName("cursor 가 있으면 그 위치 뒤 쿼리를 쓴다")
  void page_withCursor_usesKeysetQuery() {
    when(notificationRepository.findPageAfter(eq(MEMBER_ID), eq(OLDER), eq("n-old"), any(Pageable.class)))
      .thenReturn(List.of());

    notificationQueryService.page(MEMBER_ID, OLDER + "|n-old", 20);

    verify(notificationRepository).findPageAfter(eq(MEMBER_ID), eq(OLDER), eq("n-old"), any(Pageable.class));
  }

  @Test
  @DisplayName("cursor 형식이 틀리면 첫 쪽으로 본다")
  void cursorMalformed_returnsFirstPage() {
    when(notificationRepository.findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(eq(MEMBER_ID), any(Pageable.class)))
      .thenReturn(List.of());

    notificationQueryService.page(MEMBER_ID, "not-a-cursor|x", 20);

    verify(notificationRepository).findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(eq(MEMBER_ID), any(Pageable.class));
    verify(notificationRepository, never()).findPageAfter(anyString(), any(), anyString(), any());
  }

  @Test
  @DisplayName("일과 완료 줄의 제목은 subjectIds 마지막(가장 최근) 일과의 지금 제목이다")
  void routineCompleted_titleOfLastSubject() {
    when(notificationRepository.findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(eq(MEMBER_ID), any(Pageable.class)))
      .thenReturn(List.of(routineCompleted("n1", "p1", "r1,r2", NEWER)));
    when(profileGuardianService.profileNamesOf(eq(MEMBER_ID), anyCollection())).thenReturn(Map.of("p1", "하늘"));
    when(routineQueryService.titlesOf(anyCollection(), anyCollection())).thenReturn(Map.of("r1", "양치", "r2", "세수"));

    NotificationItemResponse item = notificationQueryService.page(MEMBER_ID, null, 20).items().get(0);

    assertThat(item.routineTitle()).isEqualTo("세수");
    assertThat(item.profileName()).isEqualTo("하늘");
    assertThat(item.isRead()).isFalse();
  }

  @Test
  @DisplayName("지워진 일과의 제목은 null 이다")
  void deletedRoutine_titleNull() {
    when(notificationRepository.findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(eq(MEMBER_ID), any(Pageable.class)))
      .thenReturn(List.of(routineCompleted("n1", "p1", "r-deleted", NEWER)));
    when(profileGuardianService.profileNamesOf(eq(MEMBER_ID), anyCollection())).thenReturn(Map.of("p1", "하늘"));
    when(routineQueryService.titlesOf(anyCollection(), anyCollection())).thenReturn(Map.of());

    assertThat(notificationQueryService.page(MEMBER_ID, null, 20).items().get(0).routineTitle()).isNull();
  }

  @Test
  @DisplayName("더는 접근할 수 없는 이룸이의 이름은 null 이다")
  void profileNoLongerAccessible_profileNameNull() {
    when(notificationRepository.findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(eq(MEMBER_ID), any(Pageable.class)))
      .thenReturn(List.of(routineCompleted("n1", "p-left", "r1", NEWER)));
    when(profileGuardianService.profileNamesOf(eq(MEMBER_ID), anyCollection())).thenReturn(Map.of());

    NotificationItemResponse item = notificationQueryService.page(MEMBER_ID, null, 20).items().get(0);

    assertThat(item.profileName()).isNull();
    assertThat(item.profileId()).isEqualTo("p-left");
  }

  @Test
  @DisplayName("공동 보호자가 보낸 일과는 targetId 일과의 제목을 쓴다")
  void sentByCoGuardian_titleOfTarget() {
    Notification sent = routineCompleted("n1", "p1", null, NEWER);
    sent.setType(NotificationType.ROUTINE_SENT_BY_CO_GUARDIAN);
    sent.setTargetId("r9");
    when(notificationRepository.findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(eq(MEMBER_ID), any(Pageable.class)))
      .thenReturn(List.of(sent));
    when(profileGuardianService.profileNamesOf(eq(MEMBER_ID), anyCollection())).thenReturn(Map.of("p1", "하늘"));
    when(routineQueryService.titlesOf(anyCollection(), anyCollection())).thenReturn(Map.of("r9", "산책"));

    assertThat(notificationQueryService.page(MEMBER_ID, null, 20).items().get(0).routineTitle()).isEqualTo("산책");
  }

  @Test
  @DisplayName("platform 이 틀려도 요약은 실패하지 않고 공지만 false 이다")
  void invalidPlatform_noticeFalse_doesNotThrow() {
    when(notificationRepository.countByRecipientMemberIdAndReadAtIsNull(MEMBER_ID)).thenReturn(3L);
    when(noticeHistoryService.hasUnseenNotice(eq(MEMBER_ID), eq("WINDOWS"), any(AppLocale.class)))
      .thenThrow(new CustomException(ErrorCode.NOTICE_PLATFORM_INVALID));

    UnreadSummaryResponse summary = notificationQueryService.unreadSummary(MEMBER_ID, "WINDOWS");

    assertThat(summary.hasUnreadNotice()).isFalse();
    assertThat(summary.hasUnreadNotification()).isTrue();
    assertThat(summary.unreadNotificationCount()).isEqualTo(3L);
  }

  @Test
  @DisplayName("공지 판단 외의 예외는 숨기지 않는다")
  void otherNoticeError_isNotSwallowed() {
    when(noticeHistoryService.hasUnseenNotice(anyString(), any(), any(AppLocale.class)))
      .thenThrow(new CustomException(ErrorCode.INVALID_INPUT_VALUE));

    assertThatThrownBy(() -> notificationQueryService.unreadSummary(MEMBER_ID, "IOS"))
      .isInstanceOf(CustomException.class);
  }

  private static Notification routineCompleted(String id, String profileId, String subjectIds, LocalDateTime occurredAt) {
    Notification notification = new Notification();
    notification.setId(id);
    notification.setRecipientMemberId(MEMBER_ID);
    notification.setProfileId(profileId);
    notification.setType(NotificationType.ROUTINE_COMPLETED);
    notification.setSubjectIds(subjectIds);
    notification.setLastOccurredAt(occurredAt);
    return notification;
  }
}
