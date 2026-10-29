package com.chuseok22.elumserver.talk.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class LocalFileTalkImageStorageTest {

  @TempDir
  Path tempDir;

  private TalkImageStorage talkImageStorage;

  @BeforeEach
  void setUp() {
    talkImageStorage = new LocalFileTalkImageStorage(new TalkProperties(tempDir.toString(), null));
  }

  @Test
  @DisplayName("저장한 그림을 열쇠로 다시 읽으면 같은 바이트와 형식이 나온다")
  void save_thenRead_roundTrips() {
    byte[] originalBytes = {1, 2, 3, 4};

    String key = talkImageStorage.save("post-1", 2, originalBytes, "image/jpeg");
    RoutineImageStorage.ImageContent content = talkImageStorage.read(key);

    assertThat(key).isEqualTo("post-1/2.jpg");
    assertThat(content.bytes()).isEqualTo(originalBytes);
    assertThat(content.contentType()).isEqualTo("image/jpeg");
  }

  @Test
  @DisplayName("저장 폴더 밖을 가리키는 글 번호는 거절한다")
  void save_pathEscape_rejected() {
    assertThatThrownBy(() -> talkImageStorage.save("../x", 1, new byte[]{1}, "image/jpeg"))
      .isInstanceOf(CustomException.class);
    assertThat(Files.exists(tempDir.getParent().resolve("x"))).isFalse();
  }

  @Test
  @DisplayName("없는 열쇠를 읽으면 그림 없음 오류다")
  void read_missingKey_throwsNotFound() {
    assertThatThrownBy(() -> talkImageStorage.read("post-9/1.jpg"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_IMAGE_NOT_FOUND));
  }

  @Test
  @DisplayName("글 하나를 지우면 그 글의 그림 폴더가 통째로 사라진다")
  void deletePost_removesDirectory() {
    talkImageStorage.save("post-1", 1, new byte[]{1}, "image/jpeg");
    talkImageStorage.save("post-1", 2, new byte[]{2}, "image/png");
    talkImageStorage.save("post-2", 1, new byte[]{3}, "image/jpeg");

    talkImageStorage.deletePost("post-1");

    assertThat(Files.exists(tempDir.resolve("post-1"))).isFalse();
    assertThat(Files.exists(tempDir.resolve("post-2/1.jpg"))).isTrue();
  }

  @Test
  @DisplayName("글 폴더가 없어도 지우기는 조용히 끝난다")
  void deletePost_missingDirectory_doesNothing() {
    talkImageStorage.deletePost("post-none");
    talkImageStorage.deletePost("../x");
  }
}
