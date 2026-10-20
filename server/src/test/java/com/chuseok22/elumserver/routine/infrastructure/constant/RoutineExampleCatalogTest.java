package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
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

  @Test
  @DisplayName("모든 카드에 예시 이미지 id 가 있고, 앱 에셋 폴더가 있으면 그 파일도 있다 — 없으면 옛 픽토그램이 다시 나온다")
  void everyStepHasExampleImageThatExistsInClientAssets() {
    // 서버만 체크아웃한 환경(도커 빌드)에서는 앱 폴더가 없어 파일 검사를 건너뜀
    Path assetDirectory = Path.of("..", "client", "assets", "images", "example_routines");
    boolean canCheckFiles = Files.isDirectory(assetDirectory);
    for (RoutineExample example : RoutineExampleCatalog.ALL) {
      for (RoutineExampleStep step : example.steps()) {
        String label = example.titleKo() + " / " + step.textKo();
        assertThat(step.exampleImageId()).as(label).matches("[a-z_]+");
        if (canCheckFiles) {
          assertThat(Files.exists(assetDirectory.resolve(step.exampleImageId() + ".webp")))
            .as(label + " -> " + step.exampleImageId()).isTrue();
        }
      }
    }
  }

  @Test
  @DisplayName("같은 행동이 아니면 예시 이미지가 겹치지 않는다 — 양치·화장실 가기만 공유")
  void exampleImagesAreSharedOnlyBySameAction() {
    Map<String, Set<String>> textsByImage = new HashMap<>();
    for (RoutineExample example : RoutineExampleCatalog.ALL) {
      for (RoutineExampleStep step : example.steps()) {
        textsByImage.computeIfAbsent(step.exampleImageId(), key -> new HashSet<>()).add(step.textKo());
      }
    }
    textsByImage.forEach((imageId, texts) -> assertThat(texts).as(imageId).hasSize(1));
  }
}
