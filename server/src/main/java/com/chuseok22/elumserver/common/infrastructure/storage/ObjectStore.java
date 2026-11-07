package com.chuseok22.elumserver.common.infrastructure.storage;

import java.util.Optional;

/**
 * 객체 저장소: 쓰기, 읽기, 한 개 삭제, 폴더 삭제
 * 저장소 장애는 {@link ObjectStoreException}, 없는 객체 읽기는 빈 값
 */
public interface ObjectStore {

  void put(String objectName, byte[] bytes, String contentType);

  Optional<byte[]> read(String objectName);

  void delete(String objectName);

  /// folderName 아래 객체 전부 삭제
  void deleteFolder(String folderName);
}
