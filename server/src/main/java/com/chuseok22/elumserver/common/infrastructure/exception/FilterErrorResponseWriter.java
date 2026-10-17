package com.chuseok22.elumserver.common.infrastructure.exception;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.MediaType;

/**
 * 필터 계층 에러 응답 공통: 상태 코드, application/json UTF-8, ErrorResponse JSON
 * GlobalExceptionHandler 밖(보안 필터·진입점) 전용
 */
public final class FilterErrorResponseWriter {

  // Jackson 2 매퍼 빈이 없어 직접 생성 (스레드 안전, 재사용)
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
  private static final String CHARACTER_ENCODING = "UTF-8";

  private FilterErrorResponseWriter() {
  }

  /**
   * ErrorCode + 문구 > {"errorCode":"...","errorMessage":"..."} 응답 작성
   */
  public static void write(HttpServletResponse response, ErrorCode errorCode, String errorMessage)
    throws IOException {
    response.setStatus(errorCode.getStatus().value());
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.setCharacterEncoding(CHARACTER_ENCODING);
    response.getWriter().write(OBJECT_MAPPER.writeValueAsString(new ErrorResponse(errorCode, errorMessage)));
  }
}
