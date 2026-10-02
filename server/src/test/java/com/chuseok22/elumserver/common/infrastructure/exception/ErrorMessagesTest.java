package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import java.util.Locale;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.StaticMessageSource;

/** 대체 순서(요청 언어 → en → ko)를 가짜 문구 원본으로 본다. 실제 번역 파일 내용과 무관하다. */
class ErrorMessagesTest {

  private static final String KEY = "ROUTINE_NOT_FOUND";

  private final StaticMessageSource source = new StaticMessageSource();
  private final ErrorMessages messages = new ErrorMessages(source);

  private void put(String key, AppLocale locale, String text) {
    source.addMessage(key, Locale.of(locale.code()), text);
  }

  @Test
  @DisplayName("요청 언어의 문구가 있으면 그것을 준다")
  void requestLanguageWins() {
    put(KEY, AppLocale.KO, "ko 문구");
    put(KEY, AppLocale.EN, "en text");
    put(KEY, AppLocale.JA, "ja テキスト");

    assertThat(messages.of(KEY, AppLocale.JA, "기본")).isEqualTo("ja テキスト");
  }

  @Test
  @DisplayName("요청 언어에 키가 없으면 en 으로 간다")
  void missingKey_fallsBackToEn() {
    put(KEY, AppLocale.KO, "ko 문구");
    put(KEY, AppLocale.EN, "en text");

    assertThat(messages.of(KEY, AppLocale.ES, "기본")).isEqualTo("en text");
  }

  @Test
  @DisplayName("en 에도 없으면 ko 로 간다")
  void missingEn_fallsBackToKo() {
    put(KEY, AppLocale.KO, "ko 문구");

    assertThat(messages.of(KEY, AppLocale.ZH, "기본")).isEqualTo("ko 문구");
  }

  @Test
  @DisplayName("값이 비어 있는 키는 없는 것으로 본다 — 번역 파일에 키만 있고 값이 빈 경우")
  void blankValue_isTreatedAsMissing() {
    put(KEY, AppLocale.KO, "ko 문구");
    put(KEY, AppLocale.EN, "   ");
    put(KEY, AppLocale.JA, "");

    assertThat(messages.of(KEY, AppLocale.JA, "기본")).isEqualTo("ko 문구");
  }

  @Test
  @DisplayName("ko 요청은 영어로 새지 않는다 — ko 키가 비면 기본 문구로 간다")
  void koRequest_neverFallsToEnglish() {
    put(KEY, AppLocale.EN, "en text");

    assertThat(messages.of(KEY, AppLocale.KO, "기본")).isEqualTo("기본");
  }

  @Test
  @DisplayName("어느 언어에도 없으면 호출한 쪽이 준 기본 문구, ErrorCode 는 코드 이름이다")
  void nothingAnywhere_usesDefault() {
    assertThat(messages.of("NO.SUCH.KEY", AppLocale.JA, "기본")).isEqualTo("기본");
    assertThat(messages.of(ErrorCode.ROUTINE_NOT_FOUND, AppLocale.JA)).isEqualTo("ROUTINE_NOT_FOUND");
  }

  @Test
  @DisplayName("of(ErrorCode) 는 요청 안의 언어를 따르고, 요청 밖은 KO 다")
  void ofErrorCode_followsCurrentLocale() {
    put("INTERNAL_SERVER_ERROR", AppLocale.KO, "ko");
    put("INTERNAL_SERVER_ERROR", AppLocale.JA, "ja");

    assertThat(messages.of(ErrorCode.INTERNAL_SERVER_ERROR)).isEqualTo("ko");
    assertThat(CurrentLocale.callAs(AppLocale.JA, () -> messages.of(ErrorCode.INTERNAL_SERVER_ERROR))).isEqualTo("ja");
  }

  @Test
  @DisplayName("standard() 는 같은 인스턴스를 돌려준다")
  void standard_isShared() {
    assertThat(ErrorMessages.standard()).isSameAs(ErrorMessages.standard());
  }
}
