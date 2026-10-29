package com.chuseok22.elumserver.systemconfig.application.service;

/**
 * 설정 값 검사 결과: 통과면 저장할 정리된 값, 거부면 관리자에게 보일 이유
 */
public record ConfigValueCheck(boolean isValid, String normalizedValue, String rejectReason) {

  public static ConfigValueCheck accepted(String normalizedValue) {
    return new ConfigValueCheck(true, normalizedValue, null);
  }

  public static ConfigValueCheck rejected(String rejectReason) {
    return new ConfigValueCheck(false, null, rejectReason);
  }
}
