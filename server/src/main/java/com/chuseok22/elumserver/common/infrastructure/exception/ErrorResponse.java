package com.chuseok22.elumserver.common.infrastructure.exception;

public record ErrorResponse(
  ErrorCode errorCode,
  String errorMessage
) {

}
