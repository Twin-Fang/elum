package com.chuseok22.elumserver.routine.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
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
    routineImageStorage = new LocalFileRoutineImageStorage(new RoutineProperties(tempDir.toString()));
  }

  @Test
  @DisplayName("save로 저장한 이미지를 read로 다시 읽으면 동일한 바이트를 반환한다")
  void saveThenRead_returnsSameBytes() {
    byte[] originalBytes = {1, 2, 3, 4};
    GeneratedImage image = new GeneratedImage(originalBytes, "png");

    String savedKey = routineImageStorage.save("batch-1", 1, image);
    RoutineImageStorage.ImageContent content = routineImageStorage.read(savedKey);

    assertThat(content.bytes()).isEqualTo(originalBytes);
  }

  @Test
  @DisplayName("저장 결과는 경로가 아니라 열쇠다 — 저장 위치가 바뀌어도 이 값은 그대로 쓴다")
  void save_returnsKeyNotPath() {
    String key = routineImageStorage.save("batch-1", 2, new GeneratedImage(new byte[]{9}, "webp"));

    assertThat(key).isEqualTo("batch-1/2.webp");
    assertThat(key).doesNotContain(tempDir.toString());
  }

  @Test
  @DisplayName("열쇠로 바꾸기 전에 저장된 경로도 계속 읽힌다 — 마이그레이션이 늦어도 그림이 안 깨진다")
  void read_legacyAbsolutePath_stillWorks() {
    byte[] bytes = {5, 6, 7};
    String key = routineImageStorage.save("batch-2", 1, new GeneratedImage(bytes, "png"));
    String legacyPath = tempDir.resolve(key).toString();

    assertThat(routineImageStorage.read(legacyPath).bytes()).isEqualTo(bytes);
  }

  @Test
  @DisplayName("저장 폴더 밖을 가리키는 열쇠는 읽지 않는다")
  void read_pathTraversal_rejected() {
    assertThatThrownBy(() -> routineImageStorage.read("../../etc/passwd"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND));
  }

  @Test
  @DisplayName("한 번에 만든 그림을 통째로 지운다")
  void deleteBatch_removesAll() {
    String key = routineImageStorage.save("batch-3", 1, new GeneratedImage(new byte[]{1}, "png"));

    routineImageStorage.deleteBatch("batch-3");

    assertThatThrownBy(() -> routineImageStorage.read(key))
      .isInstanceOf(CustomException.class);
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
