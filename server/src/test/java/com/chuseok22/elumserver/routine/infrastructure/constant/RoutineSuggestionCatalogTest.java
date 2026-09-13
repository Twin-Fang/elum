package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import java.util.List;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RoutineSuggestionCatalogTest {

  @Test
  @DisplayName("추천 일과 카탈로그는 충분한 수의 항목을 갖는다")
  void all_hasEnoughEntries() {
    // 정확한 개수를 고정하면 항목을 추가할 때마다 테스트가 깨진다.
    // 홈 화면에 무작위로 노출하기에 부족하지 않은지만 본다.
    assertThat(RoutineSuggestionCatalog.ALL).hasSizeGreaterThanOrEqualTo(50);
  }

  @Test
  @DisplayName("추천 일과에 내면 조절 표현이 들어가지 않는다")
  void all_hasNoInternalRegulationEntries() {
    // 2026-09-13 서울 ABA연구소 자문 —
    // "마음을 다스리기" 같은 내면 조절은 카드로 만들 수 없다.
    // 눈으로 "했다/안 했다"를 확인할 수 없으면 `했어요!` 버튼을 누를 수 없고 수행률도 계산되지 않는다.
    // 기분이 나쁘면 폰을 던지지, 속으로 조절하지 않는다는 것이 소장님의 지적이었다.
    List<String> forbidden = List.of("다스리", "진정", "참기", "마음을", "화해", "감정을");

    assertThat(RoutineSuggestionCatalog.ALL)
      .allSatisfy(suggestion -> {
        String combined = suggestion.text() + " " + suggestion.naturalLanguageExample();
        assertThat(forbidden)
          .as("내면 조절 표현이 포함된 추천 일과: %s", suggestion.text())
          .noneMatch(combined::contains);
      });
  }

  @Test
  @DisplayName("추천 일과에 성인 사용자를 위한 항목이 포함된다")
  void all_containsAdultEntries() {
    // 자문 당시 추천 50개가 전부 아동·학교 전제였고,
    // 회사에 다니는 성인 사용자에게 "학교에 가요"가 노출되는 문제가 실제로 있었다.
    List<String> texts = RoutineSuggestionCatalog.ALL.stream()
      .map(RoutineSuggestionResponse::text)
      .toList();

    assertThat(texts).anyMatch(text -> text.contains("출근"));
    assertThat(texts).anyMatch(text -> text.contains("센터"));
  }

  @Test
  @DisplayName("추천 일과 카탈로그는 아이콘/문구/자연어 예시가 비어있지 않다")
  void all_entriesHaveIconTextAndExample() {
    assertThat(RoutineSuggestionCatalog.ALL)
      .allSatisfy(suggestion -> {
        assertThat(suggestion.icon()).isNotBlank();
        assertThat(suggestion.text()).isNotBlank();
        assertThat(suggestion.naturalLanguageExample()).isNotBlank();
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

  @Test
  @DisplayName("추천 일과 카탈로그의 자연어 예시는 서로 중복되지 않는다")
  void all_naturalLanguageExamplesAreDistinct() {
    List<String> examples = RoutineSuggestionCatalog.ALL.stream()
      .map(RoutineSuggestionResponse::naturalLanguageExample)
      .collect(Collectors.toList());

    assertThat(examples).doesNotHaveDuplicates();
  }
}
