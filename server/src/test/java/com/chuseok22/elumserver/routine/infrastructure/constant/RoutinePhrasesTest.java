package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 가짜 문구 파일로 "한 벌" 규칙과 대체 순서를 본다. 실제 번역 내용과 무관하다. */
class RoutinePhrasesTest {

  private static Map<String, String> full(String tag) {
    Map<String, String> map = new HashMap<>();
    for (int i = 1; i <= 2; i++) {
      String n = "%02d".formatted(i);
      map.put("suggestion." + n + ".icon", "I" + i);
      map.put("suggestion." + n + ".text", tag + "-text-" + n);
      map.put("suggestion." + n + ".example", tag + "-example-" + n);
    }
    for (String goal : List.of("PREPARE_ITEMS", "PREPARE_NEW")) {
      map.put("fallback." + goal + ".question", tag + "-q-" + goal);
      for (int i = 1; i <= 3; i++) {
        map.put("fallback." + goal + ".option." + i + ".emoji", "E" + i);
        map.put("fallback." + goal + ".option." + i + ".label", tag + "-o" + i);
      }
    }
    return map;
  }

  private static RoutinePhrases phrasesOf(Map<AppLocale, Map<String, String>> files) {
    return new RoutinePhrases(locale -> files.getOrDefault(locale, Map.of()));
  }

  @Test
  @DisplayName("ko 파일이 기준이다 — 같은 키가 모두 채워져 있어야 완성이다")
  void completeWhenAllKoKeysFilled() {
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en")));

    assertThat(phrases.missingKeys(AppLocale.KO)).isEmpty();
    assertThat(phrases.missingKeys(AppLocale.EN)).isEmpty();
    assertThat(phrases.missingKeys(AppLocale.JA)).hasSize(full("ko").size());
  }

  @Test
  @DisplayName("값이 빈 키도 비어 있는 것으로 센다")
  void blankValueCountsAsMissing() {
    Map<String, String> ja = full("ja");
    ja.put("fallback.PREPARE_NEW.option.2.label", "  ");
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.JA, ja));

    assertThat(phrases.missingKeys(AppLocale.JA)).containsExactly("fallback.PREPARE_NEW.option.2.label");
  }

  @Test
  @DisplayName("ko 파일에 꼭 있어야 하는 키(폴백 질문·추천 첫 항목)가 빠지면 ko 도 미완성이다")
  void koStructure_isRequired() {
    Map<String, String> ko = full("ko");
    ko.remove("fallback.PREPARE_NEW.question");
    var phrases = phrasesOf(Map.of(AppLocale.KO, ko));

    assertThat(phrases.missingKeys(AppLocale.KO)).contains("fallback.PREPARE_NEW.question");
  }

  @Test
  @DisplayName("요청 언어가 완성이면 그 언어의 목록을 준다")
  void completeRequestLanguage_isUsed() {
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en"), AppLocale.ES, full("es")));

    assertThat(phrases.suggestions(AppLocale.ES)).extracting("text").containsExactly("es-text-01", "es-text-02");
    assertThat(phrases.fallbackQuestion(SupportGoal.PREPARE_ITEMS, AppLocale.ES).question()).isEqualTo("es-q-PREPARE_ITEMS");
  }

  @Test
  @DisplayName("요청 언어가 미완성이면 en, en 도 미완성이면 ko 로 간다 — 두 언어가 한 목록에 섞이지 않는다")
  void incompleteRequestLanguage_fallsBackAsWholeSet() {
    Map<String, String> partialJa = new HashMap<>();
    partialJa.put("suggestion.01.text", "ja-text-01");
    var withEn = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en"), AppLocale.JA, partialJa));
    var withoutEn = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.JA, partialJa));

    assertThat(withEn.suggestions(AppLocale.JA)).extracting("text").containsExactly("en-text-01", "en-text-02");
    assertThat(withoutEn.suggestions(AppLocale.JA)).extracting("text").containsExactly("ko-text-01", "ko-text-02");
    assertThat(withoutEn.suggestions(AppLocale.ZH)).extracting("text").containsExactly("ko-text-01", "ko-text-02");
  }

  @Test
  @DisplayName("ko 요청은 en 이 완성돼 있어도 영어로 새지 않는다")
  void koRequest_neverFallsToEnglish() {
    Map<String, String> brokenKo = full("ko");
    brokenKo.put("suggestion.02.text", "");
    var phrases = phrasesOf(Map.of(AppLocale.KO, brokenKo, AppLocale.EN, full("en")));

    // ko 가 미완성이어도 KO 요청은 ko 파일을 쓴다(기동 검사가 이 상태를 막는다)
    assertThat(phrases.suggestions(AppLocale.KO).get(0).text()).isEqualTo("ko-text-01");
  }

  @Test
  @DisplayName("선택지 수는 ko 파일을 따른다 — 다른 언어가 더 많이 적어도 같은 개수다")
  void optionCount_followsKo() {
    Map<String, String> en = full("en");
    en.put("fallback.PREPARE_ITEMS.option.4.emoji", "E4");
    en.put("fallback.PREPARE_ITEMS.option.4.label", "extra");
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, en));

    assertThat(phrases.fallbackQuestion(SupportGoal.PREPARE_ITEMS, AppLocale.EN).options()).hasSize(3);
  }

  @Test
  @DisplayName("incompleteLocales 는 미완성인 언어와 빠진 키만 돌려준다")
  void incompleteLocales_listsOnlyIncomplete() {
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en")));

    Map<AppLocale, List<String>> result =
      phrases.incompleteLocales(List.of(AppLocale.KO, AppLocale.EN, AppLocale.JA, AppLocale.ES));

    assertThat(result).containsOnlyKeys(AppLocale.JA, AppLocale.ES);
  }

  @Test
  @DisplayName("실제 문구 파일: 다섯 언어 파일이 모두 있고 ko 는 완성이다")
  void realFiles() {
    for (AppLocale locale : AppLocale.values()) {
      assertThat(getClass().getResource("/i18n/routine-phrases_" + locale.code() + ".properties"))
        .as("파일 %s", locale.code()).isNotNull();
    }
    assertThat(RoutinePhrases.standard().missingKeys(AppLocale.KO)).isEmpty();
    assertThat(RoutinePhrases.standard().suggestions(AppLocale.KO)).hasSize(58);
  }

  @Test
  @DisplayName("실제 문구 파일: 어느 언어도 빈 목록이나 빈 질문을 내지 않는다 — 비어 있으면 ko 로 간다")
  void realFiles_neverEmpty() {
    for (AppLocale locale : AppLocale.values()) {
      assertThat(RoutinePhrases.standard().suggestions(locale)).hasSize(58).allSatisfy(suggestion ->
        assertThat(suggestion.text()).isNotBlank());
      for (SupportGoal goal : List.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW)) {
        var question = RoutinePhrases.standard().fallbackQuestion(goal, locale);
        assertThat(question.question()).isNotBlank();
        assertThat(question.options()).hasSizeGreaterThanOrEqualTo(3).allSatisfy(option ->
          assertThat(option.label()).isNotBlank());
      }
    }
  }
}
