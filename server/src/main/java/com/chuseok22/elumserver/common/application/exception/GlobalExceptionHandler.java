package com.chuseok22.elumserver.common.application.exception;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.MultipartException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;

// admin은 Thymeleaf SSR이라 JSON 에러 대신 기본 에러 페이지를 받아야 하므로 REST API 도메인 패키지로 범위를 좁힌다.
// 새 도메인 패키지를 만들면 basePackages 에 더한다 — 빠뜨리면 CustomException 이 잡히지 않아 400·404 가 500 으로 나간다.
// 빠뜨림은 ExceptionHandlerCoverageTest 가 잡는다.
// admin 중 JSON 을 돌려주는 컨트롤러는 @JsonErrorResponse 를 붙여 이 범위에 넣는다.
@RestControllerAdvice(
  basePackages = {
    "com.chuseok22.elumserver.adreward",
    "com.chuseok22.elumserver.ai",
    "com.chuseok22.elumserver.auth",
    "com.chuseok22.elumserver.member",
    "com.chuseok22.elumserver.common",
    "com.chuseok22.elumserver.consent",
    "com.chuseok22.elumserver.credit",
    "com.chuseok22.elumserver.link",
    "com.chuseok22.elumserver.notice",
    "com.chuseok22.elumserver.routine",
    "com.chuseok22.elumserver.systemconfig"
  },
  annotations = JsonErrorResponse.class
)
@Slf4j
public class GlobalExceptionHandler {

  // 문구는 요청 언어로 고른다. 헤더가 없으면 KO 라 이전 응답과 같다.
  private final ErrorMessages messages = ErrorMessages.standard();

  @ExceptionHandler(CustomException.class)
  public ResponseEntity<ErrorResponse> handleCustomException(CustomException e) {
    log.warn("[CustomException] 발생: {}", e.getMessage());
    ErrorCode errorCode = e.getErrorCode();
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, messages.of(errorCode)));
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ErrorResponse> handleValidationException(MethodArgumentNotValidException e) {
    // 필드 이름은 식별자라 그대로 두고 문구만 요청 언어로 고른다. 키가 없으면 DTO message(한국어)다.
    AppLocale locale = CurrentLocale.get();
    String detail = e.getBindingResult().getFieldErrors().stream()
      .map(error -> error.getField() + ": " + messages.ofValidation(error, locale))
      .findFirst()
      .orElse(messages.of(ErrorCode.INVALID_INPUT_VALUE, locale));
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
      .body(new ErrorResponse(errorCode,
        messages.of("detail.requestBodyUnreadable", CurrentLocale.get(), "요청 본문을 읽을 수 없습니다.")));
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
      .body(new ErrorResponse(errorCode, messages.of(errorCode)));
  }

  @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
  public ResponseEntity<ErrorResponse> handleMethodNotSupported(HttpRequestMethodNotSupportedException e) {
    log.warn("[HttpRequestMethodNotSupportedException] 발생: {}", e.getMessage());
    ErrorCode errorCode = ErrorCode.METHOD_NOT_ALLOWED;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, messages.of(errorCode)));
  }

  // 사진 업로드가 스프링 multipart 한도를 넘거나 multipart 형식이 아닐 때.
  // 처리하지 않으면 하위 Exception.class 로 흘러 500 이 된다. 한도(현재 200MB)는 공지 업로드와 공유라 그대로 두고,
  // 카드 사진 5MB 는 서비스에서 따로 막는다.
  @ExceptionHandler(MaxUploadSizeExceededException.class)
  public ResponseEntity<ErrorResponse> handleMaxUploadSize(MaxUploadSizeExceededException e) {
    log.warn("[MaxUploadSizeExceededException] 발생: {}", e.getMessage());
    ErrorCode errorCode = ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, messages.of(errorCode)));
  }

  // multipart 파싱 실패, 필수 파트(image) 누락은 클라이언트 입력 오류다.
  @ExceptionHandler({MultipartException.class, MissingServletRequestPartException.class})
  public ResponseEntity<ErrorResponse> handleMultipart(Exception e) {
    log.warn("[MultipartException] 발생: {}", e.getMessage());
    ErrorCode errorCode = ErrorCode.INVALID_INPUT_VALUE;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, messages.of(errorCode)));
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<ErrorResponse> handleException(Exception e) {
    log.error("[UnhandledException] 발생", e);
    ErrorCode errorCode = ErrorCode.INTERNAL_SERVER_ERROR;
    return ResponseEntity
      .status(errorCode.getStatus())
      .body(new ErrorResponse(errorCode, messages.of(errorCode)));
  }
}
