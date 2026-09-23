package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeInput;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notice.infrastructure.storage.LocalFileNoticeImageStorage;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage.ImageContent;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.mock.web.MockMultipartFile;

/**
 * 공지 이미지 올리기·바꾸기·지우기·내보내기 (이슈 #370, N16·N17).
 *
 * <p>저장소는 목이 아니라 실제 디스크(임시 폴더)를 쓴다. "지우면 파일도 지운다"는
 * 파일이 실제로 사라졌는지로만 확인할 수 있다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NoticeImageFlowTest {

  private static final Instant NOW = Instant.parse("2026-09-23T03:00:00Z"); // 한국 12:00
  private static final byte[] PNG_HEAD = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};

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
    doAnswer(invocation -> stored.remove(invocation.<AppNotice>getArgument(0)))
      .when(repository).delete(any(AppNotice.class));
  }

  private NoticeInput input(boolean enabled, String startsAt) {
    return new NoticeInput("공지", "본문", "", "", "ALL", "0", startsAt, "", enabled);
  }

  private MockMultipartFile png(int size) {
    byte[] bytes = Arrays.copyOf(PNG_HEAD, Math.max(size, PNG_HEAD.length));
    return new MockMultipartFile("image", "event.png", "image/png", bytes);
  }

  private long storedFiles() throws IOException {
    try (Stream<Path> files = Files.walk(tempDir)) {
      return files.filter(Files::isRegularFile).count();
    }
  }

  @Test
  @DisplayName("png 를 올리면 파일을 저장하고 열쇠를 공지에 적는다")
  void create_withImage_storesFile() throws IOException {
    AppNotice saved = service.create(input(true, "2026-09-23T09:00"), png(1024), "admin");

    assertThat(saved.getImageKey()).startsWith(saved.getId() + "/").endsWith(".png");
    assertThat(Files.exists(tempDir.resolve(saved.getImageKey()))).isTrue();
    assertThat(storedFiles()).isEqualTo(1);
  }

  @Test
  @DisplayName("2MB 는 받고 2MB 를 1바이트라도 넘으면 거부한다 — 공지도 저장하지 않는다 (N16)")
  void imageTooLarge_rejected() throws IOException {
    assertThat(service.create(input(true, "2026-09-23T09:00"), png(2 * 1024 * 1024), "admin")
      .getImageKey()).isNotNull();
    stored.clear();

    assertThatThrownBy(() -> service.create(input(true, "2026-09-23T09:00"), png(2 * 1024 * 1024 + 1), "admin"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_IMAGE_TOO_LARGE);
    assertThat(stored).isEmpty();
    assertThat(storedFiles()).isEqualTo(1); // 앞서 받은 2MB 한 장뿐
  }

  @Test
  @DisplayName("이름만 png 인 gif 는 거부한다 — 서명으로 가린다 (N16)")
  void disguisedGif_rejected() throws IOException {
    MockMultipartFile gif = new MockMultipartFile("image", "event.png", "image/png",
      "GIF89a-not-really-png".getBytes());

    assertThatThrownBy(() -> service.create(input(true, "2026-09-23T09:00"), gif, "admin"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_IMAGE_INVALID_TYPE);
    verify(repository, never()).save(any());
    assertThat(storedFiles()).isZero();
  }

  @Test
  @DisplayName("파일 칸을 비워 보내면(빈 파일) 이미지 없이 저장한다")
  void emptyFile_meansNoImage() {
    MockMultipartFile empty = new MockMultipartFile("image", "", "application/octet-stream", new byte[0]);

    assertThat(service.create(input(true, "2026-09-23T09:00"), empty, "admin").getImageKey()).isNull();
  }

  @Test
  @DisplayName("새 그림으로 바꾸면 옛 파일을 지운다 — 쓰지 않는 파일이 쌓이지 않는다")
  void replaceImage_deletesOld() throws IOException {
    AppNotice saved = service.create(input(true, "2026-09-23T09:00"), png(100), "admin");
    String oldKey = saved.getImageKey();

    service.update(saved.getId(), input(true, "2026-09-23T09:00"), false, png(200), false, "admin");

    assertThat(saved.getImageKey()).isNotEqualTo(oldKey);
    assertThat(Files.exists(tempDir.resolve(oldKey))).isFalse();
    assertThat(Files.exists(tempDir.resolve(saved.getImageKey()))).isTrue();
  }

  @Test
  @DisplayName("이미지 지우기를 켜고 저장하면 파일과 열쇠를 함께 지운다")
  void removeImage() throws IOException {
    AppNotice saved = service.create(input(true, "2026-09-23T09:00"), png(100), "admin");

    service.update(saved.getId(), input(true, "2026-09-23T09:00"), false, null, true, "admin");

    assertThat(saved.getImageKey()).isNull();
    assertThat(storedFiles()).isZero();
  }

  @Test
  @DisplayName("고치다 검증에 걸리면 옛 그림은 그대로 남는다")
  void update_rejected_keepsOldImage() {
    AppNotice saved = service.create(input(true, "2026-09-23T09:00"), png(100), "admin");
    String oldKey = saved.getImageKey();

    assertThatThrownBy(() -> service.update(saved.getId(), input(true, ""), false, png(100), true, "admin"))
      .isInstanceOf(CustomException.class);

    assertThat(saved.getImageKey()).isEqualTo(oldKey);
    assertThat(Files.exists(tempDir.resolve(oldKey))).isTrue();
  }

  @Test
  @DisplayName("공지를 지우면 이미지 파일도 지운다 (N17)")
  void delete_removesImage() throws IOException {
    AppNotice saved = service.create(input(true, "2026-09-23T09:00"), png(100), "admin");

    service.delete(saved.getId());

    verify(repository).delete(saved);
    assertThat(storedFiles()).isZero();
    assertThat(service.publishedFor("IOS").notices()).isEmpty();
  }

  @Test
  @DisplayName("없는 공지를 지우면 404 다")
  void delete_missing() {
    assertThatThrownBy(() -> service.delete("none"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_NOT_FOUND);
  }

  @Test
  @DisplayName("게시 중인 공지의 이미지는 앱에 내보낸다")
  void liveImage_served() {
    AppNotice saved = service.create(input(true, "2026-09-23T09:00"), png(100), "admin");

    ImageContent content = service.liveImage(saved.getId());

    assertThat(content.contentType()).isEqualTo("image/png");
    assertThat(content.bytes()).hasSize(100);
  }

  @Test
  @DisplayName("게시 중이 아니면(꺼짐, 예약) 이미지도 404 다")
  void notLiveImage_404() {
    AppNotice off = service.create(input(false, "2026-09-23T09:00"), png(100), "admin");
    AppNotice scheduled = service.create(input(true, "2026-09-24T09:00"), png(100), "admin");

    for (String id : List.of(off.getId(), scheduled.getId(), "none")) {
      assertThatThrownBy(() -> service.liveImage(id))
        .isInstanceOf(CustomException.class)
        .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_IMAGE_NOT_FOUND);
    }
  }

  @Test
  @DisplayName("관리자는 게시 전 공지의 이미지도 본다 — 편집 화면 미리보기")
  void adminImage_anyStatus() {
    AppNotice off = service.create(input(false, "2026-09-23T09:00"), png(100), "admin");

    assertThat(service.adminImage(off.getId()).bytes()).hasSize(100);
  }

  @Test
  @DisplayName("이미지가 없는 게시 중 공지의 이미지를 부르면 404 다")
  void liveWithoutImage_404() {
    AppNotice saved = service.create(input(true, "2026-09-23T09:00"), null, "admin");

    assertThatThrownBy(() -> service.liveImage(saved.getId()))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_IMAGE_NOT_FOUND);
  }
}
