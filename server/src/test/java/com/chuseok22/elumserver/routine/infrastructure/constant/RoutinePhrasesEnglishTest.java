package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.Properties;
import java.util.TreeMap;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 실제 en 문구 파일이 ko 한 벌과 같은 구조로 채워졌는지 본다. */
class RoutinePhrasesEnglishTest {

  private static final Pattern HANGUL = Pattern.compile("[\\u1100-\\u11FF\\u3130-\\u318F\\uAC00-\\uD7AF]");
  private static final Pattern FORBIDDEN_WORDS = Pattern.compile(
    "(?i)\\b(child|children|kid|kids|therapy|treatment|training|diagnos\\w*|symptoms?)\\b");
  // 칩에 한 줄로 보이는 길이 상한
  private static final int MAX_CHIP_TEXT_LENGTH = 40;

  private static Map<String, String> load(String code) throws Exception {
    try (InputStream in = RoutinePhrasesEnglishTest.class.getResourceAsStream("/i18n/routine-phrases_" + code + ".properties")) {
      assertThat(in).isNotNull();
      Properties properties = new Properties();
      properties.load(new InputStreamReader(in, StandardCharsets.UTF_8));
      Map<String, String> map = new TreeMap<>();
      properties.stringPropertyNames().forEach(key -> map.put(key, properties.getProperty(key)));
      return map;
    }
  }

  @Test
  @DisplayName("en 한 벌이 완성이다 — 빠진 키가 없다")
  void englishSet_isComplete() {
    assertThat(RoutinePhrases.classpath().incompleteLocales(java.util.List.of(AppLocale.EN))).isEmpty();
  }

  @Test
  @DisplayName("en 키 집합이 ko 와 같고 값이 모두 채워져 있다")
  void englishKeys_matchKo() throws Exception {
    Map<String, String> ko = load("ko");
    Map<String, String> en = load("en");

    assertThat(en.keySet()).isEqualTo(ko.keySet());
    en.forEach((key, value) -> assertThat(value).as(key).isNotBlank());
  }

  @Test
  @DisplayName("icon·emoji 는 ko 와 글자 그대로 같다")
  void englishIcons_identicalToKo() throws Exception {
    Map<String, String> ko = load("ko");
    Map<String, String> en = load("en");

    ko.keySet().stream().filter(key -> key.endsWith(".icon") || key.endsWith(".emoji"))
      .forEach(key -> assertThat(en.get(key)).as(key).isEqualTo(ko.get(key)));
  }

  @Test
  @DisplayName("영어 문구에 한글·child·kid·의료 암시어가 없고 text 는 짧다")
  void englishText_isCleanAndShort() throws Exception {
    Map<String, String> en = load("en");

    en.forEach((key, value) -> {
      if (key.endsWith(".icon") || key.endsWith(".emoji")) {
        return;
      }
      assertThat(HANGUL.matcher(value).find()).as("한글 포함: " + key).isFalse();
      assertThat(FORBIDDEN_WORDS.matcher(value).find()).as("금지어: " + key + " = " + value).isFalse();
    });
    en.entrySet().stream().filter(entry -> entry.getKey().endsWith(".text")).forEach(entry -> {
      assertThat(entry.getValue().length()).as(entry.getKey()).isLessThanOrEqualTo(MAX_CHIP_TEXT_LENGTH);
      assertThat(entry.getValue()).as(entry.getKey()).doesNotEndWith(".");
    });
  }
}
