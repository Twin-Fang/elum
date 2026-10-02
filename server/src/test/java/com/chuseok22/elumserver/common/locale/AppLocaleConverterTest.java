package com.chuseok22.elumserver.common.locale;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class AppLocaleConverterTest {

  private final AppLocaleConverter converter = new AppLocaleConverter();

  @Test
  @DisplayName("DB 에는 소문자 코드로 저장하고 그대로 읽는다")
  void roundTrip() {
    for (AppLocale locale : AppLocale.values()) {
      assertThat(converter.convertToDatabaseColumn(locale)).isEqualTo(locale.code());
      assertThat(converter.convertToEntityAttribute(locale.code())).isEqualTo(locale);
    }
  }

  @Test
  @DisplayName("손상된 값·빈 값으로 일과 조회가 죽지 않는다 — ko 로 읽는다")
  void brokenValues_readAsKo() {
    assertThat(converter.convertToEntityAttribute(null)).isEqualTo(AppLocale.KO);
    assertThat(converter.convertToEntityAttribute("")).isEqualTo(AppLocale.KO);
    assertThat(converter.convertToEntityAttribute("xx")).isEqualTo(AppLocale.KO);
    assertThat(converter.convertToEntityAttribute(" EN ")).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("null 은 null 로 저장한다 — NOT NULL 제약이 잡는다")
  void nullWrite() {
    assertThat(converter.convertToDatabaseColumn(null)).isNull();
  }
}
