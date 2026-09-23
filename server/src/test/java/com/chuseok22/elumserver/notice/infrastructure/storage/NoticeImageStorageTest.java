package com.chuseok22.elumserver.notice.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.notice.core.NoticeImageType;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * 공지 이미지 저장소 (이슈 #370). 일과 이미지 저장소({@code RoutineImageStorage})와 같은 관례 —
 * DB 에는 경로가 아니라 열쇠를 둔다.
 */
class NoticeImageStorageTest {

  @TempDir
  Path tempDir;

  private Path base;
  private NoticeImageStorage storage;

  @BeforeEach
  void setUp() {
    base = tempDir.resolve("notice-images");
    storage = new LocalFileNoticeImageStorage(new NoticeProperties(base.toString()));
  }

  @Test
  @DisplayName("저장 결과는 경로가 아니라 공지 아이디로 시작하는 열쇠다")
  void save_returnsKey() {
    String key = storage.save("notice-1", new byte[]{1, 2, 3}, NoticeImageType.WEBP);

    assertThat(key).startsWith("notice-1/").endsWith(".webp");
    assertThat(key).doesNotContain(base.toString());
  }

  @Test
  @DisplayName("같은 공지에 새로 올리면 열쇠가 달라진다 — 앱이 옛 그림을 캐시에서 꺼내지 않게")
  void save_twice_differentKeys() {
    String first = storage.save("notice-1", new byte[]{1}, NoticeImageType.PNG);
    String second = storage.save("notice-1", new byte[]{2}, NoticeImageType.PNG);

    assertThat(first).isNotEqualTo(second);
  }

  @Test
  @DisplayName("열쇠로 다시 읽으면 같은 바이트와 형식을 준다")
  void read_returnsBytesAndContentType() {
    String key = storage.save("notice-1", new byte[]{7, 8, 9}, NoticeImageType.JPEG);

    NoticeImageStorage.ImageContent content = storage.read(key);

    assertThat(content.bytes()).containsExactly(7, 8, 9);
    assertThat(content.contentType()).isEqualTo("image/jpeg");
  }

  @Test
  @DisplayName("지우면 파일이 사라지고 다시 읽으면 404 다 (N17)")
  void delete_removesFile() {
    String key = storage.save("notice-1", new byte[]{1}, NoticeImageType.PNG);

    storage.delete(key);

    assertThat(Files.exists(base.resolve(key))).isFalse();
    assertThatThrownBy(() -> storage.read(key))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_IMAGE_NOT_FOUND);
  }

  @Test
  @DisplayName("없는 열쇠나 빈 열쇠를 지워도 조용히 넘어간다 — 지우는 중에 다른 실패를 가리지 않게")
  void delete_missing_isQuiet() {
    storage.delete("notice-1/none.png");
    storage.delete(null);
    storage.delete(" ");
  }

  @Test
  @DisplayName("저장 폴더 밖을 가리키는 열쇠는 읽지도 지우지도 않는다")
  void outsideBase_refused() throws Exception {
    Path outside = tempDir.resolve("secret.png");
    Files.write(outside, new byte[]{1});

    assertThatThrownBy(() -> storage.read("../secret.png"))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_IMAGE_NOT_FOUND);
    storage.delete("../secret.png");
    assertThat(Files.exists(outside)).isTrue();
  }
}
