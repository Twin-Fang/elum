package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticeResponse;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticesResponse;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notice.infrastructure.storage.LocalFileNoticeImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 앱에 줄 공지 목록 (이슈 #370). 게시 판단은 서버가 한다 — 기기 시간이 틀려도 끝난 공지가
 * 뜨지 않게(N5).
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NoticePublishTest {

  /** 한국 시각 2026-09-23 12:00. 서버 JVM 은 UTC 로 돌 수 있으므로 시계는 UTC 로 준다. */
  private static final Instant NOW = Instant.parse("2026-09-23T03:00:00Z");
  private static final LocalDateTime NOW_KST = LocalDateTime.of(2026, 9, 23, 12, 0);

  @TempDir
  Path tempDir;

  @Mock
  private AppNoticeRepository repository;
  @Mock
  private SystemConfigService systemConfigService;

  private final List<AppNotice> stored = new ArrayList<>();
  private NoticeService service;

  @BeforeEach
  void setUp() {
    service = new NoticeService(repository, systemConfigService,
      new LocalFileNoticeImageStorage(new NoticeProperties(tempDir.toString())),
      Clock.fixed(NOW, ZoneOffset.UTC));
    when(repository.findAll()).thenReturn(stored);
    when(systemConfigService.getInt(ConfigKey.NOTICE_HIDE_DAYS)).thenReturn(7);
  }

  private AppNotice notice(String id, NoticePlatform platform, int priority, LocalDateTime startsAt) {
    AppNotice notice = new AppNotice();
    notice.setId(id);
    notice.setTitle("제목 " + id);
    notice.setBody("본문 " + id);
    notice.setPlatform(platform);
    notice.setPriority(priority);
    notice.setStartsAt(startsAt);
    notice.setEnabled(true);
    notice.setCreatedBy("admin");
    notice.setUpdatedBy("admin");
    stored.add(notice);
    return notice;
  }

  private List<String> ids(AppNoticesResponse response) {
    return response.notices().stream().map(AppNoticeResponse::id).toList();
  }

  @Test
  @DisplayName("iOS 앱에는 전체 공지와 iOS 공지만 준다")
  void platform_filters() {
    notice("all", NoticePlatform.ALL, 0, NOW_KST.minusDays(1));
    notice("ios", NoticePlatform.IOS, 0, NOW_KST.minusDays(2));
    notice("android", NoticePlatform.ANDROID, 0, NOW_KST.minusDays(3));

    assertThat(ids(service.publishedFor("IOS"))).containsExactly("all", "ios");
    assertThat(ids(service.publishedFor("android"))).containsExactly("all", "android");
  }

  @Test
  @DisplayName("플랫폼을 안 주면 전체 공지만 준다 — 한쪽 스토어용 안내가 새지 않게")
  void noPlatform_onlyAll() {
    notice("all", NoticePlatform.ALL, 0, NOW_KST.minusDays(1));
    notice("ios", NoticePlatform.IOS, 0, NOW_KST.minusDays(1));

    assertThat(ids(service.publishedFor(null))).containsExactly("all");
  }

  @Test
  @DisplayName("모르는 플랫폼 값은 400 이다")
  void unknownPlatform_rejected() {
    assertThatThrownBy(() -> service.publishedFor("WINDOWS"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_PLATFORM_INVALID);
  }

  @Test
  @DisplayName("기간은 서버 시계의 한국 시각으로 판단한다 — JVM 이 UTC 여도 9시간 밀리지 않는다 (N5)")
  void period_usesServerClockInKst() {
    // UTC 로 보면 지금은 03:00 이라 11:00 시작은 아직 예약이다. 한국 시각으로는 게시 중이다.
    notice("started-11", NoticePlatform.ALL, 0, NOW_KST.minusHours(1));
    // 한국 시각 12:30 시작 — 아직 예약
    notice("starts-1230", NoticePlatform.ALL, 0, NOW_KST.plusMinutes(30));
    // 한국 시각 12:00 에 끝남 — 종료 그 순간부터 빠진다
    notice("ended-12", NoticePlatform.ALL, 0, NOW_KST.minusDays(1)).setEndsAt(NOW_KST);

    assertThat(ids(service.publishedFor("IOS"))).containsExactly("started-11");
  }

  @Test
  @DisplayName("꺼 둔 공지는 기간 안이어도 주지 않는다 (N17)")
  void disabled_excluded() {
    notice("on", NoticePlatform.ALL, 0, NOW_KST.minusDays(1));
    notice("off", NoticePlatform.ALL, 9, NOW_KST.minusDays(1)).setEnabled(false);

    assertThat(ids(service.publishedFor("IOS"))).containsExactly("on");
  }

  @Test
  @DisplayName("우선순위가 큰 것 먼저, 같으면 시작이 늦은 것 먼저다")
  void ordering() {
    notice("p0-old", NoticePlatform.ALL, 0, NOW_KST.minusDays(5));
    notice("p0-new", NoticePlatform.ALL, 0, NOW_KST.minusDays(1));
    notice("p5", NoticePlatform.ALL, 5, NOW_KST.minusDays(9));

    assertThat(ids(service.publishedFor("IOS"))).containsExactly("p5", "p0-new", "p0-old");
  }

  @Test
  @DisplayName("게시 중인 공지가 6개 이상이면 순서대로 5개만 준다 (N24)")
  void atMostFive() {
    for (int i = 1; i <= 7; i++) {
      notice("n" + i, NoticePlatform.ALL, i, NOW_KST.minusDays(1));
    }

    assertThat(ids(service.publishedFor("IOS"))).containsExactly("n7", "n6", "n5", "n4", "n3");
  }

  @Test
  @DisplayName("보지 않기 일수는 관리자 설정 값이다")
  void hideDays_fromConfig() {
    when(systemConfigService.getInt(ConfigKey.NOTICE_HIDE_DAYS)).thenReturn(3);

    assertThat(service.publishedFor("IOS").hideDays()).isEqualTo(3);
  }

  @Test
  @DisplayName("설정 값이 1~30 밖이면(DB 를 손으로 고친 경우) 가까운 끝으로 맞춘다")
  void hideDays_clamped() {
    when(systemConfigService.getInt(ConfigKey.NOTICE_HIDE_DAYS)).thenReturn(0);
    assertThat(service.publishedFor("IOS").hideDays()).isEqualTo(1);

    when(systemConfigService.getInt(ConfigKey.NOTICE_HIDE_DAYS)).thenReturn(365);
    assertThat(service.publishedFor("IOS").hideDays()).isEqualTo(30);
  }

  @Test
  @DisplayName("응답 항목 — 강조 표기는 그대로, 버튼과 이미지가 없으면 null 이다")
  void responseFields() {
    AppNotice notice = notice("plain", NoticePlatform.ALL, 0, NOW_KST.minusDays(1));
    notice.setTitle("**하루 3개**까지 만들 수 있어요");
    notice.setRevision(4);

    AppNoticeResponse item = service.publishedFor("IOS").notices().getFirst();

    assertThat(item.id()).isEqualTo("plain");
    assertThat(item.revision()).isEqualTo(4);
    assertThat(item.title()).isEqualTo("**하루 3개**까지 만들 수 있어요");
    assertThat(item.body()).isEqualTo("본문 plain");
    assertThat(item.imageUrl()).isNull();
    assertThat(item.button()).isNull();
  }

  @Test
  @DisplayName("이미지 주소는 열쇠가 바뀌면 달라진다 — 그림을 바꾸면 앱 캐시가 새 그림을 받는다")
  void imageUrl_changesWithKey() {
    AppNotice notice = notice("img", NoticePlatform.ALL, 0, NOW_KST.minusDays(1));
    notice.setImageKey("img/aaa111.png");
    notice.setButtonLabel("자세히 보기");
    notice.setButtonUrl("https://twin-fang.github.io/elum/");

    AppNoticeResponse first = service.publishedFor("IOS").notices().getFirst();
    notice.setImageKey("img/bbb222.webp");
    AppNoticeResponse second = service.publishedFor("IOS").notices().getFirst();

    assertThat(first.imageUrl()).startsWith("/api/app/notices/img/image?v=");
    assertThat(first.imageUrl()).isNotEqualTo(second.imageUrl());
    assertThat(first.button().label()).isEqualTo("자세히 보기");
    assertThat(first.button().url()).isEqualTo("https://twin-fang.github.io/elum/");
  }
}
