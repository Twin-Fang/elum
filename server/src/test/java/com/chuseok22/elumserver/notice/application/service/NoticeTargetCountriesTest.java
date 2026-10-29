package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeInput;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticeResponse;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticesResponse;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.core.NoticeTargetCountries;
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
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 공지 대상 국가 (#531): 입력 형식, 국가별 노출, 국가 미상 처리, 5장 자리
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NoticeTargetCountriesTest {

  /** 한국 시각 2026-09-23 12:00 */
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
    when(repository.save(any(AppNotice.class)))
      .thenAnswer(invocation -> invocation.getArgument(0));
    when(systemConfigService.getInt(ConfigKey.NOTICE_HIDE_DAYS)).thenReturn(7);
  }

  @Test
  @DisplayName("헤더 없는 옛 앱(KR)은 대상이 빈 기존 공지를 전과 같이 본다")
  void headerlessOldApp_seesUntargetedNotice() {
    live("legacy", 0, null);

    assertThat(ids(service.publishedFor("IOS", "KR"))).containsExactly("legacy");
  }

  @Test
  @DisplayName("국가 미상에게 대상이 지정된 공지는 새지 않는다 — 대상 없는 공지만 보인다")
  void unknownRegion_neverSeesTargeted() {
    live("everyone", 0, null);
    live("korea-only", 9, "KR");

    assertThat(ids(service.publishedFor("IOS", null))).containsExactly("everyone");
    assertThat(ids(service.publishedFor("IOS", "KR"))).containsExactly("korea-only", "everyone");
    assertThat(ids(service.publishedFor("IOS", "JP"))).containsExactly("everyone");
  }

  @Test
  @DisplayName("다른 나라 공지는 5장 자리를 차지하지 않는다 — 자르기 전에 거른다")
  void otherCountryNotices_doNotTakeSlots() {
    for (int index = 0; index < 5; index++) {
      live("japan-" + index, 10, "JP");
    }
    live("korea", 0, "KR,JP");

    assertThat(ids(service.publishedFor("IOS", "KR"))).containsExactly("korea");
  }

  @Test
  @DisplayName("대상 국가 입력은 쉼표·공백으로 나누고 중복을 지운다 — 비우면 전체(null)")
  void create_normalizesTargetCountries() {
    assertThat(service.create(input(" KR,  JP KR "), null, "admin").getTargetCountries()).isEqualTo("KR,JP");
    assertThat(service.create(input(" , "), null, "admin").getTargetCountries()).isNull();
  }

  @ParameterizedTest
  @ValueSource(strings = {"kr", "KOR", "K1", "KR,jp"})
  @DisplayName("두 글자 대문자가 아니면 저장하지 않는다 — 몰래 고치면 화면 값과 저장 값이 달라진다")
  void create_rejectsMalformedCode(String raw) {
    assertThatThrownBy(() -> service.create(input(raw), null, "admin"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_TARGET_COUNTRIES_INVALID);
  }

  @Test
  @DisplayName("저장 열(255자)을 넘는 목록은 거절한다 — 저장 순간 500 이 나지 않게")
  void create_rejectsTooLong() {
    StringBuilder codes = new StringBuilder();
    for (char first = 'A'; first <= 'Z'; first++) {
      for (char second = 'A'; second <= 'E'; second++) {
        codes.append(first).append(second).append(',');
      }
    }
    assertThat(codes.length()).isGreaterThan(NoticeTargetCountries.MAX_LENGTH);

    assertThatThrownBy(() -> service.create(input(codes.toString()), null, "admin"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_TARGET_COUNTRIES_INVALID);
  }

  private void live(String id, int priority, String targetCountries) {
    AppNotice notice = new AppNotice();
    notice.setId(id);
    notice.setTitle("제목 " + id);
    notice.setBody("본문 " + id);
    notice.setPlatform(NoticePlatform.ALL);
    notice.setPriority(priority);
    notice.setStartsAt(NOW_KST.minusDays(1));
    notice.setTargetCountries(targetCountries);
    notice.setEnabled(true);
    notice.setCreatedBy("admin");
    notice.setUpdatedBy("admin");
    stored.add(notice);
  }

  private static NoticeInput input(String targetCountries) {
    return new NoticeInput("공지", "본문", "", "", "ALL", "ko", targetCountries, "0", "2026-09-23T09:00", "", false);
  }

  private static List<String> ids(AppNoticesResponse response) {
    return response.notices().stream().map(AppNoticeResponse::id).toList();
  }
}
