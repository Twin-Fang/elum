package com.chuseok22.elumserver.routine.infrastructure.guard;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.ApplicationRunner;

class RoutinePhrasesStartupGuardTest {

  @AfterEach
  void tearDown() {
    RoutinePhrases.resetStandardForTesting();
  }

  private static Map<String, String> full(String tag) {
    return full(tag, RoutinePhrasesStartupGuard.MIN_SUGGESTIONS);
  }

  private static Map<String, String> full(String tag, int suggestions) {
    Map<String, String> map = new HashMap<>();
    for (int i = 1; i <= suggestions; i++) {
      String n = "%02d".formatted(i);
      map.put("suggestion." + n + ".icon", "I");
      map.put("suggestion." + n + ".text", tag + "-text" + n);
      map.put("suggestion." + n + ".example", tag + "-example" + n);
    }
    for (String goal : List.of("PREPARE_ITEMS", "PREPARE_NEW")) {
      map.put("fallback." + goal + ".question", tag + "-q");
      for (int i = 1; i <= 3; i++) {
        map.put("fallback." + goal + ".option." + i + ".emoji", "E");
        map.put("fallback." + goal + ".option." + i + ".label", tag + "-o" + i);
      }
    }
    return map;
  }

  private static EnabledLocales enabled(String csv) {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).thenReturn(csv);
    return new EnabledLocales(config);
  }

  private RoutinePhrasesStartupGuard guard(String enabledCsv, Map<AppLocale, Map<String, String>> files) {
    return new RoutinePhrasesStartupGuard(
      enabled(enabledCsv), new RoutinePhrases(locale -> files.getOrDefault(locale, Map.of())));
  }

  @Test
  @DisplayName("ko 만 켜져 있으면 다른 언어 파일이 비어 있어도 뜬다 — 지금의 배포 상태")
  void koOnly_startsEvenWithEmptyOtherFiles() {
    assertThatCode(() -> guard("ko", Map.of(AppLocale.KO, full("ko"))).verify()).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("ko,ja 켜짐 + ja 문구 완성이면 뜬다")
  void enabledJaComplete_starts() {
    assertThatCode(() -> guard("ko,ja", Map.of(AppLocale.KO, full("ko"), AppLocale.JA, full("ja"))).verify())
      .doesNotThrowAnyException();
  }

  @Test
  @DisplayName("켜진 언어의 문구 한 벌이 비어 있으면 서버가 뜨지 않는다 — 빠진 언어와 키를 알린다")
  void enabledButEmpty_blocksStartup() {
    var guard = guard("ko,ja", Map.of(AppLocale.KO, full("ko")));

    assertThatThrownBy(guard::verify)
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("ja")
      .hasMessageContaining("fallback.PREPARE_ITEMS");
  }

  @Test
  @DisplayName("DB 직접 수정으로 관리자 가드를 우회해 켜진 es 가 비어 있으면 기동이 실패한다")
  void dbDirectEdit_enablesEmptyEs_blocksStartup() {
    // 관리자 화면(CONTENT_LOCALE_NOT_READY)을 지나지 않고 DB 값만 ko,es 로 바뀐 상황
    var guard = guard("ko,es", Map.of(AppLocale.KO, full("ko")));

    assertThatThrownBy(guard::verify)
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("es 빈 키")
      .hasMessageContaining("fallback.PREPARE_ITEMS.option.1.emoji");
  }

  @Test
  @DisplayName("켜진 언어가 키 하나만 비어도 서버가 뜨지 않는다")
  void enabledButOneKeyMissing_blocksStartup() {
    Map<String, String> en = full("en");
    en.put("fallback.PREPARE_NEW.option.3.label", "");
    var guard = guard("ko,en", Map.of(AppLocale.KO, full("ko"), AppLocale.EN, en));

    assertThatThrownBy(guard::verify)
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("fallback.PREPARE_NEW.option.3.label");
  }

  @Test
  @DisplayName("켜진 언어가 한 벌을 모두 채웠으면 뜬다")
  void enabledAndComplete_starts() {
    assertThatCode(() -> guard("ko,en", Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en"))).verify())
      .doesNotThrowAnyException();
  }

  @Test
  @DisplayName("ko 파일 자체가 비면 아무 언어도 안 켜도 서버가 뜨지 않는다 — 모든 대체 순서의 끝이다")
  void koEmpty_blocksStartup() {
    assertThatThrownBy(() -> guard("ko", Map.of()).verify()).isInstanceOf(IllegalStateException.class);
  }

  @Test
  @DisplayName("ko 추천 번호에 구멍이 있으면 구멍 뒤 문구가 잘리므로 서버가 뜨지 않는다 — 어느 키인지 알린다")
  void koSuggestionNumberHole_blocksStartup() {
    Map<String, String> ko = full("ko");
    // 02 를 빼면 03 이후는 번호가 끊겨 읽히지 않는다(개수 하한과 별개로 구멍을 알린다).
    ko.remove("suggestion.02.icon");
    ko.remove("suggestion.02.text");
    ko.remove("suggestion.02.example");

    assertThatThrownBy(() -> guard("ko", Map.of(AppLocale.KO, ko)).verify())
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("ko")
      .hasMessageContaining("suggestion.03");
  }

  @Test
  @DisplayName("ko 폴백 선택지 번호에 구멍이 있어도 서버가 뜨지 않는다")
  void koOptionNumberHole_blocksStartup() {
    Map<String, String> ko = full("ko");
    ko.put("fallback.PREPARE_ITEMS.option.5.emoji", "E");
    ko.put("fallback.PREPARE_ITEMS.option.5.label", "ko-o5");

    assertThatThrownBy(() -> guard("ko", Map.of(AppLocale.KO, ko)).verify())
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("fallback.PREPARE_ITEMS.option.5");
  }

  @Test
  @DisplayName("ko 폴백 질문이 없으면 서버가 뜨지 않는다")
  void koFallbackQuestionMissing_blocksStartup() {
    Map<String, String> ko = full("ko");
    ko.remove("fallback.PREPARE_NEW.question");

    assertThatThrownBy(() -> guard("ko", Map.of(AppLocale.KO, ko)).verify())
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("fallback.PREPARE_NEW.question");
  }

  @Test
  @DisplayName("ko 추천이 하한보다 하나 적은 49개면 서버가 뜨지 않는다 — 몇 개인지 알린다")
  void koSuggestionsBelowMinimum_blocksStartup() {
    assertThatThrownBy(() -> guard("ko", Map.of(AppLocale.KO, full("ko", 49))).verify())
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("ko 추천 일과 49개")
      .hasMessageContaining("최소 50개");
  }

  @Test
  @DisplayName("ko 추천이 하한과 같은 50개면 뜬다")
  void koSuggestionsAtMinimum_starts() {
    assertThatCode(() -> guard("ko", Map.of(AppLocale.KO, full("ko", 50))).verify()).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("ko 추천이 하나도 없어도 서버가 뜨지 않는다")
  void koSuggestionsZero_blocksStartup() {
    assertThatThrownBy(() -> guard("ko", Map.of(AppLocale.KO, full("ko", 0))).verify())
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("ko 추천 일과 0개");
  }

  @Test
  @DisplayName("켜진 언어에 미지원 코드가 섞인 DB 값(ko,xx)이어도 서버가 터지지 않고 ko 로 본다")
  void unknownCodeInDb_treatedAsKo() {
    assertThatCode(() -> guard("ko,xx", Map.of(AppLocale.KO, full("ko"))).verify()).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("시딩 전이라 설정을 읽지 못해도 ko 로 검사하고 뜬다 — @Order 가 필요 없다")
  void configUnreadable_fallsBackToKo() {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).thenThrow(new IllegalStateException("not seeded"));
    var guard = new RoutinePhrasesStartupGuard(
      new EnabledLocales(config), new RoutinePhrases(locale -> locale == AppLocale.KO ? full("ko") : Map.of()));

    assertThatCode(guard::verify).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("운영 생성자는 호출 시점의 standard() 를 검사한다 — 켜진 언어가 비면 막힌다")
  void productionConstructor_usesStandardAtRunTime() {
    RoutinePhrases.overrideStandardForTesting(new RoutinePhrases(locale -> locale == AppLocale.KO ? full("ko") : Map.of()));

    assertThatCode(() -> new RoutinePhrasesStartupGuard(enabled("ko")).verify()).doesNotThrowAnyException();
    assertThatThrownBy(() -> new RoutinePhrasesStartupGuard(enabled("ko,es")).verify())
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("es");
  }

  @Test
  @DisplayName("기동 진입점 run() 이 검사를 실제로 부른다 — 켜진 es 가 비면 run() 이 예외를 던진다")
  void run_invokesVerify_blocksStartup() {
    ApplicationRunner runner = guard("ko,es", Map.of(AppLocale.KO, full("ko")));

    assertThatThrownBy(() -> runner.run(null))
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("es 빈 키")
      .hasMessageContaining("fallback.PREPARE_ITEMS");
  }

  @Test
  @DisplayName("정상 설정에서는 run() 이 예외 없이 끝난다")
  void run_passesWhenComplete() {
    ApplicationRunner runner = guard("ko", Map.of(AppLocale.KO, full("ko")));

    assertThatCode(() -> runner.run(null)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("타입만 본다: ApplicationRunner 구현이다 (연결은 run_* 테스트가 증명)")
  void typeOnly_isAnApplicationRunner() {
    assertThat(ApplicationRunner.class).isAssignableFrom(RoutinePhrasesStartupGuard.class);
  }

  @Test
  @DisplayName("실제 문구 파일과 기본 설정(ko)으로는 검사를 통과한다 — 번호 구멍도 없다")
  void realFiles_defaultConfig_passes() {
    assertThatCode(() -> new RoutinePhrasesStartupGuard(enabled("ko")).verify()).doesNotThrowAnyException();
    assertThat(RoutinePhrases.standard().koNumberingProblems()).isEmpty();
  }
}
