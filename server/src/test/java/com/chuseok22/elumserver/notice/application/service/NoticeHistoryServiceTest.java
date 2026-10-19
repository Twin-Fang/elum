package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notice.application.dto.response.NoticeHistoryItemResponse;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notification.infrastructure.entity.NoticeSeen;
import com.chuseok22.elumserver.notification.infrastructure.repository.NoticeSeenRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
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
  private NoticeSeenRepository noticeSeenRepository;

  private final List<AppNotice> stored = new ArrayList<>();
  private NoticeHistoryService service;

  @BeforeEach
  void setUp() {
    when(appNoticeRepository.findAll()).thenReturn(stored);
    when(noticeSeenRepository.findById(MEMBER_ID)).thenReturn(Optional.empty());
    service = new NoticeHistoryService(appNoticeRepository, noticeSeenRepository, Clock.fixed(NOW, java.time.ZoneOffset.UTC));
  }

  @Test
  @DisplayName("게시가 끝난 공지도 90일 안이면 목록에 나온다")
  void includesEndedNotice_within90Days() {
    AppNotice ended = notice("ended", NOW_KST.minusDays(30));
    ended.setEndsAt(NOW_KST.minusDays(10));
    stored.add(ended);

    assertThat(service.history("IOS", null, null).items()).extracting(NoticeHistoryItemResponse::id)
      .containsExactly("ended");
  }

  @Test
  @DisplayName("90일보다 오래된 공지는 나오지 않는다")
  void excludesOlderThan90Days() {
    stored.add(notice("old", NOW_KST.minusDays(91)));

    assertThat(service.history("IOS", null, null).items()).isEmpty();
  }

  @Test
  @DisplayName("요청 언어와 다른 공지는 나오지 않는다")
  void excludesOtherLocale() {
    AppNotice english = notice("en", NOW_KST.minusDays(1));
    english.setLocale(AppLocale.EN);
    stored.add(english);

    assertThat(service.history("IOS", null, null).items()).isEmpty();
  }

  @Test
  @DisplayName("꺼진 공지는 나오지 않는다")
  void excludesDisabled() {
    AppNotice disabled = notice("off", NOW_KST.minusDays(1));
    disabled.setEnabled(false);
    stored.add(disabled);

    assertThat(service.history("IOS", null, null).items()).isEmpty();
  }

  @Test
  @DisplayName("읽은 뒤에 다시 보이게 고친 공지는 안 읽음이다")
  void republishedAfterSeen_isUnseen() {
    AppNotice republished = notice("re", NOW_KST.minusDays(20));
    republished.setRevisedAt(NOW_KST.minusDays(1));
    stored.add(republished);
    NoticeSeen seen = new NoticeSeen();
    seen.setMemberId(MEMBER_ID);
    seen.setSeenAt(NOW_KST.minusDays(5));
    when(noticeSeenRepository.findById(MEMBER_ID)).thenReturn(Optional.of(seen));

    assertThat(service.hasUnseenNotice(MEMBER_ID, "IOS")).isTrue();
  }

  @Test
  @DisplayName("읽은 뒤 바뀐 공지가 없으면 안 읽음이 아니다")
  void seenAfterAll_isNotUnseen() {
    stored.add(notice("a", NOW_KST.minusDays(20)));
    NoticeSeen seen = new NoticeSeen();
    seen.setMemberId(MEMBER_ID);
    seen.setSeenAt(NOW_KST.minusDays(5));
    when(noticeSeenRepository.findById(MEMBER_ID)).thenReturn(Optional.of(seen));

    assertThat(service.hasUnseenNotice(MEMBER_ID, "IOS")).isFalse();
  }

  @Test
  @DisplayName("읽은 기록이 없으면 공지가 하나라도 있을 때 안 읽음이다")
  void noSeenRow_anyNotice_isUnseen() {
    stored.add(notice("a", NOW_KST.minusDays(60)));

    assertThat(service.hasUnseenNotice(MEMBER_ID, "IOS")).isTrue();
  }

  @Test
  @DisplayName("cursor 로 이어 받으면 중복 없이 다음 쪽이 나온다")
  void cursor_continuesAfterLastItem() {
    stored.add(notice("a", NOW_KST.minusDays(1)));
    stored.add(notice("b", NOW_KST.minusDays(2)));
    stored.add(notice("c", NOW_KST.minusDays(3)));

    var first = service.history("IOS", null, 2);
    var second = service.history("IOS", first.nextCursor(), 2);

    assertThat(first.items()).extracting(NoticeHistoryItemResponse::id).containsExactly("a", "b");
    assertThat(first.nextCursor()).isEqualTo("b");
    assertThat(second.items()).extracting(NoticeHistoryItemResponse::id).containsExactly("c");
    assertThat(second.nextCursor()).isNull();
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
