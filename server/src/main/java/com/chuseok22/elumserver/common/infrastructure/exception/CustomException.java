package com.chuseok22.elumserver.common.infrastructure.exception;

import lombok.Getter;

@Getter
public class CustomException extends RuntimeException {


  private final ErrorCode errorCode;
  // 관리자 화면이 문구 뒤에 덧붙이는 값(한도·현재 값 등). 응답 문구에는 쓰지 않는다. 없으면 null
  private final String detail;

  public CustomException(ErrorCode errorCode) {
    this(errorCode, null);
  }

  public CustomException(ErrorCode errorCode, String detail) {
    super(errorCode.getMessage());
    this.errorCode = errorCode;
    this.detail = detail;
  }
}
