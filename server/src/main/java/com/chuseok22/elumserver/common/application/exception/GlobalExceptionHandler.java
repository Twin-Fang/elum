package com.chuseok22.elumserver.common.application.exception;

import com.chuseok22.elumserver.admin.application.controller.AdminPromptTestController;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

// admin은 Thymeleaf SSR이라 JSON 에러 대신 기본 에러 페이지를 받아야 하므로,
// 이 어드바이스는 REST API 도메인(ai, auth, member, common, routine)에만 적용되도록 범위를 좁힌다.
// 단, AdminPromptTestController(미리보기/테스트)는 AJAX(JSON) 응답을 반환하므로
// assignableTypes로 이 컨트롤러 하나만 예외적으로 추가한다(AdminPromptController를 포함한
// 다른 admin 페이지는 계속 제외 — assignableTypes는 클래스 단위 적용이라 같은 컨트롤러에
// SSR/REST 엔드포인트를 함께 두면 안 된다, fable5 검토에서 발견).
@RestControllerAdvice(
  basePackages = {
    "com.chuseok22.elumserver.ai",
    "com.chuseok22.elumserver.auth",
    "com.chuseok22.elumserver.member",
    "com.chuseok22.elumserver.common",
    "com.chuseok22.elumserver.routine"
  },
  assignableTypes = AdminPromptTestController.class
)
@Slf4j
public class GlobalExceptionHandler {

  @ExceptionHandler(CustomException.class)
  public ResponseEntity<ErrorResponse> handleCustomException(CustomException e) {
    log.warn("[CustomException] 발생: {}", e.getMessage());
    ErrorCode errorCode = e.getErrorCode();
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, errorCode.getMessage()));
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ErrorResponse> handleValidationException(MethodArgumentNotValidException e) {
    String detail = e.getBindingResult().getFieldErrors().stream()
      .map(error -> error.getField() + ": " + error.getDefaultMessage())
      .findFirst()
      .orElse(ErrorCode.INVALID_INPUT_VALUE.getMessage());
    log.warn("[ValidationException] 발생: {}", detail);
    ErrorCode errorCode = ErrorCode.INVALID_INPUT_VALUE;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, detail));
  }

  @ExceptionHandler(HttpMessageNotReadableException.class)
  public ResponseEntity<ErrorResponse> handleMessageNotReadable(HttpMessageNotReadableException e) {
    log.warn("[HttpMessageNotReadableException] 발생: {}", e.getMessage());
    ErrorCode errorCode = ErrorCode.INVALID_INPUT_VALUE;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, "요청 본문을 읽을 수 없습니다."));
  }

  // @RequestParam 타입 파싱 실패(예: count에 숫자가 아닌 값 전달)를 400으로 처리한다.
  // 처리하지 않으면 하위 Exception.class 핸들러로 흘러가 500이 되어 클라이언트 입력
  // 오류가 서버 오류로 잘못 보고된다.
  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  public ResponseEntity<ErrorResponse> handleTypeMismatch(MethodArgumentTypeMismatchException e) {
    log.warn("[MethodArgumentTypeMismatchException] 발생: {}", e.getMessage());
    ErrorCode errorCode = ErrorCode.INVALID_INPUT_VALUE;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, errorCode.getMessage()));
  }

  @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
  public ResponseEntity<ErrorResponse> handleMethodNotSupported(HttpRequestMethodNotSupportedException e) {
    log.warn("[HttpRequestMethodNotSupportedException] 발생: {}", e.getMessage());
    ErrorCode errorCode = ErrorCode.METHOD_NOT_ALLOWED;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, errorCode.getMessage()));
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<ErrorResponse> handleException(Exception e) {
    log.error("[UnhandledException] 발생", e);
    ErrorCode errorCode = ErrorCode.INTERNAL_SERVER_ERROR;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, errorCode.getMessage()));
  }
}
