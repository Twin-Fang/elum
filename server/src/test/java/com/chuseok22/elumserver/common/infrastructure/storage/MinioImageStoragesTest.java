package com.chuseok22.elumserver.common.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.MinioStorageProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import com.chuseok22.elumserver.notice.core.NoticeImageType;
import com.chuseok22.elumserver.notice.infrastructure.storage.MinioNoticeImageStorage;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.MinioRoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.talk.infrastructure.storage.MinioTalkImageStorage;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * 전환 중 사용자 문제 겨냥: 옛 그림이 안 보임, 지운 그림이 다시 보임, 저장 실패가 조용히 묻힘
 */
class MinioImageStoragesTest {

  private static final byte[] IMAGE_BYTES = {1, 2, 3};

  @TempDir
  Path tempDir;

  private final MemoryObjectStore objectStore = new MemoryObjectStore();

  private MinioRoutineImageStorage routineStorage(boolean isFallbackToLocal) {
    return new MinioRoutineImageStorage(
      objectStore, new RoutineProperties(tempDir.toString()), properties(isFallbackToLocal));
  }

  private MinioTalkImageStorage talkStorage(boolean isFallbackToLocal) {
    return new MinioTalkImageStorage(
      objectStore, new TalkProperties(tempDir.toString(), null), properties(isFallbackToLocal));
  }

  private MinioNoticeImageStorage noticeStorage(boolean isFallbackToLocal) {
    return new MinioNoticeImageStorage(
      objectStore, new NoticeProperties(tempDir.toString()), properties(isFallbackToLocal));
  }

  private static MinioStorageProperties properties(boolean isFallbackToLocal) {
    return new MinioStorageProperties("http://minio:9000", "user", "secret", "elum", isFallbackToLocal);
  }

  private void writeLocalFile(String key) throws IOException {
    Path file = tempDir.resolve(key);
    Files.createDirectories(file.getParent());
    Files.write(file, IMAGE_BYTES);
  }

  @Test
  @DisplayName("새 카드 그림은 로컬 폴더 구조와 같은 이름으로 MinIO 에 쓰이고 같은 열쇠로 읽힌다")
  void routineSave_writesToAreaAndReadsBack() {
    RoutineImageStorage storage = routineStorage(false);

    String key = storage.save("batch-1", 2, new GeneratedImage(IMAGE_BYTES, "png"));

    assertThat(key).isEqualTo("batch-1/2.png");
    assertThat(objectStore.objects).containsKey("routine-images/batch-1/2.png");
    assertThat(storage.read(key).bytes()).isEqualTo(IMAGE_BYTES);
    assertThat(storage.read(key).contentType()).isEqualTo("image/png");
    assertThat(tempDir.resolve(key)).doesNotExist();
  }

  @Test
  @DisplayName("아직 복사되지 않은 옛 그림은 대체가 켜져 있으면 로컬에서 읽힌다")
  void read_missingInMinio_fallsBackToLocal() throws IOException {
    writeLocalFile("batch-1/1.png");

    assertThat(routineStorage(true).read("batch-1/1.png").bytes()).isEqualTo(IMAGE_BYTES);
  }

  @Test
  @DisplayName("MinIO 장애 때도 대체가 켜져 있으면 로컬 그림이 보인다")
  void read_minioDown_fallsBackToLocal() throws IOException {
    writeLocalFile("batch-1/1.png");
    objectStore.isDown = true;

    assertThat(routineStorage(true).read("batch-1/1.png").bytes()).isEqualTo(IMAGE_BYTES);
  }

  @Test
  @DisplayName("대체를 끄면 로컬에 파일이 있어도 저장소별 없음 오류가 난다")
  void read_fallbackOff_throwsAreaNotFound() throws IOException {
    writeLocalFile("x/1.png");

    assertThrowsCode(() -> routineStorage(false).read("x/1.png"), ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND);
    assertThrowsCode(() -> talkStorage(false).read("x/1.png"), ErrorCode.TALK_IMAGE_NOT_FOUND);
    assertThrowsCode(() -> noticeStorage(false).read("x/1.png"), ErrorCode.NOTICE_IMAGE_NOT_FOUND);
  }

  @Test
  @DisplayName("저장 실패는 저장소별 기존 오류로 드러난다")
  void save_minioDown_throwsExistingCodes() {
    objectStore.isDown = true;
    GeneratedImage image = new GeneratedImage(IMAGE_BYTES, "png");

    assertThrowsCode(() -> routineStorage(true).save("b", 1, image), ErrorCode.ROUTINE_AI_GENERATION_FAILED);
    assertThrowsCode(() -> routineStorage(true).saveUploaded("s", IMAGE_BYTES), ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
    assertThrowsCode(() -> talkStorage(true).save("p", 1, IMAGE_BYTES, "image/png"), ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
    assertThrowsCode(() -> noticeStorage(true).save("n", IMAGE_BYTES, NoticeImageType.PNG), ErrorCode.NOTICE_IMAGE_SAVE_FAILED);
  }

  @Test
  @DisplayName("지운 그림은 양쪽에서 사라져 대체 읽기로 다시 보이지 않는다")
  void delete_removesBothCopies() throws IOException {
    RoutineImageStorage storage = routineStorage(true);
    String key = storage.saveUploaded("step-1", IMAGE_BYTES);
    writeLocalFile(key);

    storage.delete(key);

    assertThat(objectStore.objects).isEmpty();
    assertThat(tempDir.resolve(key)).doesNotExist();
    assertThrowsCode(() -> storage.read(key), ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND);
  }

  @Test
  @DisplayName("이야기 글 삭제와 생성 실패 묶음 삭제는 그 폴더만 양쪽에서 지운다")
  void deleteFolder_removesOnlyThatFolder() throws IOException {
    TalkImageStorage talk = talkStorage(true);
    talk.save("post-1", 1, IMAGE_BYTES, "image/jpeg");
    talk.save("post-2", 1, IMAGE_BYTES, "image/jpeg");
    writeLocalFile("post-1/1.jpg");

    talk.deletePost("post-1");

    assertThat(objectStore.objects).containsOnlyKeys("talk-images/post-2/1.jpg");
    assertThat(tempDir.resolve("post-1")).doesNotExist();
  }

  @Test
  @DisplayName("삭제 장애는 삭제 흐름을 막지 않는다")
  void delete_minioDown_doesNotThrow() {
    objectStore.isDown = true;
    NoticeImageStorage notice = noticeStorage(true);

    notice.delete("notice-1/a.png");
  }

  @Test
  @DisplayName("옛 DB 값의 경로 전체 열쇠도 같은 객체를 가리킨다")
  void read_legacyFullPathKey_findsObject() {
    objectStore.objects.put("routine-images/abc/1.png", IMAGE_BYTES);

    assertThat(routineStorage(false).read("data/routine-images/abc/1.png").bytes()).isEqualTo(IMAGE_BYTES);
  }

  @Test
  @DisplayName("구역 밖을 가리키는 열쇠로는 다른 구역 그림을 읽지 못한다")
  void read_traversalKey_isRejected() {
    objectStore.objects.put("talk-images/secret/1.jpg", IMAGE_BYTES);

    assertThrowsCode(() -> routineStorage(false).read("../talk-images/secret/1.jpg"), ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND);
  }

  private static void assertThrowsCode(Runnable action, ErrorCode expectedCode) {
    assertThatThrownBy(action::run)
      .isInstanceOf(CustomException.class)
      .satisfies(error -> assertThat(((CustomException) error).getErrorCode()).isEqualTo(expectedCode));
  }

  /// 저장소 동작 대역: 메모리 Map, isDown 이면 전부 장애
  @Test
  @DisplayName("카드 그림 MinIO: AI 그림은 webp 로 저장하고, 옛 png 는 같은 이름의 .webp 사본을 만든다 (#1219)")
  void routine_minio_compressesAndCopiesWebp() {
    byte[] webpBytes = {9, 9};
    MinioRoutineImageStorage storage = new MinioRoutineImageStorage(objectStore,
      new RoutineProperties(tempDir.toString()), properties(false),
      image -> Optional.of(new GeneratedImage(webpBytes, "webp")));

    assertThat(storage.save("batch-1", 1, new GeneratedImage(IMAGE_BYTES, "png"))).isEqualTo("batch-1/1.webp");
    assertThat(objectStore.objects).containsKey("routine-images/batch-1/1.webp");

    objectStore.objects.put("routine-images/batch-2/1.png", IMAGE_BYTES);
    assertThat(storage.saveWebpCopy("batch-2/1.png")).contains("batch-2/1.webp");
    assertThat(objectStore.objects.get("routine-images/batch-2/1.webp")).isEqualTo(webpBytes);
    assertThat(objectStore.objects).containsKey("routine-images/batch-2/1.png");
    assertThat(storage.saveWebpCopy("batch-2/missing.png")).isEmpty();
  }

  @Test
  @DisplayName("카드 그림 MinIO: 열쇠에 없는 오래된 객체만 지우고, 쓰는 그림·옛 형식 열쇠·방금 만든 그림은 남긴다 (#1216)")
  void routine_minio_deletesUnreferencedOnly() {
    MinioRoutineImageStorage storage = routineStorage(false);
    objectStore.objects.put("routine-images/batch-live/1.png", IMAGE_BYTES);
    objectStore.objects.put("routine-images/batch-legacy/1.png", IMAGE_BYTES);
    objectStore.objects.put("routine-images/batch-deleted/1.png", IMAGE_BYTES);
    objectStore.objects.put("routine-images/batch-new/1.png", IMAGE_BYTES);
    objectStore.objects.put("talk-images/post-1/1.png", IMAGE_BYTES);
    objectStore.recentObjectNames.add("routine-images/batch-new/1.png");

    int deletedCount = storage.deleteUnreferenced(
      List.of("batch-live/1.png", "data/routine-images/batch-legacy/1.png"), Instant.now().minusSeconds(3_600));

    assertThat(deletedCount).isEqualTo(1);
    assertThat(objectStore.objects).doesNotContainKey("routine-images/batch-deleted/1.png")
      .containsKeys("routine-images/batch-live/1.png", "routine-images/batch-legacy/1.png",
        "routine-images/batch-new/1.png", "talk-images/post-1/1.png");
  }

  @Test
  @DisplayName("카드 그림 MinIO: 목록을 못 읽으면 던진다 — 정리 작업이 아무것도 지우지 않게")
  void routine_minio_listFails_throws() {
    MinioRoutineImageStorage storage = routineStorage(false);
    objectStore.isDown = true;

    assertThatThrownBy(() -> storage.deleteUnreferenced(List.of("a/1.png"), Instant.now()))
      .isInstanceOf(ObjectStoreException.class);
  }

  private static final class MemoryObjectStore implements ObjectStore {

    private final Map<String, byte[]> objects = new HashMap<>();
    private boolean isDown;

    @Override
    public void put(String objectName, byte[] bytes, String contentType) {
      failIfDown();
      objects.put(objectName, bytes);
    }

    @Override
    public Optional<byte[]> read(String objectName) {
      failIfDown();
      return Optional.ofNullable(objects.get(objectName));
    }

    @Override
    public void delete(String objectName) {
      failIfDown();
      objects.remove(objectName);
    }

    @Override
    public void deleteFolder(String folderName) {
      failIfDown();
      objects.keySet().removeIf(name -> name.startsWith(folderName + "/"));
    }

    // 시험용 수정 시각: 기본은 오래전, recentObjectNames 는 지금
    private final Set<String> recentObjectNames = new java.util.HashSet<>();

    @Override
    public List<StoredObject> list(String folderName) {
      failIfDown();
      return objects.keySet().stream()
        .filter(name -> name.startsWith(folderName + "/"))
        .map(name -> new StoredObject(name, recentObjectNames.contains(name) ? Instant.now() : Instant.EPOCH))
        .toList();
    }

    private void failIfDown() {
      if (isDown) {
        throw new ObjectStoreException("down", null);
      }
    }
  }
}
