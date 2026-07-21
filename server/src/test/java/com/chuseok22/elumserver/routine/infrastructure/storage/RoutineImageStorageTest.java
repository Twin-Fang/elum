package com.chuseok22.elumserver.routine.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import java.nio.file.Path;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class RoutineImageStorageTest {

  @TempDir
  Path tempDir;

  private RoutineImageStorage routineImageStorage;

  @BeforeEach
  void setUp() {
    routineImageStorage = new RoutineImageStorage(new RoutineProperties(tempDir.toString()));
  }

  @Test
  @DisplayName("save로 저장한 이미지를 read로 다시 읽으면 동일한 바이트를 반환한다")
  void saveThenRead_returnsSameBytes() {
    byte[] originalBytes = {1, 2, 3, 4};
    GeminiImageClient.GeneratedImage image = new GeminiImageClient.GeneratedImage(originalBytes, "png");

    String savedPath = routineImageStorage.save("batch-1", 1, image);
    RoutineImageStorage.ImageContent content = routineImageStorage.read(savedPath);

    assertThat(content.bytes()).isEqualTo(originalBytes);
  }

  @Test
  @DisplayName("존재하지 않는 경로를 read하면 ROUTINE_STEP_IMAGE_NOT_FOUND를 던진다")
  void read_missingFile_throwsCustomException() {
    String missingPath = tempDir.resolve("missing.png").toString();

    assertThatThrownBy(() -> routineImageStorage.read(missingPath))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND));
  }
}
