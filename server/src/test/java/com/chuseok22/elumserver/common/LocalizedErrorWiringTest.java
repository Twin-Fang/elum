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
import com.chuseok22.elumserver.systemconfig.infrastructure.security.MaintenanceModeFilter;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.context.support.StaticMessageSource;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/**
 * 오류 응답을 만드는 5곳이 실제로 ErrorMessages(요청 언어)를 거치는지 가짜 일본어 문구로 증명한다 (다국어 #526).
 *
 * <p>번역 리소스가 비어 있는 동안에는 ja 요청도 ko 와 같은 글자라, 가짜 문구 없이는 배선이 끊겨도 테스트가 모른다.
 */
class LocalizedErrorWiringTest {

  private static String fake(ErrorCode code) {
    return "JA-FAKE:" + code.name();
  }

  @BeforeEach
  void injectFakeJapanese() {
    StaticMessageSource source = new StaticMessageSource();
    for (ErrorCode code : ErrorCode.values()) {
      source.addMessage(code.name(), Locale.of("ja"), fake(code));
    }
    ErrorMessages.overrideStandardForTesting(new ErrorMessages(source));
  }

  // 다른 테스트로 가짜가 새지 않게 반드시 원복한다
  @AfterEach
  void restore() {
    ErrorMessages.resetStandardForTesting();
  }

  @Test
  @DisplayName("GlobalExceptionHandler: ja 요청은 요청 언어 문구를 쓴다")
  void globalHandler_usesRequestLanguage() {
    GlobalExceptionHandler handler = new GlobalExceptionHandler();
    ErrorCode code = ErrorCode.INVALID_TOKEN;

    ResponseEntity<ErrorResponse> ja =
      CurrentLocale.callAs(AppLocale.JA, () -> handler.handleCustomException(new CustomException(code)));
    ResponseEntity<ErrorResponse> ko =
      CurrentLocale.callAs(AppLocale.KO, () -> handler.handleCustomException(new CustomException(code)));

    assertThat(ja.getBody().errorMessage()).isEqualTo(fake(code));
    assertThat(ko.getBody().errorMessage()).isEqualTo(code.getMessage());
  }

  @Test
  @DisplayName("MultipartLimitExceptionHandler: ja 요청은 요청 언어 문구를 쓴다")
  void multipartHandler_usesRequestLanguage() {
    ResponseEntity<ErrorResponse> response = CurrentLocale.callAs(AppLocale.JA,
      () -> new MultipartLimitExceptionHandler().handleMaxUploadSize(
        new MaxUploadSizeExceededException(1L),
        new MockHttpServletRequest("POST", "/api/routines/r1/steps/s1/image")));

    assertThat(response.getBody().errorMessage()).isEqualTo(fake(ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE));
  }

  @Test
  @DisplayName("JwtAuthenticationEntryPoint: ja 요청은 요청 언어 문구를 쓴다")
  void entryPoint_usesRequestLanguage() throws Exception {
    MockHttpServletResponse response = new MockHttpServletResponse();

    CurrentLocale.runAs(AppLocale.JA, () -> {
      try {
        new JwtAuthenticationEntryPoint().commence(
          new MockHttpServletRequest("GET", "/api/member/me"), response, new BadCredentialsException("x"));
      } catch (Exception e) {
        throw new IllegalStateException(e);
      }
    });

    JsonNode body = new ObjectMapper().readTree(response.getContentAsString(StandardCharsets.UTF_8));
    assertThat(body.get("errorMessage").asText()).isEqualTo(fake(ErrorCode.INVALID_TOKEN));
  }

  @Test
  @DisplayName("AidlpDecryptionFilter: ja 요청은 요청 언어 문구를 쓴다")
  void dlpFilter_usesRequestLanguage() throws Exception {
    AidlpDecryptionFilter filter =
      new AidlpDecryptionFilter(mock(AidlpCryptoService.class), mock(NonceStore.class), new AidlpProperties());
    MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/routines");
    request.setContent("{\"encrypted\":{}}".getBytes(StandardCharsets.UTF_8));
    MockHttpServletResponse response = new MockHttpServletResponse();

    CurrentLocale.runAs(AppLocale.JA, () -> {
      try {
        filter.doFilter(request, response, new MockFilterChain());
      } catch (Exception e) {
        throw new IllegalStateException(e);
      }
    });

    JsonNode body = new ObjectMapper().readTree(response.getContentAsString(StandardCharsets.UTF_8));
    assertThat(body.get("errorMessage").asText()).isEqualTo(fake(ErrorCode.DLP_SECRET_NOT_CONFIGURED));
  }

  private String maintenanceMessage(String configured) throws Exception {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getBoolean(ConfigKey.MAINTENANCE_MODE)).thenReturn(true);
    when(config.getString(ConfigKey.MAINTENANCE_MESSAGE)).thenReturn(configured);
    MockHttpServletResponse response = new MockHttpServletResponse();
    CurrentLocale.runAs(AppLocale.JA, () -> {
      try {
        new MaintenanceModeFilter(config).doFilter(
          new MockHttpServletRequest("GET", "/api/member/me"), response, new MockFilterChain());
      } catch (Exception e) {
        throw new IllegalStateException(e);
      }
    });
    return new ObjectMapper().readTree(response.getContentAsString(StandardCharsets.UTF_8))
      .get("errorMessage").asText();
  }

  @Test
  @DisplayName("MaintenanceModeFilter: 기본 문구는 번역하고 관리자가 쓴 문구는 그대로 준다")
  void maintenance_bothBranches() throws Exception {
    assertThat(maintenanceMessage(ConfigKey.MAINTENANCE_MESSAGE.getDefaultValue()))
      .isEqualTo(fake(ErrorCode.MAINTENANCE_MODE));
    assertThat(maintenanceMessage("")).isEqualTo(fake(ErrorCode.MAINTENANCE_MODE));
    assertThat(maintenanceMessage("오늘 밤 10시까지 점검해요")).isEqualTo("오늘 밤 10시까지 점검해요");
  }
}
