package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import java.util.List;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RoutineSuggestionCatalogTest {

  @Test
  @DisplayName("추천 일과 카탈로그는 정확히 50개다")
  void all_hasFiftyEntries() {
    assertThat(RoutineSuggestionCatalog.ALL).hasSize(50);
  }

  @Test
  @DisplayName("추천 일과 카탈로그는 아이콘/문구가 비어있지 않다")
  void all_entriesHaveIconAndText() {
    assertThat(RoutineSuggestionCatalog.ALL)
      .allSatisfy(suggestion -> {
        assertThat(suggestion.icon()).isNotBlank();
        assertThat(suggestion.text()).isNotBlank();
      });
  }

  @Test
  @DisplayName("추천 일과 카탈로그의 문구는 서로 중복되지 않는다")
  void all_textsAreDistinct() {
    List<String> texts = RoutineSuggestionCatalog.ALL.stream()
      .map(RoutineSuggestionResponse::text)
      .collect(Collectors.toList());

    assertThat(texts).doesNotHaveDuplicates();
  }
}
