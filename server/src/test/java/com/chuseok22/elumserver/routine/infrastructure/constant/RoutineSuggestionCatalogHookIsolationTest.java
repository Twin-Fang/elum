package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 테스트 훅이 ALL 을 오염시키지 않는지 본다 (다국어 #526).
 *
 * <p>ALL 은 클래스 로드 때 한 번 정해진다. 훅을 건 채 이 클래스가 처음 로드돼도 가짜 문구로 고정되면 안 된다.
 * 이 클래스만 단독 실행하면 로드 순서가 "훅 먼저"가 되어 오염 여부가 드러난다.
 */
class RoutineSuggestionCatalogHookIsolationTest {

  @AfterEach
  void tearDown() {
    RoutinePhrases.resetStandardForTesting();
  }

  @Test
  @DisplayName("훅을 건 채 처음 읽어도 ALL 은 실제 ko 58개이고 가짜 문구가 아니다")
  void all_isNotAffectedByTestHook() {
    Map<String, String> fake = Map.of(
      "suggestion.01.icon", "F", "suggestion.01.text", "fake-text", "suggestion.01.example", "fake-ex");
    RoutinePhrases.overrideStandardForTesting(new RoutinePhrases(locale -> fake));

    assertThat(RoutineSuggestionCatalog.ALL).hasSize(58);
    assertThat(RoutineSuggestionCatalog.ALL).extracting("text").doesNotContain("fake-text");
  }
}
