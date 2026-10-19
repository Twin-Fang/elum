package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RoutineExampleCatalogTest {

  @Test
  @DisplayName("분류마다 예시 일과가 2개씩 있다 — 0개면 고른 분류에 아무것도 안 들어간다")
  void everyCategoryHasTwoExamples() {
    for (RoutineExampleCategory category : RoutineExampleCategory.values()) {
      assertThat(RoutineExampleCatalog.of(category)).as(category.name()).hasSize(2);
    }
    assertThat(RoutineExampleCatalog.ALL).hasSize(8);
  }

  @Test
  @DisplayName("모든 카드의 픽토그램 id 가 카탈로그에 있다 — 없으면 카드 그림 자리가 빈다")
  void everyPictogramIdExistsInCatalog() {
    PictogramCatalog pictograms = new PictogramCatalog();
    assertThat(pictograms.isEmpty()).isFalse();
    for (RoutineExample example : RoutineExampleCatalog.ALL) {
      for (RoutineExampleStep step : example.steps()) {
        assertThat(pictograms.contains(step.pictogramId()))
          .as(example.titleKo() + " / " + step.textKo() + " -> " + step.pictogramId())
          .isTrue();
      }
    }
  }

  @Test
  @DisplayName("제목·카드 문장이 ko·en 모두 비어 있지 않고 카드가 3장 이상이다")
  void noBlankText() {
    for (RoutineExample example : RoutineExampleCatalog.ALL) {
      assertThat(example.titleKo()).isNotBlank();
      assertThat(example.titleEn()).isNotBlank();
      assertThat(example.scheduledTime()).isNotNull();
      assertThat(example.steps()).as(example.titleKo()).hasSizeGreaterThanOrEqualTo(3);
      for (RoutineExampleStep step : example.steps()) {
        assertThat(step.textKo()).isNotBlank();
        assertThat(step.textEn()).isNotBlank();
      }
    }
  }
}
