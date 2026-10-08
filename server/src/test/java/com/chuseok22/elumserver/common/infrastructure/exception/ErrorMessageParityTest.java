package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

/**
 * ko 응답이 다국어 작업 전과 같다는 증명 (다국어 #521, 헤더 없는 앱의 호환).
 *
 * <p>golden 은 작업 전 {@code ErrorCode} enum 의 이름·HTTP 상태·문구를 <b>JSON 으로 따로</b> 고정한 것이다. ko 리소스는
 * properties 로 읽으므로 인코딩·이스케이프 실수가 있으면 여기서 글자 단위로 드러난다.
 * ko 문구를 의도적으로 바꾸는 PR 은 golden 도 같이 고친다 — 그때는 그것이 이 테스트의 목적이다.
 */
class ErrorMessageParityTest {

  private static final Map<String, Map<String, String>> GOLDEN = loadGolden();

  private static Map<String, Map<String, String>> loadGolden() {
    try (InputStream in = ErrorMessageParityTest.class.getResourceAsStream("/i18n/golden/error-messages-ko.json")) {
      assertThat(in).as("golden 파일 /i18n/golden/error-messages-ko.json").isNotNull();
      return new ObjectMapper().readValue(in, new TypeReference<>() {
      });
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  @Test
  @DisplayName("golden 은 작업 전 ErrorCode 104개를 모두 담고 있다")
  void goldenCoversAllLegacyCodes() {
    assertThat(GOLDEN).hasSize(104);
  }

  @Test
  @DisplayName("원본 이후 더한 코드는 golden 밖에서 따로 단언한다 — golden 을 다시 만들면 원본 증명이 흐려진다")
  void codesAddedAfterOriginal_areAssertedSeparately() {
    assertThat(ErrorCode.values()).hasSize(GOLDEN.size() + 1 + ADDED_LOG_CODES.size() + ADDED_FEEDBACK_CODES.size());
    assertThat(GOLDEN).doesNotContainKey(ErrorCode.CONTENT_LOCALE_NOT_READY.name());
    assertThat(ErrorCode.CONTENT_LOCALE_NOT_READY.getStatus().name()).isEqualTo("BAD_REQUEST");
    assertThat(ErrorMessages.standard().of(ErrorCode.CONTENT_LOCALE_NOT_READY, AppLocale.KO))
      .isEqualTo("이 언어는 아직 켤 수 없어요. 서버 문구 파일이 비어 있어요.");
  }

  // 의견 보내기가 더한 코드.
  private static final java.util.List<ErrorCode> ADDED_FEEDBACK_CODES = java.util.List.of(
    ErrorCode.FEEDBACK_MESSAGE_EMPTY,
    ErrorCode.FEEDBACK_MESSAGE_TOO_LONG,
    ErrorCode.FEEDBACK_LOG_TOO_LARGE,
    ErrorCode.FEEDBACK_RATE_LIMITED,
    ErrorCode.FEEDBACK_NOT_FOUND
  );

  // 관리자 로그 관리 화면이 더한 코드. 문구 끝의 (E-LOG-00N) 이 화면에 찍히는 추적용 식별자다.
  private static final Map<ErrorCode, String> ADDED_LOG_CODES = Map.of(
    ErrorCode.INVALID_LOG_PATH, "BAD_REQUEST",
    ErrorCode.LOG_FILE_NOT_FOUND, "NOT_FOUND",
    ErrorCode.LOG_FILE_IN_USE, "CONFLICT",
    ErrorCode.LOG_FILE_DELETE_FAILED, "INTERNAL_SERVER_ERROR",
    ErrorCode.INVALID_LOG_LEVEL, "BAD_REQUEST"
  );

  @Test
  @DisplayName("관리자 로그 코드는 golden 밖에서 상태와 식별자를 단언한다")
  void adminLogCodes_areAssertedSeparately() {
    ADDED_LOG_CODES.forEach((code, status) -> {
      assertThat(GOLDEN).doesNotContainKey(code.name());
      assertThat(code.getStatus().name()).as("상태 %s", code).isEqualTo(status);
      assertThat(ErrorMessages.standard().of(code, AppLocale.KO)).as("ko %s", code).containsPattern("\\(E-LOG-00\\d\\)$");
      assertThat(ErrorMessages.standard().of(code, AppLocale.EN)).as("en %s", code).containsPattern("\\(E-LOG-00\\d\\)$");
    });
  }

  @Test
  @DisplayName("ko 리소스의 문구는 기존 enum 문구와 글자 하나까지 같다")
  void koResource_equalsLegacyText() {
    GOLDEN.forEach((name, legacy) -> {
      ErrorCode code = ErrorCode.valueOf(name);
      assertThat(ErrorMessages.standard().of(code, AppLocale.KO))
        .as("ko 문구 %s", name)
        .isEqualTo(legacy.get("message"));
    });
  }

  @Test
  @DisplayName("HTTP 상태도 그대로다")
  void status_isUnchanged() {
    GOLDEN.forEach((name, legacy) ->
      assertThat(ErrorCode.valueOf(name).getStatus().name()).as("상태 %s", name).isEqualTo(legacy.get("status")));
  }

  @Test
  @DisplayName("ErrorCode.getMessage() 는 지금도 같은 한국어 문구다 — 관리자 화면·로그·예외 메시지")
  void getMessage_stillReturnsLegacyKorean() {
    GOLDEN.forEach((name, legacy) ->
      assertThat(ErrorCode.valueOf(name).getMessage()).as("getMessage %s", name).isEqualTo(legacy.get("message")));
  }

  @Test
  @DisplayName("모든 ErrorCode 는 ko 문구가 있다 — 새 코드를 더하고 리소스를 빠뜨리면 여기서 걸린다")
  void everyErrorCodeHasKoMessage() {
    for (ErrorCode code : ErrorCode.values()) {
      assertThat(ErrorMessages.standard().of(code, AppLocale.KO))
        .as("ko 문구 %s", code.name())
        .isNotBlank()
        .isNotEqualTo(code.name());
    }
  }

  @Test
  @DisplayName("접미사 없는 messages.properties 는 없다 — 있으면 ResourceBundle 부모 체인이 ja 요청에 en 보다 먼저 그 값을 줘 대체 순서가 조용히 깨진다")
  void noBaseMessagesFile() {
    assertThat(getClass().getResource("/i18n/messages.properties")).isNull();
  }

  @ParameterizedTest
  @EnumSource(AppLocale.class)
  @DisplayName("언어마다 문구 파일이 있다 — 번역 값은 계획 5에서 채운다")
  void everyLocaleHasAFile(AppLocale locale) {
    assertThat(getClass().getResource("/i18n/messages_" + locale.code() + ".properties")).isNotNull();
  }

  @ParameterizedTest
  @EnumSource(AppLocale.class)
  @DisplayName("파일이 비어 있어도 모든 언어가 모든 코드에서 문구를 받는다 — en → ko 대체")
  void everyLocaleAlwaysGetsAMessage(AppLocale locale) {
    for (ErrorCode code : ErrorCode.values()) {
      assertThat(ErrorMessages.standard().of(code, locale))
        .as("%s %s", locale.code(), code.name())
        .isNotBlank()
        .isNotEqualTo(code.name());
    }
  }
}
