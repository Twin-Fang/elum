package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.application.exception.MultipartLimitExceptionHandler;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/**
 * multipart 한도 초과 (이슈 #455).
 *
 * <p>로컬 서버에 210MB 를 올려 보고서야 알았다 — 이 예외는 컨트롤러가 정해지기 전에 터져서, 범위를 좁힌
 * 어드바이스는 적용되지 않는다. 핸들러 메서드를 직접 부르는 테스트는 그 사실을 못 잡으므로 <b>어드바이스가
 * 범위를 좁히지 않았다는 것</b>을 함께 못박는다.
 */
class MultipartLimitExceptionHandlerTest {

  private final MultipartLimitExceptionHandler handler = new MultipartLimitExceptionHandler();

  @Test
  @DisplayName("API 경로는 400 ROUTINE_STEP_IMAGE_TOO_LARGE 를 JSON 으로 준다")
  void apiPath_returnsJson400() {
    MockHttpServletRequest request = new MockHttpServletRequest("PUT", "/api/routines/r1/steps/s1/image");

    ResponseEntity<ErrorResponse> response = handler.handleMaxUploadSize(new MaxUploadSizeExceededException(200L), request);

    assertThat(response.getStatusCode().value()).isEqualTo(400);
    assertThat(response.getBody()).isNotNull();
    assertThat(response.getBody().errorCode()).isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE);
  }

  @Test
  @DisplayName("관리자 화면 경로는 JSON 을 주지 않는다 — 기존처럼 413 만 돌려준다")
  void adminPath_keepsPlain413() {
    MockHttpServletRequest request = new MockHttpServletRequest("POST", "/admin/notices");

    ResponseEntity<ErrorResponse> response = handler.handleMaxUploadSize(new MaxUploadSizeExceededException(200L), request);

    assertThat(response.getStatusCode().value()).isEqualTo(413);
    assertThat(response.getBody()).isNull();
  }

  @Test
  @DisplayName("어드바이스가 패키지·타입으로 범위를 좁히지 않는다 — 컨트롤러 이전 단계의 예외도 받는다")
  void advice_isNotScoped() {
    RestControllerAdvice advice = MultipartLimitExceptionHandler.class.getAnnotation(RestControllerAdvice.class);

    assertThat(advice).isNotNull();
    assertThat(advice.basePackages()).isEmpty();
    assertThat(advice.basePackageClasses()).isEmpty();
    assertThat(advice.assignableTypes()).isEmpty();
    assertThat(advice.annotations()).isEmpty();
  }
}
