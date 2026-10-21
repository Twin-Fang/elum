package com.chuseok22.elumserver.common.infrastructure.exception;

import com.chuseok22.elumserver.common.infrastructure.logging.RequestIdFilter;
import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * API 에러 응답: 에러 코드, 문구, 요청 id
 *
 * @param requestId 서버 로그를 찾는 요청 id (RequestIdFilter, #656). 요청 밖이면 null 이라 JSON 에서 빠짐
 */
public record ErrorResponse(
  ErrorCode errorCode,
  String errorMessage,
  @JsonInclude(JsonInclude.Include.NON_NULL)
  String requestId
) {

  /// 지금 요청의 id 를 붙인 에러 응답
  public ErrorResponse(ErrorCode errorCode, String errorMessage) {
    this(errorCode, errorMessage, RequestIdFilter.currentRequestId());
  }
}
