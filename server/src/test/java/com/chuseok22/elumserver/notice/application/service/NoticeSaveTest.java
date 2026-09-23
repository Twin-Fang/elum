package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeInput;
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
import java.util.Optional;
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
 * 관리자 저장 검증 (이슈 #370, N12~N15·N25).
 *
 * <p>걸리면 <b>400 과 에러 코드</b>다. 500 으로 떨어지면 서버 장애와 섞이고(#257 의 교훈),
 * 저장이 반쯤 된 채로 남으면 안 된다 — 걸린 요청은 아무것도 쓰지 않는다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NoticeSaveTest {

  private static final Instant NOW = Instant.parse("2026-09-23T03:00:00Z"); // 한국 12:00

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
    when(repository.save(any(AppNotice.class))).thenAnswer(invocation -> {
      AppNotice notice = invocation.getArgument(0);
      if (notice.getId() == null) {
        notice.setId("notice-" + (stored.size() + 1));
        stored.add(notice);
      }
      return notice;
    });
    when(repository.findById(any())).thenAnswer(invocation -> stored.stream()
      .filter(notice -> notice.getId().equals(invocation.getArgument(0))).findFirst());
    when(systemConfigService.getInt(ConfigKey.NOTICE_HIDE_DAYS)).thenReturn(7);
  }

  /** 통과하는 입력. 테스트마다 한 칸만 바꿔 그 칸의 검증을 본다. */
  private NoticeInput valid() {
    return new NoticeInput("베타 기간 안내", "하루 3개까지 만들 수 있어요", "", "",
      "ALL", "0", "2026-09-23T09:00", "", true);
  }

  private NoticeInput with(String title, String body) {
    NoticeInput base = valid();
    return new NoticeInput(title, body, base.buttonLabel(), base.buttonUrl(), base.platform(),
      base.priority(), base.startsAt(), base.endsAt(), base.enabled());
  }

  private NoticeInput withButton(String label, String url) {
    NoticeInput base = valid();
    return new NoticeInput(base.title(), base.body(), label, url, base.platform(),
      base.priority(), base.startsAt(), base.endsAt(), base.enabled());
  }

  private NoticeInput withPeriod(String startsAt, String endsAt) {
    NoticeInput base = valid();
    return new NoticeInput(base.title(), base.body(), base.buttonLabel(), base.buttonUrl(),
      base.platform(), base.priority(), startsAt, endsAt, base.enabled());
  }

  private void assertRejected(NoticeInput input, ErrorCode expected) {
    assertThatThrownBy(() -> service.create(input, null, "admin"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(expected);
    assertThat(expected.getStatus().value()).isEqualTo(400);
    verify(repository, never()).save(any());
  }

  @Test
  @DisplayName("통과한 입력은 다듬어서 저장한다 — 판은 1, 만든 사람과 고친 사람을 남긴다")
  void create_savesNormalized() {
    AppNotice saved = service.create(new NoticeInput("  **하루 3개**까지  ", "첫 줄\r\n둘째 줄\r\n  ",
      " 자세히 보기 ", " https://twin-fang.github.io/elum/ ", "ios", " 3 ",
      "2026-09-23T09:00", "2026-09-30T18:00", true), null, "kimchi");

    assertThat(saved.getTitle()).isEqualTo("**하루 3개**까지");
    assertThat(saved.getBody()).isEqualTo("첫 줄\n둘째 줄");
    assertThat(saved.getButtonLabel()).isEqualTo("자세히 보기");
    assertThat(saved.getButtonUrl()).isEqualTo("https://twin-fang.github.io/elum/");
    assertThat(saved.getPlatform()).isEqualTo(NoticePlatform.IOS);
    assertThat(saved.getPriority()).isEqualTo(3);
    assertThat(saved.getStartsAt()).isEqualTo(LocalDateTime.of(2026, 9, 23, 9, 0));
    assertThat(saved.getEndsAt()).isEqualTo(LocalDateTime.of(2026, 9, 30, 18, 0));
    assertThat(saved.isEnabled()).isTrue();
    assertThat(saved.getRevision()).isEqualTo(1);
    assertThat(saved.getCreatedBy()).isEqualTo("kimchi");
    assertThat(saved.getUpdatedBy()).isEqualTo("kimchi");
  }

  @Test
  @DisplayName("버튼과 종료를 비우면 없는 것으로 저장한다")
  void create_optionalFieldsEmpty() {
    AppNotice saved = service.create(valid(), null, "admin");

    assertThat(saved.getButtonLabel()).isNull();
    assertThat(saved.getButtonUrl()).isNull();
    assertThat(saved.getEndsAt()).isNull();
    assertThat(saved.getPriority()).isZero();
  }

  @ParameterizedTest
  @ValueSource(strings = {"", "   ", "****", " ** ** "})
  @DisplayName("제목이 비었거나 공백·표기뿐이면 거부한다 (N15)")
  void blankTitle(String title) {
    assertRejected(with(title, "본문"), ErrorCode.NOTICE_TITLE_BLANK);
  }

  @Test
  @DisplayName("제목은 표기까지 40자다 — 41자는 거부, 40자는 통과 (N15)")
  void titleLength() {
    assertRejected(with("가".repeat(41), "본문"), ErrorCode.NOTICE_TITLE_TOO_LONG);
    assertThat(service.create(with("가".repeat(40), "본문"), null, "admin").getTitle()).hasSize(40);
  }

  @Test
  @DisplayName("제목의 ** 짝이 안 맞으면 거부한다 (N25)")
  void unpairedEmphasis() {
    assertRejected(with("**하루 3개까지", "본문"), ErrorCode.NOTICE_TITLE_EMPHASIS_UNPAIRED);
  }

  @ParameterizedTest
  @ValueSource(strings = {"", "  ", "\r\n\r\n"})
  @DisplayName("본문이 비었거나 공백뿐이면 거부한다 (N15)")
  void blankBody(String body) {
    assertRejected(with("제목", body), ErrorCode.NOTICE_BODY_BLANK);
  }

  @Test
  @DisplayName("본문은 1000자까지다 — CRLF 는 LF 로 세어 창 줄바꿈 때문에 넘치지 않는다 (N15)")
  void bodyLength() {
    assertRejected(with("제목", "가".repeat(1001)), ErrorCode.NOTICE_BODY_TOO_LONG);
    String thousandWithCrlf = "가".repeat(499) + "\r\n" + "가".repeat(500);
    assertThat(service.create(with("제목", thousandWithCrlf), null, "admin").getBody()).hasSize(1000);
  }

  @Test
  @DisplayName("버튼 문구만 있거나 링크만 있으면 거부한다 (N13)")
  void halfButton() {
    assertRejected(withButton("자세히 보기", ""), ErrorCode.NOTICE_BUTTON_INCOMPLETE);
    assertRejected(withButton(" ", "https://twin-fang.github.io/elum/"), ErrorCode.NOTICE_BUTTON_INCOMPLETE);
  }

  @ParameterizedTest
  @ValueSource(strings = {
    "http://twin-fang.github.io/elum/",
    "javascript:alert(1)",
    "HTTPS://twin-fang.github.io",
    "https://",
    "https:// twin-fang.github.io",
    "twin-fang.github.io/elum/",
  })
  @DisplayName("버튼 링크는 https:// 로 시작하는 올바른 주소만 받는다 (N12)")
  void nonHttpsUrl(String url) {
    assertRejected(withButton("자세히 보기", url), ErrorCode.NOTICE_BUTTON_URL_INVALID);
  }

  @Test
  @DisplayName("버튼 링크가 500자를 넘으면 거부한다 (N12)")
  void tooLongUrl() {
    assertRejected(withButton("자세히 보기", "https://a.com/" + "a".repeat(500)),
      ErrorCode.NOTICE_BUTTON_URL_INVALID);
  }

  @Test
  @DisplayName("버튼 문구는 20자까지다 — 버튼 한 줄에 들어가야 한다")
  void buttonLabelLength() {
    assertRejected(withButton("가".repeat(21), "https://a.com"), ErrorCode.NOTICE_BUTTON_LABEL_TOO_LONG);
  }

  @Test
  @DisplayName("시작이 종료와 같거나 늦으면 거부한다 (N14)")
  void startNotBeforeEnd() {
    assertRejected(withPeriod("2026-09-30T10:00", "2026-09-30T10:00"), ErrorCode.NOTICE_PERIOD_INVALID);
    assertRejected(withPeriod("2026-10-01T10:00", "2026-09-30T10:00"), ErrorCode.NOTICE_PERIOD_INVALID);
  }

  @ParameterizedTest
  @ValueSource(strings = {"", "  ", "2026-13-40T99:00", "내일"})
  @DisplayName("시작 일시가 없거나 읽을 수 없으면 거부한다 (N14)")
  void badStart(String startsAt) {
    assertRejected(withPeriod(startsAt, ""), ErrorCode.NOTICE_PERIOD_INVALID);
  }

  @Test
  @DisplayName("종료 일시를 읽을 수 없으면 거부한다 — 끝없음으로 바꾸지 않는다 (N14)")
  void badEnd() {
    assertRejected(withPeriod("2026-09-23T09:00", "다음 주"), ErrorCode.NOTICE_PERIOD_INVALID);
  }

  @Test
  @DisplayName("우선순위가 숫자가 아니면 거부한다")
  void badPriority() {
    NoticeInput base = valid();
    assertRejected(new NoticeInput(base.title(), base.body(), "", "", "ALL", "첫째",
      base.startsAt(), "", true), ErrorCode.NOTICE_PRIORITY_INVALID);
  }

  @Test
  @DisplayName("모르는 플랫폼은 거부한다")
  void badPlatform() {
    NoticeInput base = valid();
    assertRejected(new NoticeInput(base.title(), base.body(), "", "", "PC", "0",
      base.startsAt(), "", true), ErrorCode.NOTICE_PLATFORM_INVALID);
  }

  @Test
  @DisplayName("\"다시 보이게\"를 끄고 고치면 판이 그대로다 — 숨긴 사람에게 다시 뜨지 않는다")
  void update_withoutBump_keepsRevision() {
    AppNotice saved = service.create(valid(), null, "first");

    AppNotice updated = service.update(saved.getId(), with("베타 기간 안내(오타 수정)", "본문"),
      false, null, false, "second");

    assertThat(updated.getRevision()).isEqualTo(1);
    assertThat(updated.getTitle()).isEqualTo("베타 기간 안내(오타 수정)");
    assertThat(updated.getCreatedBy()).isEqualTo("first");
    assertThat(updated.getUpdatedBy()).isEqualTo("second");
  }

  @Test
  @DisplayName("\"다시 보이게\"를 켜고 저장하면 판이 오른다 — 숨긴 사람에게도 다시 뜬다")
  void update_withBump_raisesRevision() {
    AppNotice saved = service.create(valid(), null, "admin");

    service.update(saved.getId(), valid(), true, null, false, "admin");
    AppNotice updated = service.update(saved.getId(), valid(), true, null, false, "admin");

    assertThat(updated.getRevision()).isEqualTo(3);
  }

  @Test
  @DisplayName("고치다 검증에 걸리면 저장된 값은 그대로다")
  void update_rejected_keepsStored() {
    AppNotice saved = service.create(valid(), null, "admin");

    assertThatThrownBy(() -> service.update(saved.getId(), with("   ", "본문"), true, null, false, "admin"))
      .isInstanceOf(CustomException.class);

    assertThat(saved.getTitle()).isEqualTo("베타 기간 안내");
    assertThat(saved.getRevision()).isEqualTo(1);
  }

  @Test
  @DisplayName("없는 공지를 고치면 404 다")
  void update_missing() {
    assertThatThrownBy(() -> service.update("none", valid(), false, null, false, "admin"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_NOT_FOUND);
  }

  @Test
  @DisplayName("게시 중인 공지를 끄면 다음 조회부터 빠지고, 다시 켜면 돌아온다 (N17)")
  void toggle() {
    AppNotice saved = service.create(valid(), null, "admin");
    assertThat(service.publishedFor("IOS").notices()).hasSize(1);

    service.setEnabled(saved.getId(), false, "off-admin");
    assertThat(service.publishedFor("IOS").notices()).isEmpty();
    assertThat(saved.getUpdatedBy()).isEqualTo("off-admin");

    service.setEnabled(saved.getId(), true, "admin");
    assertThat(service.publishedFor("IOS").notices()).hasSize(1);
  }

  @Test
  @DisplayName("없는 공지를 켜고 끄면 404 다")
  void toggle_missing() {
    when(repository.findById("none")).thenReturn(Optional.empty());
    assertThatThrownBy(() -> service.setEnabled("none", true, "admin"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_NOT_FOUND);
  }
}
