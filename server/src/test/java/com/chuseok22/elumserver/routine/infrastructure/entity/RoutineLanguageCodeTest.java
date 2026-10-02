package com.chuseok22.elumserver.routine.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RoutineLanguageCodeTest {

  @Test
  @DisplayName("언어가 null 인 옛 행은 ko 코드로 본다")
  void nullLanguage_isKo() {
    Routine routine = new Routine();
    routine.setLanguage(null);

    assertThat(routine.languageCode()).isEqualTo("ko");
  }

  @Test
  @DisplayName("저장된 언어는 소문자 코드로 나온다")
  void storedLanguage_isLowercaseCode() {
    Routine routine = new Routine();
    routine.setLanguage(AppLocale.JA);

    assertThat(routine.languageCode()).isEqualTo("ja");
  }
}
