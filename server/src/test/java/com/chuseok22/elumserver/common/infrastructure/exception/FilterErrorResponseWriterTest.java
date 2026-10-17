package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletResponse;

/**
 * 필터 에러 응답 계약 고정: GlobalExceptionHandler 와 같은 ErrorResponse 키 순서·값
 * 깨지면 필터에서 거절된 요청만 앱이 errorCode 를 못 읽음
 */
class FilterErrorResponseWriterTest {

  @Test
  @DisplayName("상태 코드·Content-Type·UTF-8 과 errorCode, errorMessage 순서의 JSON 을 쓴다")
  void write_writesErrorResponseJson() throws Exception {
    MockHttpServletResponse response = new MockHttpServletResponse();

    FilterErrorResponseWriter.write(response, ErrorCode.DLP_ENVELOPE_INVALID, "형식 \"오류\"");

    assertThat(response.getStatus()).isEqualTo(400);
    assertThat(response.getContentType()).isEqualTo("application/json;charset=UTF-8");
    assertThat(response.getCharacterEncoding()).isEqualTo("UTF-8");
    assertThat(response.getContentAsByteArray()).isEqualTo(
      "{\"errorCode\":\"DLP_ENVELOPE_INVALID\",\"errorMessage\":\"형식 \\\"오류\\\"\"}"
        .getBytes(StandardCharsets.UTF_8));
  }
}
