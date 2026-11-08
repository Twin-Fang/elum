package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.MinioStorageProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import com.chuseok22.elumserver.common.infrastructure.storage.ObjectStore;
import com.chuseok22.elumserver.common.infrastructure.storage.ObjectStoreException;
import com.chuseok22.elumserver.common.infrastructure.storage.StoredImageArea;
import com.chuseok22.elumserver.common.infrastructure.storage.StoredImageFormat;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 카드 그림 MinIO 구현: 쓰기 MinIO, 읽기 MinIO > 로컬 대체, 삭제 양쪽
 * 삭제를 양쪽에서 하는 이유: 로컬에 남으면 지운 그림이 읽기 대체로 다시 보임
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "elum.store.image", havingValue = "minio")
public class MinioRoutineImageStorage implements RoutineImageStorage {

  private static final String AREA_NAME = "routine-images";

  private final StoredImageArea imageArea;
  private final RoutineImageStorage localStorage;
  private final boolean isFallbackToLocal;

  public MinioRoutineImageStorage(
    ObjectStore objectStore, RoutineProperties routineProperties, MinioStorageProperties minioProperties
  ) {
    this.imageArea = new StoredImageArea(objectStore, AREA_NAME);
    this.localStorage = new LocalFileRoutineImageStorage(routineProperties);
    this.isFallbackToLocal = minioProperties.fallbackToLocal();
  }

  @Override
  public String save(String batchId, Integer stepOrder, GeneratedImage image) {
    String key = batchId + "/" + stepOrder + "." + image.extension();
    return putOrThrow(key, image.bytes(), ErrorCode.ROUTINE_AI_GENERATION_FAILED);
  }

  @Override
  public void deleteBatch(String batchId) {
    if (batchId == null || batchId.isBlank()) {
      return;
    }
    imageArea.deleteFolderQuietly(batchId);
    localStorage.deleteBatch(batchId);
  }

  @Override
  public String saveUploaded(String stepId, byte[] bytes) {
    return putOrThrow(stepId + "/" + UUID.randomUUID() + ".jpg", bytes, ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
  }

  @Override
  public String saveImported(String stepId, ImageContent content) {
    String fileName = "talk-" + UUID.randomUUID() + "." + StoredImageFormat.extensionOf(content.contentType());
    return putOrThrow(stepId + "/" + fileName, content.bytes(), ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
  }

  @Override
  public String saveRegenerated(String stepId, GeneratedImage image) {
    String fileName = "ai-" + UUID.randomUUID() + "." + image.extension();
    return putOrThrow(stepId + "/" + fileName, image.bytes(), ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
  }

  @Override
  public void delete(String key) {
    if (key == null || key.isBlank()) {
      return;
    }
    imageArea.deleteQuietly(key);
    localStorage.delete(key);
  }

  @Override
  public ImageContent read(String key) {
    return imageArea.readQuietly(key)
      .map(bytes -> new ImageContent(bytes, StoredImageFormat.contentTypeOf(key)))
      .orElseGet(() -> readFallback(key));
  }

  private ImageContent readFallback(String key) {
    if (isFallbackToLocal) {
      return localStorage.read(key);
    }
    throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND);
  }

  private String putOrThrow(String key, byte[] bytes, ErrorCode failureCode) {
    try {
      imageArea.put(key, bytes, StoredImageFormat.contentTypeOf(key));
      return key;
    } catch (ObjectStoreException | IllegalArgumentException e) {
      log.warn("[routine image] save failed : error={}", e.getClass().getSimpleName(), e);
      throw new CustomException(failureCode);
    }
  }
}
