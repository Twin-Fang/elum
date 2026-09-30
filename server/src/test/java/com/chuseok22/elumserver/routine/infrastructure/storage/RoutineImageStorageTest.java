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

  // ── 카드 사진 업로드 (이슈 #455) ──────────────────────

  @Test
  @DisplayName("saveUploaded 는 {stepId}/{UUID}.jpg 열쇠를 돌려주고 같은 바이트를 읽을 수 있다")
  void saveUploaded_keyFormat() {
    byte[] bytes = {1, 2, 3};

    String key = routineImageStorage.saveUploaded("step-1", bytes);

    assertThat(key).matches("step-1/[0-9a-f-]{36}\\.jpg");
    assertThat(routineImageStorage.read(key).bytes()).isEqualTo(bytes);
    assertThat(routineImageStorage.read(key).contentType()).isEqualTo("image/jpeg");
  }

  @Test
  @DisplayName("saveUploaded 는 매번 새 열쇠다 — 열쇠가 바뀌는 것이 앱의 캐시 갱신 신호다")
  void saveUploaded_newKeyEveryTime() {
    String first = routineImageStorage.saveUploaded("step-1", new byte[]{1});
    String second = routineImageStorage.saveUploaded("step-1", new byte[]{2});

    assertThat(first).isNotEqualTo(second);
    assertThat(routineImageStorage.read(first).bytes()).containsExactly(1);
  }

  @Test
  @DisplayName("saveUploaded 후 임시 파일이 남지 않는다")
  void saveUploaded_noTempLeft() throws Exception {
    routineImageStorage.saveUploaded("step-1", new byte[]{1});

    try (var files = java.nio.file.Files.list(tempDir.resolve("step-1"))) {
      assertThat(files.map(f -> f.getFileName().toString())).noneMatch(name -> name.endsWith(".tmp"));
    }
  }

  @Test
  @DisplayName("saveUploaded 는 저장 폴더 밖을 가리키는 stepId 를 거절한다")
  void saveUploaded_pathTraversal_rejected() {
    for (String evil : new String[]{"../evil", "../../etc", "/abs"}) {
      assertThatThrownBy(() -> routineImageStorage.saveUploaded(evil, new byte[]{1}))
        .isInstanceOf(CustomException.class)
        .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
          .isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED));
    }
    assertThat(tempDir.getParent().resolve("evil")).doesNotExist();
  }

  @Test
  @DisplayName("쓰기가 실패하면 SAVE_FAILED — AI 생성 실패 코드를 쓰지 않는다")
  void saveUploaded_ioFailure_usesSaveFailedCode() throws Exception {
    // 폴더 자리에 파일이 있어 디렉터리를 만들 수 없다
    java.nio.file.Files.writeString(tempDir.resolve("step-blocked"), "file");

    assertThatThrownBy(() -> routineImageStorage.saveUploaded("step-blocked", new byte[]{1}))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED));
  }

  @Test
  @DisplayName("delete 는 그 파일 하나만 지우고 같은 폴더의 다른 그림은 남긴다")
  void delete_removesOnlyThatKey() {
    String keep = routineImageStorage.save("step-1", 1, new GeneratedImage(new byte[]{1}, "png"));
    String gone = routineImageStorage.saveUploaded("step-1", new byte[]{2});

    routineImageStorage.delete(gone);

    assertThatThrownBy(() -> routineImageStorage.read(gone)).isInstanceOf(CustomException.class);
    assertThat(routineImageStorage.read(keep).bytes()).containsExactly(1);
  }

  @Test
  @DisplayName("delete 는 없는 열쇠·빈 값·폴더 밖 열쇠에도 던지지 않고 밖의 파일을 지우지 않는다")
  void delete_isSafe() throws Exception {
    Path outside = tempDir.getParent().resolve("outside-" + java.util.UUID.randomUUID() + ".txt");
    java.nio.file.Files.writeString(outside, "keep");
    try {
      routineImageStorage.delete("nope/none.jpg");
      routineImageStorage.delete(null);
      routineImageStorage.delete(" ");
      routineImageStorage.delete("../" + outside.getFileName());

      assertThat(outside).exists();
    } finally {
      java.nio.file.Files.deleteIfExists(outside);
    }
  }

  @Test
  @DisplayName("Content-Type 은 확장자로 정한다 — jpg·jpeg·png·webp, 모르면 octet-stream")
  void read_contentTypeByExtension() {
    assertThat(routineImageStorage.read(routineImageStorage.save("b", 1, new GeneratedImage(new byte[]{1}, "png")))
      .contentType()).isEqualTo("image/png");
    assertThat(routineImageStorage.read(routineImageStorage.save("b", 2, new GeneratedImage(new byte[]{1}, "jpg")))
      .contentType()).isEqualTo("image/jpeg");
    assertThat(routineImageStorage.read(routineImageStorage.save("b", 3, new GeneratedImage(new byte[]{1}, "JPEG")))
      .contentType()).isEqualTo("image/jpeg");
    assertThat(routineImageStorage.read(routineImageStorage.save("b", 4, new GeneratedImage(new byte[]{1}, "webp")))
      .contentType()).isEqualTo("image/webp");
    assertThat(routineImageStorage.read(routineImageStorage.save("b", 5, new GeneratedImage(new byte[]{1}, "xyz")))
      .contentType()).isEqualTo("application/octet-stream");
  }
}
