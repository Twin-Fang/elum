package com.chuseok22.elumserver.license.application.service.store;

/**
 * 스토어 API 시간 초과·5xx·인증 실패: 거부가 아니라 "확인 중" (Pro 를 주지도, 구매를 버리지도 않음)
 */
public class StoreTemporarilyUnavailableException extends RuntimeException {

  public StoreTemporarilyUnavailableException(String message) {
    super(message);
  }

  public StoreTemporarilyUnavailableException(String message, Throwable cause) {
    super(message, cause);
  }
}
