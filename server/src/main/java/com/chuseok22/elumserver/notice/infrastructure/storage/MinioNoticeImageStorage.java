package com.chuseok22.elumserver.notice.infrastructure.storage;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.MinioStorageProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.common.infrastructure.storage.ObjectStore;
import com.chuseok22.elumserver.common.infrastructure.storage.ObjectStoreException;
import com.chuseok22.elumserver.common.infrastructure.storage.StoredImageArea;
import com.chuseok22.elumserver.notice.core.NoticeImageType;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 공지 그림 MinIO 구현: 쓰기 MinIO, 읽기 MinIO > 로컬 대체, 삭제 양쪽
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "elum.store.image", havingValue = "minio")
public class MinioNoticeImageStorage implements NoticeImageStorage {

  private static final String AREA_NAME = "notice-images";
  private static final String UNKNOWN_CONTENT_TYPE = "application/octet-stream";

  private final StoredImageArea imageArea;
  private final NoticeImageStorage localStorage;
  private final boolean isFallbackToLocal;

  public MinioNoticeImageStorage(
    ObjectStore objectStore, NoticeProperties noticeProperties, MinioStorageProperties minioProperties
  ) {
    this.imageArea = new StoredImageArea(objectStore, AREA_NAME);
    this.localStorage = new LocalFileNoticeImageStorage(noticeProperties);
    this.isFallbackToLocal = minioProperties.fallbackToLocal();
  }

  @Override
  public String save(String noticeId, byte[] bytes, NoticeImageType type) {
    String key = noticeId + "/" + UUID.randomUUID().toString().replace("-", "") + "." + type.getExtension();
    try {
      imageArea.put(key, bytes, type.getContentType());
      return key;
    } catch (ObjectStoreException | IllegalArgumentException e) {
      log.warn("[notice image] save failed : noticeId={}", noticeId, e);
      throw new CustomException(ErrorCode.NOTICE_IMAGE_SAVE_FAILED);
    }
  }

  @Override
  public ImageContent read(String key) {
    return imageArea.readQuietly(key)
      .map(bytes -> new ImageContent(bytes, contentTypeOf(key)))
      .orElseGet(() -> readFallback(key));
  }

  @Override
  public void delete(String key) {
    if (key == null || key.isBlank()) {
      return;
    }
    imageArea.deleteQuietly(key);
    localStorage.delete(key);
  }

  private ImageContent readFallback(String key) {
    if (isFallbackToLocal) {
      return localStorage.read(key);
    }
    throw new CustomException(ErrorCode.NOTICE_IMAGE_NOT_FOUND);
  }

  private static String contentTypeOf(String key) {
    return NoticeImageType.fromKey(key).map(NoticeImageType::getContentType).orElse(UNKNOWN_CONTENT_TYPE);
  }
}
