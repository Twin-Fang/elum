package com.chuseok22.elumserver.common.locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class AppLocaleTest {

  @Test
  @DisplayName("내부 코드는 소문자 두 글자다")
  void codes() {
    assertThat(List.of(AppLocale.values()).stream().map(AppLocale::code).toList())
      .containsExactly("ko", "en", "ja", "zh", "es");
  }

  @Test
  @DisplayName("대체 순서는 요청 언어 → en → ko 이고 ko 요청은 ko 만 본다")
  void fallbackChain() {
    assertThat(AppLocale.JA.fallbackChain()).containsExactly(AppLocale.JA, AppLocale.EN, AppLocale.KO);
    assertThat(AppLocale.ZH.fallbackChain()).containsExactly(AppLocale.ZH, AppLocale.EN, AppLocale.KO);
    assertThat(AppLocale.ES.fallbackChain()).containsExactly(AppLocale.ES, AppLocale.EN, AppLocale.KO);
    assertThat(AppLocale.EN.fallbackChain()).containsExactly(AppLocale.EN, AppLocale.KO);
    // C2: 한국어 사용자에게 영어가 새면 안 된다
    assertThat(AppLocale.KO.fallbackChain()).containsExactly(AppLocale.KO);
  }

  @Test
  @DisplayName("fromCode 는 정확히 일치하는 코드만 받는다")
  void fromCode_exact() {
    assertThat(AppLocale.fromCode("ja")).isEqualTo(AppLocale.JA);
    assertThat(AppLocale.fromCode("zh")).isEqualTo(AppLocale.ZH);
  }

  @ParameterizedTest
  @ValueSource(strings = {"KO", "zh-Hans", "xx", "", " ko"})
  @DisplayName("fromCode 는 대소문자가 다르거나 모르는 코드면 IllegalArgumentException")
  void fromCode_rejectsOthers(String code) {
    assertThatThrownBy(() -> AppLocale.fromCode(code)).isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  @DisplayName("fromCode(null) 도 IllegalArgumentException 이다")
  void fromCode_null() {
    assertThatThrownBy(() -> AppLocale.fromCode(null)).isInstanceOf(IllegalArgumentException.class);
  }

  @ParameterizedTest
  @NullAndEmptySource
  @ValueSource(strings = {" ", "\t", "   \n"})
  @DisplayName("헤더가 없거나 비었으면 ko — 이미 배포된 앱")
  void noHeader_isKo(String header) {
    assertThat(AppLocale.fromAcceptLanguage(header)).isEqualTo(AppLocale.KO);
  }

  @ParameterizedTest
  @CsvSource(delimiter = '|', value = {
    "ko|KO", "en|EN", "ja|JA", "zh-Hans|ZH", "es|ES",
    "ko-KR|KO", "en-US|EN", "ja-JP|JA", "es-MX|ES", "zh_CN|ZH",
    "JA|JA", "KO;q=1|KO", "ko-KR,en;q=0.5|KO",
    // C1: zh* 는 모두 zh. 번체 판단은 클라이언트의 몫이다
    "zh-TW|ZH", "zh-Hant|ZH", "zh-HK|ZH",
    // 5개 밖·깨진 값은 en
    "ar|EN", "fr-FR|EN", "*|EN", "xx|EN", ";q=0.5|EN", ",|EN", "-|EN", "_ko|EN",
    // 품질값은 순서를 바꾸지 않는다 — 첫 태그만 본다(C1)
    "en;q=0.1, ja;q=0.9|EN", "ja;q=0.1, en;q=0.9|JA"
  })
  @DisplayName("첫 번째 태그의 기본 언어만 본다 — 지원 밖이거나 깨졌으면 en")
  void firstTagOnly(String header, AppLocale expected) {
    assertThat(AppLocale.fromAcceptLanguage(header)).isEqualTo(expected);
  }

  @Test
  @DisplayName("어떤 값이 와도 터지지 않는다")
  void neverThrows() {
    List<String> weird = List.of(
      "\u0000\u0000", "a".repeat(10_000), ";;;", "q=1", "en;;;q=", ",,,ja", "ko,,,", "日本語", "😀");
    for (String header : weird) {
      assertThatCode(() -> AppLocale.fromAcceptLanguage(header)).doesNotThrowAnyException();
    }
    assertThat(AppLocale.fromAcceptLanguage(",,,ja")).isEqualTo(AppLocale.JA);
  }
}
