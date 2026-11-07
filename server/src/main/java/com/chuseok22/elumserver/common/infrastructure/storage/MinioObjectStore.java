package com.chuseok22.elumserver.common.infrastructure.storage;

import com.chuseok22.elumserver.common.infrastructure.properties.MinioStorageProperties;
import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.GetObjectResponse;
import io.minio.ListObjectsArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import io.minio.Result;
import io.minio.errors.ErrorResponseException;
import io.minio.messages.Item;
import java.io.ByteArrayInputStream;
import java.util.Optional;
import java.util.stream.Stream;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * MinIO 객체 저장소 (elum.store.image=minio 일 때만 등록)
 * 설정 누락은 기동 실패, 접속 실패는 경고만 (MinIO 재시작 중에도 서버는 뜸)
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "elum.store.image", havingValue = "minio")
public class MinioObjectStore implements ObjectStore {

  private static final long CONNECT_TIMEOUT_MILLISECONDS = 3_000;
  private static final long TRANSFER_TIMEOUT_MILLISECONDS = 20_000;
  // S3 오류 코드: 없는 객체
  private static final String NO_SUCH_KEY_CODE = "NoSuchKey";
  // 크기를 아는 바이트 배열이라 분할 크기 자동
  private static final long AUTO_PART_SIZE = -1;

  private final MinioClient minioClient;
  private final String bucket;

  public MinioObjectStore(MinioStorageProperties properties) {
    requireConfigured(properties);
    this.bucket = properties.bucket();
    this.minioClient = MinioClient.builder()
      .endpoint(properties.endpoint())
      .credentials(properties.accessKey(), properties.secretKey())
      .build();
    this.minioClient.setTimeout(
      CONNECT_TIMEOUT_MILLISECONDS, TRANSFER_TIMEOUT_MILLISECONDS, TRANSFER_TIMEOUT_MILLISECONDS);
    warnIfBucketUnavailable();
  }

  @Override
  public void put(String objectName, byte[] bytes, String contentType) {
    try (ByteArrayInputStream stream = new ByteArrayInputStream(bytes)) {
      minioClient.putObject(PutObjectArgs.builder()
        .bucket(bucket).object(objectName)
        .stream(stream, bytes.length, AUTO_PART_SIZE)
        .contentType(contentType)
        .build());
    } catch (Exception e) {
      throw new ObjectStoreException("minio put failed : " + objectName, e);
    }
  }

  @Override
  public Optional<byte[]> read(String objectName) {
    try (GetObjectResponse response = minioClient.getObject(
      GetObjectArgs.builder().bucket(bucket).object(objectName).build())) {
      return Optional.of(response.readAllBytes());
    } catch (ErrorResponseException e) {
      if (NO_SUCH_KEY_CODE.equals(e.errorResponse().code())) {
        return Optional.empty();
      }
      throw new ObjectStoreException("minio read failed : " + objectName, e);
    } catch (Exception e) {
      throw new ObjectStoreException("minio read failed : " + objectName, e);
    }
  }

  @Override
  public void delete(String objectName) {
    try {
      minioClient.removeObject(RemoveObjectArgs.builder().bucket(bucket).object(objectName).build());
    } catch (Exception e) {
      throw new ObjectStoreException("minio delete failed : " + objectName, e);
    }
  }

  @Override
  public void deleteFolder(String folderName) {
    try {
      Iterable<Result<Item>> objects = minioClient.listObjects(ListObjectsArgs.builder()
        .bucket(bucket).prefix(folderName + "/").recursive(true).build());
      for (Result<Item> object : objects) {
        delete(object.get().objectName());
      }
    } catch (ObjectStoreException e) {
      throw e;
    } catch (Exception e) {
      throw new ObjectStoreException("minio delete folder failed : " + folderName, e);
    }
  }

  // 필수값 4개: 주소, 계정, 비밀번호, 버킷
  private static void requireConfigured(MinioStorageProperties properties) {
    boolean hasMissingValue = Stream.of(
        properties.endpoint(), properties.accessKey(), properties.secretKey(), properties.bucket())
      .anyMatch(value -> value == null || value.isBlank());
    if (hasMissingValue) {
      throw new IllegalStateException(
        "elum.store.image=minio needs elum.store.minio endpoint, access-key, secret-key, bucket");
    }
  }

  private void warnIfBucketUnavailable() {
    try {
      if (!minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build())) {
        log.error("[image store] bucket missing : bucket={}", bucket);
      }
    } catch (Exception e) {
      log.error("[image store] minio unreachable at startup : bucket={}, error={}",
        bucket, e.getClass().getSimpleName());
    }
  }
}
