package com.chuseok22.elumserver.common.infrastructure.storage;

/**
 * 객체 저장소 장애 (접속 실패, 시간 초과, 권한 거부)
 */
public class ObjectStoreException extends RuntimeException {

  public ObjectStoreException(String message, Throwable cause) {
    super(message, cause);
  }
}
