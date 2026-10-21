package com.chuseok22.elumserver.common.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

/**
 * DLP 복호화 필터 거절 응답 계약 고정: 상태 코드, Content-Type, 인코딩, JSON 키·값
 * 깨지면 앱이 errorCode 이름으로 분기하지 못해 원인 모를 에러 화면만 뜸
 */
class AidlpDecryptionFilterErrorResponseTest {

  @Test
  @DisplayName("시크릿 없이 암호문이 오면 500 과 DLP_SECRET_NOT_CONFIGURED JSON 을 UTF-8 로 쓴다")
  void encryptedRequestWithoutSecret_writesErrorJson() throws Exception {
    AidlpProperties properties = new AidlpProperties();
    AidlpDecryptionFilter filter = new AidlpDecryptionFilter(
      mock(AidlpCryptoService.class), mock(NonceStore.class), properties);
    MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/routines");
    request.setContent("{\"encrypted\":{\"ciphertext\":\"a\",\"iv\":\"b\",\"salt\":\"c\"}}"
      .getBytes(StandardCharsets.UTF_8));
    MockHttpServletResponse response = new MockHttpServletResponse();
    MockFilterChain chain = new MockFilterChain();

    filter.doFilter(request, response, chain);

    assertThat(chain.getRequest()).as("거절이면 체인을 타지 않는다").isNull();
    assertThat(response.getStatus()).isEqualTo(500);
    assertThat(response.getContentType()).isEqualTo("application/json;charset=UTF-8");
    assertThat(response.getCharacterEncoding()).isEqualTo("UTF-8");
    Map<String, String> body = new ObjectMapper().readValue(
      response.getContentAsByteArray(), new TypeReference<Map<String, String>>() { });
    assertThat(body).containsExactlyInAnyOrderEntriesOf(Map.of(
      "errorCode", "DLP_SECRET_NOT_CONFIGURED",
      "errorMessage", "서버에 암호화 시크릿이 설정되지 않았어요."));
  }
}
