package com.chuseok22.elumserver.common.infrastructure.storage;

import java.util.Arrays;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;

/**
 * 객체 저장소의 이미지 구역 1개 (routine-images 등): 열쇠 > 객체 이름, 장애를 조용히 넘기는 읽기·삭제
 * 객체 이름: {구역}/{열쇠}. 로컬 폴더 구조와 같아 파일을 그대로 복사할 수 있음
 */
@Slf4j
public final class StoredImageArea {

  private static final String SEPARATOR = "/";
  private static final String PARENT_DIRECTORY = "..";

  private final ObjectStore objectStore;
  private final String areaName;

  public StoredImageArea(ObjectStore objectStore, String areaName) {
    this.objectStore = objectStore;
    this.areaName = areaName;
  }

  /**
   * @throws ObjectStoreException 저장소 장애
   * @throws IllegalArgumentException 구역 밖을 가리키는 열쇠
   */
  public void put(String key, byte[] bytes, String contentType) {
    objectStore.put(toObjectName(key), bytes, contentType);
  }

  /// 없거나 읽지 못하면 빈 값 (장애는 로그)
  public Optional<byte[]> readQuietly(String key) {
    try {
      return objectStore.read(toObjectName(key));
    } catch (IllegalArgumentException | ObjectStoreException e) {
      log.warn("[image store] read failed : area={}, error={}", areaName, e.getClass().getSimpleName());
      return Optional.empty();
    }
  }

  /// 실패해도 예외 없음 (삭제 흐름을 막지 않음)
  public void deleteQuietly(String key) {
    try {
      objectStore.delete(toObjectName(key));
    } catch (IllegalArgumentException | ObjectStoreException e) {
      log.warn("[image store] delete failed : area={}, error={}", areaName, e.getClass().getSimpleName());
    }
  }

  /// 실패해도 예외 없음 (삭제 흐름을 막지 않음)
  public void deleteFolderQuietly(String folder) {
    try {
      objectStore.deleteFolder(toObjectName(folder));
    } catch (IllegalArgumentException | ObjectStoreException e) {
      log.warn("[image store] delete folder failed : area={}, error={}", areaName, e.getClass().getSimpleName());
    }
  }

  // 열쇠 > 객체 이름. 옛 DB 값은 경로 전체(data/routine-images/abc/1.png)라 구역 뒤만 씀
  private String toObjectName(String key) {
    if (key == null || key.isBlank()) {
      throw new IllegalArgumentException("blank image key");
    }
    String areaPrefix = areaName + SEPARATOR;
    int areaIndex = key.indexOf(areaPrefix);
    String relativeKey = areaIndex < 0 ? key : key.substring(areaIndex + areaPrefix.length());
    boolean isOutsideArea = relativeKey.isBlank() || relativeKey.startsWith(SEPARATOR)
      || Arrays.asList(relativeKey.split(SEPARATOR)).contains(PARENT_DIRECTORY);
    if (isOutsideArea) {
      throw new IllegalArgumentException("image key outside area");
    }
    return areaPrefix + relativeKey;
  }
}
