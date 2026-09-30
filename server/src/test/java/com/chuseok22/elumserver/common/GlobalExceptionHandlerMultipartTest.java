package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.application.exception.GlobalExceptionHandler;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.MultipartException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;

/**
 * 사진 업로드가 스프링 단계에서 막힐 때 500 으로 새지 않는지 (이슈 #455).
 */
class GlobalExceptionHandlerMultipartTest {

  private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

  @Test
  @DisplayName("multipart 한도 초과는 500 이 아니라 400 ROUTINE_STEP_IMAGE_TOO_LARGE")
  void maxUploadSize_is400() {
    ResponseEntity<ErrorResponse> response = handler.handleMaxUploadSize(new MaxUploadSizeExceededException(1L));

    assertThat(response.getStatusCode().value()).isEqualTo(400);
    assertThat(response.getBody().errorCode()).isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE);
  }

  @Test
  @DisplayName("multipart 형식 오류와 필수 파트(image) 누락은 400")
  void multipartProblems_are400() {
    assertThat(handler.handleMultipart(new MultipartException("깨진 요청")).getStatusCode().value()).isEqualTo(400);
    assertThat(handler.handleMultipart(new MissingServletRequestPartException("image")).getStatusCode().value())
      .isEqualTo(400);
  }
}
