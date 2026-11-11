package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.MinioStorageProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import com.chuseok22.elumserver.common.infrastructure.storage.ObjectStore;
import com.chuseok22.elumserver.common.infrastructure.storage.ObjectStoreException;
import com.chuseok22.elumserver.common.infrastructure.storage.StoredImageArea;
import com.chuseok22.elumserver.common.infrastructure.storage.StoredImageArea.StoredKey;
import com.chuseok22.elumserver.common.infrastructure.storage.StoredImageFormat;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 카드 그림 MinIO 구현: 쓰기 MinIO(AI 그림은 webp 압축, #1219), 읽기 MinIO > 로컬 대체, 삭제 양쪽
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
  private final CardImageCompressor cardImageCompressor;

  @Autowired
  public MinioRoutineImageStorage(
    ObjectStore objectStore, RoutineProperties routineProperties, MinioStorageProperties minioProperties,
    CardImageCompressor cardImageCompressor
  ) {
    this.imageArea = new StoredImageArea(objectStore, AREA_NAME);
    this.localStorage = new LocalFileRoutineImageStorage(routineProperties);
    this.isFallbackToLocal = minioProperties.fallbackToLocal();
    this.cardImageCompressor = cardImageCompressor;
  }

  /// 압축 없이 (시험용)
  public MinioRoutineImageStorage(
    ObjectStore objectStore, RoutineProperties routineProperties, MinioStorageProperties minioProperties
  ) {
    this(objectStore, routineProperties, minioProperties, CardImageCompressor.NONE);
  }

  @Override
  public String save(String batchId, Integer stepOrder, GeneratedImage generatedImage) {
    GeneratedImage image = compress(generatedImage);
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
  public String saveRegenerated(String stepId, GeneratedImage generatedImage) {
    GeneratedImage image = compress(generatedImage);
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

  /**
   * 저장된 그림 > 같은 이름의 .webp 사본 > 새 열쇠 (옛 png 전환용, #1219). 없거나 실패면 빈 값
   */
  @Override
  public Optional<String> saveWebpCopy(String key) {
    int extensionStart = key.lastIndexOf('.');
    if (extensionStart < 0 || key.lastIndexOf('/') > extensionStart) {
      return Optional.empty();
    }
    Optional<byte[]> original = imageArea.readQuietly(key);
    if (original.isEmpty()) {
      return Optional.empty();
    }
    Optional<GeneratedImage> webp = cardImageCompressor.toWebp(
      new GeneratedImage(original.get(), key.substring(extensionStart + 1)));
    if (webp.isEmpty()) {
      return Optional.empty();
    }
    String webpKey = key.substring(0, extensionStart + 1) + webp.get().extension();
    try {
      imageArea.put(webpKey, webp.get().bytes(), StoredImageFormat.contentTypeOf(webpKey));
      return Optional.of(webpKey);
    } catch (ObjectStoreException | IllegalArgumentException e) {
      log.warn("[routine image] webp copy save failed : error={}", e.getClass().getSimpleName());
      return Optional.empty();
    }
  }

  /**
   * 쓰지 않는 그림 정리 (#1216): 구역 객체 중 오래됐고 열쇠에 없는 것 삭제 > 지운 개수
   * 목록 실패는 던짐 (아무것도 지우지 않음)
   */
  @Override
  public int deleteUnreferenced(Collection<String> referencedKeys, Instant cutoff) {
    // 열쇠를 구역 기준 모양으로 맞춰 비교 (옛 형식 전체 경로 열쇠 보호)
    Set<String> normalizedReferencedKeys = referencedKeys.stream()
      .map(imageArea::normalizedKeyOf)
      .flatMap(Optional::stream)
      .collect(Collectors.toSet());
    List<String> orphanKeys = imageArea.listKeys().stream()
      .filter(stored -> stored.lastModified().isBefore(cutoff))
      .map(StoredKey::key)
      .filter(key -> !normalizedReferencedKeys.contains(key))
      .toList();
    orphanKeys.forEach(imageArea::deleteQuietly);
    return orphanKeys.size();
  }

  /// AI 그림 > webp. 실패면 원본 그대로 (그림이 빠지지 않게)
  private GeneratedImage compress(GeneratedImage image) {
    return cardImageCompressor.toWebp(image).orElse(image);
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
