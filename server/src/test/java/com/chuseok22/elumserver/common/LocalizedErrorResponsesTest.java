package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.application.exception.GlobalExceptionHandler;
import com.chuseok22.elumserver.common.application.exception.MultipartLimitExceptionHandler;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpCryptoService;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpDecryptionFilter;
import com.chuseok22.elumserver.common.infrastructure.security.MaintenanceModeFilter;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/**
 * 오류 응답이 요청 언어를 따르되, <b>헤더가 없으면 이전과 바이트 단위로 같다</b> (다국어 #526).
 *
 * <p>기대값은 작업 전 enum 문구를 고정한 golden(ko)에서 손으로 JSON 을 조립해 만든다 — 응답 객체를 같은 방식으로
 * 직렬화해 비교하면 둘이 함께 틀려도 통과한다.
 */
class LocalizedErrorResponsesTest {

  private static final ObjectMapper MAPPER = new ObjectMapper();
  private static final Map<String, Map<String, String>> GOLDEN = golden();

  private static Map<String, Map<String, String>> golden() {
    try (InputStream in = LocalizedErrorResponsesTest.class.getResourceAsStream("/i18n/golden/error-messages-ko.json")) {
      return MAPPER.readValue(in, new TypeReference<>() {
      });
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  /** 작업 전 응답 본문 — 이 모양 그대로 나가야 이미 배포된 앱이 깨지지 않는다. */
  private static String legacyJson(ErrorCode code) throws Exception {
    return "{\"errorCode\":\"" + code.name() + "\",\"errorMessage\":"
      + MAPPER.writeValueAsString(GOLDEN.get(code.name()).get("message")) + "}";
  }

  @Test
  @DisplayName("헤더가 없으면 모든 ErrorCode 의 응답 본문이 이전과 바이트 단위로 같다")
  void headerless_everyCode_bodyIsByteIdentical() throws Exception {
    GlobalExceptionHandler handler = new GlobalExceptionHandler();
    for (String name : GOLDEN.keySet()) {
      ErrorCode code = ErrorCode.valueOf(name);
      ResponseEntity<ErrorResponse> response = handler.handleCustomException(new CustomException(code));

      assertThat(response.getStatusCode().value()).as("상태 %s", name).isEqualTo(code.getStatus().value());
      assertThat(MAPPER.writeValueAsString(response.getBody()).getBytes(StandardCharsets.UTF_8))
        .as("본문 %s", name)
        .isEqualTo(legacyJson(code).getBytes(StandardCharsets.UTF_8));
    }
  }

  @Test
  @DisplayName("일본어 요청도 상태와 에러 코드는 그대로이고 문구는 대체 순서를 따른다")
  void jaRequest_keepsStatusAndCode_andFollowsChain() {
    GlobalExceptionHandler handler = new GlobalExceptionHandler();
    for (ErrorCode code : ErrorCode.values()) {
      ResponseEntity<ErrorResponse> response =
        CurrentLocale.callAs(AppLocale.JA, () -> handler.handleCustomException(new CustomException(code)));

      assertThat(response.getStatusCode().value()).isEqualTo(code.getStatus().value());
      assertThat(response.getBody().errorCode()).isEqualTo(code);
      // 번역 파일을 채우면 값이 달라지므로 "ko 와 같다"가 아니라 "대체 순서가 고른 값"이다
      assertThat(response.getBody().errorMessage())
        .isNotBlank()
        .isEqualTo(ErrorMessages.standard().of(code, AppLocale.JA));
    }
  }

  @Test
  @DisplayName("multipart 한도 초과 응답도 헤더가 없으면 이전과 같다")
  void multipartLimit_headerless_isLegacy() throws Exception {
    ResponseEntity<ErrorResponse> response = new MultipartLimitExceptionHandler().handleMaxUploadSize(
      new MaxUploadSizeExceededException(1L), new MockHttpServletRequest("POST", "/api/routines/r1/steps/s1/image"));

    assertThat(MAPPER.writeValueAsString(response.getBody()))
      .isEqualTo(legacyJson(ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE));
  }

  @Test
  @DisplayName("인증 진입점(401)의 본문도 헤더가 없으면 이전과 같다")
  void entryPoint_headerless_isLegacy() throws Exception {
    MockHttpServletResponse response = new MockHttpServletResponse();

    new JwtAuthenticationEntryPoint().commence(
      new MockHttpServletRequest("GET", "/api/member/me"), response, new BadCredentialsException("x"));

    assertThat(response.getStatus()).isEqualTo(401);
    assertThat(response.getContentAsString(StandardCharsets.UTF_8)).isEqualTo(legacyJson(ErrorCode.INVALID_TOKEN));
  }

  @Test
  @DisplayName("DLP 필터의 오류 본문은 에러 코드와 문구가 이전과 같다 (키 순서는 원래 보장되지 않았다)")
  void dlpFilter_headerless_isLegacy() throws Exception {
    AidlpDecryptionFilter filter =
      new AidlpDecryptionFilter(mock(AidlpCryptoService.class), mock(NonceStore.class), new AidlpProperties());
    MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/routines");
    request.setContent("{\"encrypted\":{}}".getBytes(StandardCharsets.UTF_8));
    MockHttpServletResponse response = new MockHttpServletResponse();

    filter.doFilter(request, response, new MockFilterChain());

    JsonNode body = MAPPER.readTree(response.getContentAsString(StandardCharsets.UTF_8));
    assertThat(body.get("errorCode").asText()).isEqualTo("DLP_SECRET_NOT_CONFIGURED");
    assertThat(body.get("errorMessage").asText())
      .isEqualTo(GOLDEN.get("DLP_SECRET_NOT_CONFIGURED").get("message"));
  }

  // --- 점검 모드: 관리자가 적은 안내는 그대로, 기본 문구는 요청 언어로 ---

  private MockHttpServletResponse maintenance(String configuredMessage, AppLocale locale) throws Exception {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getBoolean(ConfigKey.MAINTENANCE_MODE)).thenReturn(true);
    when(config.getString(ConfigKey.MAINTENANCE_MESSAGE)).thenReturn(configuredMessage);
    MockHttpServletResponse response = new MockHttpServletResponse();
    CurrentLocale.runAs(locale, () -> {
      try {
        new MaintenanceModeFilter(config).doFilter(
          new MockHttpServletRequest("GET", "/api/member/me"), response, new MockFilterChain());
      } catch (Exception e) {
        throw new IllegalStateException(e);
      }
    });
    return response;
  }

  @Test
  @DisplayName("점검: 헤더가 없고 안내가 비었으면 이전 응답과 같다")
  void maintenance_headerless_blankMessage_isLegacy() throws Exception {
    MockHttpServletResponse response = maintenance("", AppLocale.KO);

    assertThat(response.getStatus()).isEqualTo(503);
    assertThat(response.getContentAsString(StandardCharsets.UTF_8)).isEqualTo(legacyJson(ErrorCode.MAINTENANCE_MODE));
  }

  @Test
  @DisplayName("점검: 기본 안내 문구 그대로면 요청 언어로 바꾼다 — ko 는 같은 글자다")
  void maintenance_defaultText_followsLocale() throws Exception {
    String defaultText = ConfigKey.MAINTENANCE_MESSAGE.getDefaultValue();

    assertThat(maintenance(defaultText, AppLocale.KO).getContentAsString(StandardCharsets.UTF_8))
      .isEqualTo(legacyJson(ErrorCode.MAINTENANCE_MODE));
    JsonNode ja = MAPPER.readTree(maintenance(defaultText, AppLocale.JA).getContentAsString(StandardCharsets.UTF_8));
    assertThat(ja.get("errorMessage").asText())
      .isEqualTo(ErrorMessages.standard().of(ErrorCode.MAINTENANCE_MODE, AppLocale.JA));
  }

  @Test
  @DisplayName("점검: 관리자가 직접 쓴 안내는 어느 언어에서도 그대로 준다")
  void maintenance_customText_passesThrough() throws Exception {
    JsonNode ja = MAPPER.readTree(
      maintenance("오늘 밤 10시까지 점검해요", AppLocale.JA).getContentAsString(StandardCharsets.UTF_8));

    assertThat(ja.get("errorMessage").asText()).isEqualTo("오늘 밤 10시까지 점검해요");
  }
}
