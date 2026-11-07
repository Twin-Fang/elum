package com.chuseok22.elumserver.talk.infrastructure.storage;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.MinioStorageProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import com.chuseok22.elumserver.common.infrastructure.storage.ObjectStore;
import com.chuseok22.elumserver.common.infrastructure.storage.ObjectStoreException;
import com.chuseok22.elumserver.common.infrastructure.storage.StoredImageArea;
import com.chuseok22.elumserver.common.infrastructure.storage.StoredImageFormat;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 이야기 그림 MinIO 구현: 쓰기 MinIO, 읽기 MinIO > 로컬 대체, 삭제 양쪽
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "elum.store.image", havingValue = "minio")
public class MinioTalkImageStorage implements TalkImageStorage {

  private static final String AREA_NAME = "talk-images";

  private final StoredImageArea imageArea;
  private final TalkImageStorage localStorage;
  private final boolean isFallbackToLocal;

  public MinioTalkImageStorage(
    ObjectStore objectStore, TalkProperties talkProperties, MinioStorageProperties minioProperties
  ) {
    this.imageArea = new StoredImageArea(objectStore, AREA_NAME);
    this.localStorage = new LocalFileTalkImageStorage(talkProperties);
    this.isFallbackToLocal = minioProperties.fallbackToLocal();
  }

  @Override
  public String save(String postId, int stepOrder, byte[] bytes, String contentType) {
    String key = postId + "/" + stepOrder + "." + StoredImageFormat.extensionOf(contentType);
    try {
      imageArea.put(key, bytes, StoredImageFormat.contentTypeOf(key));
      return key;
    } catch (ObjectStoreException | IllegalArgumentException e) {
      log.warn("[talk image] save failed : postId={}, stepOrder={}", postId, stepOrder, e);
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
    }
  }

  @Override
  public RoutineImageStorage.ImageContent read(String key) {
    return imageArea.readQuietly(key)
      .map(bytes -> new RoutineImageStorage.ImageContent(bytes, StoredImageFormat.contentTypeOf(key)))
      .orElseGet(() -> readFallback(key));
  }

  @Override
  public void deletePost(String postId) {
    if (postId == null || postId.isBlank()) {
      return;
    }
    imageArea.deleteFolderQuietly(postId);
    localStorage.deletePost(postId);
  }

  private RoutineImageStorage.ImageContent readFallback(String key) {
    if (isFallbackToLocal) {
      return localStorage.read(key);
    }
    throw new CustomException(ErrorCode.TALK_IMAGE_NOT_FOUND);
  }
}
