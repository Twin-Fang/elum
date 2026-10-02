package com.chuseok22.elumserver.common.application.exception;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/**
 * multipart 전체 한도(200MB)를 넘긴 요청 (이슈 #455).
 *
 * <p>이 예외는 <b>컨트롤러가 정해지기 전</b>, 요청 본문을 해석하는 단계에서 터진다.
 * {@link GlobalExceptionHandler} 는 {@code basePackages} 로 범위를 좁혀 놓아서 이 시점에는 적용되지 않고,
 * 그래서 로컬 서버에 210MB 를 실제로 올려 보니 400 이 아니라 본문 없는 413 이 나갔다(단위 테스트는 핸들러를
 * 직접 불러서 통과했다).
 *
 * <p>범위를 좁히지 않은 별도 어드바이스로 받되, 관리자 화면(Thymeleaf SSR)은 JSON 대신 기본 응답을 받아야 하므로
 * {@code /api/} 경로에만 JSON 을 준다. 그 밖은 원래 동작대로 413 만 돌려준다.
 */
@Slf4j
@RestControllerAdvice
@Order(Ordered.LOWEST_PRECEDENCE)
public class MultipartLimitExceptionHandler {

  private final ErrorMessages messages = ErrorMessages.standard();

  @ExceptionHandler(MaxUploadSizeExceededException.class)
  public ResponseEntity<ErrorResponse> handleMaxUploadSize(MaxUploadSizeExceededException e, HttpServletRequest request) {
    log.warn("[MaxUploadSizeExceededException] 한도 초과 uri={}: {}", request.getRequestURI(), e.getMessage());
    if (!request.getRequestURI().startsWith("/api/")) {
      return ResponseEntity.status(HttpStatus.CONTENT_TOO_LARGE).build();
    }
    ErrorCode errorCode = ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, messages.of(errorCode)));
  }
}
