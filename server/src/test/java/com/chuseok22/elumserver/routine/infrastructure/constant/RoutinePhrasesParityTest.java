package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * ko 추천 일과·폴백 질문이 다국어 작업 전과 같다는 증명 (다국어 #521).
 *
 * <p>golden 은 작업 전 {@code RoutineSuggestionCatalog} 의 58개와 {@code RoutineAiPipeline} 폴백 질문을 JSON 으로
 * 따로 고정한 것이다. 이모지의 ZWJ·변형 선택자까지 같은 코드 포인트여야 한다.
 */
class RoutinePhrasesParityTest {

  private static JsonNode golden() throws Exception {
    try (InputStream in = RoutinePhrasesParityTest.class.getResourceAsStream("/i18n/golden/routine-phrases-ko.json")) {
      assertThat(in).as("golden 파일").isNotNull();
      return new ObjectMapper().readTree(in);
    }
  }

  @Test
  @DisplayName("접미사 없는 routine-phrases.properties 는 없다 — 있으면 부모 체인으로 대체 순서가 조용히 깨진다")
  void noBasePhrasesFile() {
    assertThat(getClass().getResource("/i18n/routine-phrases.properties")).isNull();
  }

  @Test
  @DisplayName("ko 추천 일과 58개가 작업 전과 같은 순서·같은 글자다")
  void koSuggestions_identicalToLegacy() throws Exception {
    JsonNode legacy = golden().get("suggestions");

    assertThat(legacy).hasSize(58);
    assertThat(RoutineSuggestionCatalog.ALL).hasSize(58);
    for (int i = 0; i < legacy.size(); i++) {
      var actual = RoutineSuggestionCatalog.ALL.get(i);
      assertThat(actual.icon()).as("icon #%d", i + 1).isEqualTo(legacy.get(i).get("icon").asText());
      assertThat(actual.text()).as("text #%d", i + 1).isEqualTo(legacy.get(i).get("text").asText());
      assertThat(actual.naturalLanguageExample()).as("example #%d", i + 1)
        .isEqualTo(legacy.get(i).get("example").asText());
    }
  }

  @Test
  @DisplayName("헤더 없음(KO): 추천 일과 목록은 ALL 과 같다")
  void headerless_suggestions_areAll() {
    assertThat(RoutineSuggestionCatalog.forLocale(AppLocale.KO)).isEqualTo(RoutineSuggestionCatalog.ALL);
  }

  @Test
  @DisplayName("ko 폴백 질문(질문·선택지 이모지·라벨)이 작업 전과 같다")
  void koFallbackQuestions_identicalToLegacy() throws Exception {
    JsonNode legacy = golden().get("fallback");

    for (SupportGoal goal : List.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW)) {
      JsonNode expected = legacy.get(goal.name());
      var actual = RoutinePhrases.standard().fallbackQuestion(goal, AppLocale.KO);

      assertThat(actual.question()).as(goal.name()).isEqualTo(expected.get("question").asText());
      assertThat(actual.options()).as(goal.name()).hasSize(expected.get("options").size());
      for (int i = 0; i < actual.options().size(); i++) {
        assertThat(actual.options().get(i).emoji()).isEqualTo(expected.get("options").get(i).get("emoji").asText());
        assertThat(actual.options().get(i).label()).isEqualTo(expected.get("options").get(i).get("label").asText());
      }
    }
  }
}
