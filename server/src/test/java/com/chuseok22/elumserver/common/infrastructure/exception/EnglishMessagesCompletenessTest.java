package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Properties;
import java.util.TreeSet;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 영어 문구가 한국어 원본의 모든 키를 갖고, 한글이 섞이지 않는다. */
class EnglishMessagesCompletenessTest {

  private static final Pattern HANGUL = Pattern.compile("[가-힣]");

  private static Properties load(String locale) throws IOException {
    Properties p = new Properties();
    try (var in = EnglishMessagesCompletenessTest.class.getResourceAsStream("/i18n/messages_" + locale + ".properties")) {
      p.load(new InputStreamReader(in, StandardCharsets.UTF_8));
    }
    return p;
  }

  @Test
  @DisplayName("영어 문구는 한국어 원본의 모든 키에 비어 있지 않은 값을 준다")
  void everyKoreanKeyHasEnglishText() throws IOException {
    Properties ko = load("ko");
    Properties en = load("en");
    var missing = new TreeSet<String>();
    for (String key : ko.stringPropertyNames()) {
      String text = en.getProperty(key);
      if (text == null || text.isBlank()) {
        missing.add(key);
      }
    }
    assertThat(missing).as("영어 문구가 없는 키").isEmpty();
  }

  @Test
  @DisplayName("영어 문구에는 한글이 없다")
  void englishTextHasNoHangul() throws IOException {
    Properties en = load("en");
    var bad = new TreeSet<String>();
    for (String key : en.stringPropertyNames()) {
      if (HANGUL.matcher(en.getProperty(key)).find()) {
        bad.add(key);
      }
    }
    assertThat(bad).as("한글이 남은 영어 문구").isEmpty();
  }

  @Test
  @DisplayName("영어 문구는 한국어 원본에 없는 키를 만들지 않는다")
  void noExtraKeys() throws IOException {
    var extra = new TreeSet<>(load("en").stringPropertyNames());
    extra.removeAll(load("ko").stringPropertyNames());
    assertThat(extra).isEmpty();
  }
}
