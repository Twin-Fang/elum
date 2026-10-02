package com.chuseok22.elumserver.routine.infrastructure.guard;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.EnabledLocales;
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
    Map<String, String> map = new HashMap<>();
    map.put("suggestion.01.icon", "I");
    map.put("suggestion.01.text", tag + "-text");
    map.put("suggestion.01.example", tag + "-example");
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
    ko.put("suggestion.03.icon", "I");
    ko.put("suggestion.03.text", "ko-text3");
    ko.put("suggestion.03.example", "ko-example3");

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
  @DisplayName("ApplicationRunner 로 등록돼 기동 때 실제로 검사한다")
  void isAnApplicationRunner() {
    assertThat(ApplicationRunner.class).isAssignableFrom(RoutinePhrasesStartupGuard.class);
  }

  @Test
  @DisplayName("실제 문구 파일과 기본 설정(ko)으로는 검사를 통과한다 — 번호 구멍도 없다")
  void realFiles_defaultConfig_passes() {
    assertThatCode(() -> new RoutinePhrasesStartupGuard(enabled("ko")).verify()).doesNotThrowAnyException();
    assertThat(RoutinePhrases.standard().koNumberingProblems()).isEmpty();
  }
}
