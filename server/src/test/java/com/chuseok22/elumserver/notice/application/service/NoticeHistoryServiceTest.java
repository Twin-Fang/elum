package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notice.application.dto.response.NoticeHistoryItemResponse;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notification.application.service.NoticeSeenService;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 공지 탭: 종료된 공지도 90일 안이면 보이고, 다시 보이게 한 공지는 읽은 뒤에도 안 읽음이 된다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NoticeHistoryServiceTest {

  /** 한국 시각 2026-10-19 12:00 (시계는 UTC 로 준다) */
  private static final Instant NOW = Instant.parse("2026-10-19T03:00:00Z");
  private static final LocalDateTime NOW_KST = LocalDateTime.of(2026, 10, 19, 12, 0);
  private static final String MEMBER_ID = "guardian-1";

  @Mock
  private AppNoticeRepository appNoticeRepository;
  @Mock
  private NoticeSeenService noticeSeenService;

  private final List<AppNotice> stored = new ArrayList<>();
  private NoticeHistoryService service;

  @BeforeEach
  void setUp() {
    when(appNoticeRepository.findAll()).thenReturn(stored);
    when(noticeSeenService.findSeenAt(MEMBER_ID)).thenReturn(Optional.empty());
    service = new NoticeHistoryService(appNoticeRepository, noticeSeenService, Clock.fixed(NOW, ZoneOffset.UTC));
  }

  @Test
  @DisplayName("게시가 끝난 공지도 90일 안이면 목록에 나온다")
  void includesEndedNotice_within90Days() {
    AppNotice ended = notice("ended", NOW_KST.minusDays(30));
    ended.setEndsAt(NOW_KST.minusDays(10));
    stored.add(ended);

    assertThat(service.history("IOS", null, null, "KR").items()).extracting(NoticeHistoryItemResponse::id)
      .containsExactly("ended");
  }

  @Test
  @DisplayName("90일보다 오래된 공지는 나오지 않는다")
  void excludesOlderThan90Days() {
    stored.add(notice("old", NOW_KST.minusDays(91)));

    assertThat(service.history("IOS", null, null, "KR").items()).isEmpty();
  }

  @Test
  @DisplayName("정확히 90일 전에 올라온 공지는 나온다")
  void includesExactly90DaysBoundary() {
    stored.add(notice("edge", NOW_KST.minusDays(90)));

    assertThat(service.history("IOS", null, null, "KR").items()).extracting(NoticeHistoryItemResponse::id)
      .containsExactly("edge");
  }

  @Test
  @DisplayName("요청 언어와 다른 공지는 나오지 않는다")
  void excludesOtherLocale() {
    AppNotice english = notice("en", NOW_KST.minusDays(1));
    english.setLocale(AppLocale.EN);
    stored.add(english);

    assertThat(service.history("IOS", null, null, "KR").items()).isEmpty();
  }

  @Test
  @DisplayName("다른 나라 대상 공지는 공지 탭·안 읽음 표시에 나오지 않는다 (#531) — 팝업과 같은 판정")
  void excludesOtherCountryNotice_inHistoryAndUnseen() {
    AppNotice japanOnly = notice("jp", NOW_KST.minusDays(1));
    japanOnly.setTargetCountries("JP");
    stored.add(japanOnly);

    assertThat(service.history("IOS", null, null, "KR").items()).isEmpty();
    assertThat(service.history("IOS", null, null, null).items()).isEmpty();
    assertThat(service.hasUnseenNotice(MEMBER_ID, "IOS", AppLocale.KO, "KR")).isFalse();
    assertThat(service.history("IOS", null, null, "JP").items()).extracting(NoticeHistoryItemResponse::id)
      .containsExactly("jp");
  }

  @Test
  @DisplayName("꺼진 공지는 나오지 않는다")
  void excludesDisabled() {
    AppNotice disabled = notice("off", NOW_KST.minusDays(1));
    disabled.setEnabled(false);
    stored.add(disabled);

    assertThat(service.history("IOS", null, null, "KR").items()).isEmpty();
  }

  @Test
  @DisplayName("읽은 뒤에 다시 보이게 고친 공지는 안 읽음이다")
  void republishedAfterSeen_isUnseen() {
    AppNotice republished = notice("re", NOW_KST.minusDays(20));
    republished.setRevisedAt(NOW_KST.minusDays(1));
    stored.add(republished);
    when(noticeSeenService.findSeenAt(MEMBER_ID)).thenReturn(Optional.of(NOW_KST.minusDays(5)));

    assertThat(service.hasUnseenNotice(MEMBER_ID, "IOS", AppLocale.KO, "KR")).isTrue();
  }

  @Test
  @DisplayName("읽은 뒤 바뀐 공지가 없으면 안 읽음이 아니다")
  void seenAfterAll_isNotUnseen() {
    stored.add(notice("a", NOW_KST.minusDays(20)));
    when(noticeSeenService.findSeenAt(MEMBER_ID)).thenReturn(Optional.of(NOW_KST.minusDays(5)));

    assertThat(service.hasUnseenNotice(MEMBER_ID, "IOS", AppLocale.KO, "KR")).isFalse();
  }

  @Test
  @DisplayName("읽은 기록이 없으면 공지가 하나라도 있을 때 안 읽음이다")
  void noSeenRow_anyNotice_isUnseen() {
    stored.add(notice("a", NOW_KST.minusDays(60)));

    assertThat(service.hasUnseenNotice(MEMBER_ID, "IOS", AppLocale.KO, "KR")).isTrue();
  }

  @Test
  @DisplayName("cursor 로 이어 받으면 중복 없이 다음 쪽이 나온다")
  void cursor_continuesAfterLastItem() {
    stored.add(notice("a", NOW_KST.minusDays(1)));
    stored.add(notice("b", NOW_KST.minusDays(2)));
    stored.add(notice("c", NOW_KST.minusDays(3)));

    var first = service.history("IOS", null, 2, "KR");
    var second = service.history("IOS", first.nextCursor(), 2, "KR");

    assertThat(first.items()).extracting(NoticeHistoryItemResponse::id).containsExactly("a", "b");
    assertThat(first.nextCursor()).isEqualTo(NOW_KST.minusDays(2) + "|b");
    assertThat(second.items()).extracting(NoticeHistoryItemResponse::id).containsExactly("c");
    assertThat(second.nextCursor()).isNull();
  }

  @Test
  @DisplayName("cursor 공지가 사라져도 그 위치 뒤에서 이어 준다")
  void cursor_continuesEvenWhenCursorNoticeIsGone() {
    stored.add(notice("a", NOW_KST.minusDays(1)));
    stored.add(notice("c", NOW_KST.minusDays(3)));
    String cursorOfMissingNotice = NOW_KST.minusDays(2) + "|b";

    assertThat(service.history("IOS", cursorOfMissingNotice, 20, "KR").items())
      .extracting(NoticeHistoryItemResponse::id).containsExactly("c");
  }

  @Test
  @DisplayName("시각이 같으면 id 큰 순이고 cursor 도 id 로 이어진다")
  void cursor_tieBreaksById() {
    stored.add(notice("a", NOW_KST.minusDays(1)));
    stored.add(notice("b", NOW_KST.minusDays(1)));

    var first = service.history("IOS", null, 1, "KR");
    var second = service.history("IOS", first.nextCursor(), 1, "KR");

    assertThat(first.items()).extracting(NoticeHistoryItemResponse::id).containsExactly("b");
    assertThat(second.items()).extracting(NoticeHistoryItemResponse::id).containsExactly("a");
  }

  @Test
  @DisplayName("형식이 틀린 cursor 는 없는 것으로 본다")
  void invalidCursor_isTreatedAsNoCursor() {
    stored.add(notice("a", NOW_KST.minusDays(1)));

    assertThat(service.history("IOS", "garbage", 20, "KR").items()).hasSize(1);
    assertThat(service.history("IOS", "not-a-time|a", 20, "KR").items()).hasSize(1);
  }

  @Test
  @DisplayName("size 는 최소 1, 최대 50 으로 맞춘다")
  void size_isClamped() {
    for (int index = 0; index < 60; index++) {
      stored.add(notice(String.format("n%02d", index), NOW_KST.minusHours(index + 1)));
    }

    assertThat(service.history("IOS", null, 0, "KR").items()).hasSize(1);
    assertThat(service.history("IOS", null, 100, "KR").items()).hasSize(50);
  }

  @Test
  @DisplayName("읽음 기록은 지금 시각으로 저장한다")
  void markSeen_recordsNow() {
    service.markSeen(MEMBER_ID);

    verify(noticeSeenService).markSeen(MEMBER_ID, NOW_KST);
  }

  private AppNotice notice(String id, LocalDateTime startsAt) {
    AppNotice notice = new AppNotice();
    notice.setId(id);
    notice.setTitle("제목 " + id);
    notice.setBody("본문");
    notice.setPlatform(NoticePlatform.ALL);
    notice.setLocale(AppLocale.KO);
    notice.setStartsAt(startsAt);
    notice.setEnabled(true);
    return notice;
  }
}
