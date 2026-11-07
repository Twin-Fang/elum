package com.chuseok22.elumserver.common.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.properties.MinioStorageProperties;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

/**
 * 실제 MinIO 왕복: 환경 변수를 준 경우만 실행 (ELUM_MINIO_TEST_ENDPOINT, _ACCESS_KEY, _SECRET_KEY, _BUCKET)
 * 가짜로는 SDK 호출과 없는 객체 오류 판정을 확인할 수 없음
 */
@EnabledIfEnvironmentVariable(named = "ELUM_MINIO_TEST_ENDPOINT", matches = ".+")
class MinioObjectStoreIntegrationTest {

  private static final byte[] IMAGE_BYTES = {1, 2, 3, 4};

  private final ObjectStore objectStore = new MinioObjectStore(new MinioStorageProperties(
    System.getenv("ELUM_MINIO_TEST_ENDPOINT"), System.getenv("ELUM_MINIO_TEST_ACCESS_KEY"),
    System.getenv("ELUM_MINIO_TEST_SECRET_KEY"), System.getenv("ELUM_MINIO_TEST_BUCKET"), false));

  @Test
  @DisplayName("쓴 객체를 읽고, 지우면 없음으로 돌아오고, 폴더 삭제는 그 폴더만 지운다")
  void putReadDelete_roundTrip() {
    String folder = "integration-" + UUID.randomUUID();
    String first = folder + "/a/1.png";
    String second = folder + "/a/2.png";
    String other = folder + "-other/1.png";

    objectStore.put(first, IMAGE_BYTES, "image/png");
    objectStore.put(second, IMAGE_BYTES, "image/png");
    objectStore.put(other, IMAGE_BYTES, "image/png");
    assertThat(objectStore.read(first)).hasValue(IMAGE_BYTES);
    assertThat(objectStore.read(folder + "/none.png")).isEmpty();

    objectStore.delete(first);
    assertThat(objectStore.read(first)).isEmpty();

    objectStore.deleteFolder(folder);
    assertThat(objectStore.read(second)).isEmpty();
    assertThat(objectStore.read(other)).hasValue(IMAGE_BYTES);

    objectStore.delete(other);
  }
}
