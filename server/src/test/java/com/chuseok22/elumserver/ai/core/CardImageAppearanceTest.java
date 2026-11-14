package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 다시 그리기 생김새 고르기 (#1384): 요청이 건드린 조각만 빼고 인물은 그대로 둔다
class CardImageAppearanceTest {

  // 운영 기본 생김새 (PromptDefaults CARD_IMAGE_SUBJECT_CHILD 와 같은 모양)
  private static final String DEFAULT_CHILD = "a simple cartoon child with a round head, short black bowl-cut hair, "
    + "dot eyes, rosy cheeks, a plain orange hoodie and gray long pants";

  @Test
  @DisplayName("옷 요청 다시 그리기 — 기본 옷만 빠지고 머리·얼굴 묘사는 유지 (기본 후드티가 교복을 덮지 않게)")
  void clothingRedraw_dropsOnlyClothing() {
    String appearance = CardImageAppearance.forScene(DEFAULT_CHILD,
      "The character, wearing a navy school uniform, picks up an umbrella.", true);

    assertThat(appearance)
      .isEqualTo("a simple cartoon child with a round head, short black bowl-cut hair, dot eyes, rosy cheeks");
  }

  @Test
  @DisplayName("머리 요청 다시 그리기 — 기본 머리만 빠지고 옷·얼굴 묘사는 유지")
  void hairRedraw_dropsOnlyHair() {
    String appearance = CardImageAppearance.forScene(DEFAULT_CHILD,
      "The character with long pigtail hair brushes the teeth.", true);

    assertThat(appearance)
      .isEqualTo("a simple cartoon child with a round head, dot eyes, rosy cheeks, a plain orange hoodie and gray long pants");
  }

  @Test
  @DisplayName("안경 요청은 더하기라 아무것도 빼지 않는다 — 인물이 달라지지 않게")
  void glassesRedraw_keepsDefault() {
    assertThat(CardImageAppearance.forScene(DEFAULT_CHILD, "The character in round glasses reads a book.", true))
      .isEqualTo(DEFAULT_CHILD);
  }

  @Test
  @DisplayName("옷·머리를 말하지 않는 다시 그리기는 기본 생김새 그대로")
  void redrawWithoutLookWords_keepsDefault() {
    assertThat(CardImageAppearance.forScene(DEFAULT_CHILD, "The character holds a cup instead of an umbrella.", true))
      .isEqualTo(DEFAULT_CHILD);
  }

  @Test
  @DisplayName("첫 그림(보호자 요청 없음)은 장면이 옷을 말해도 기본 생김새 그대로 — 일과 카드 인물이 흔들리지 않게")
  void firstDrawing_keepsDefault() {
    assertThat(CardImageAppearance.forScene(DEFAULT_CHILD, "The character, wearing a raincoat, walks outside.", false))
      .isEqualTo(DEFAULT_CHILD);
  }

  @Test
  @DisplayName("빈 생김새·빈 장면·다 빠지는 생김새도 예외 없이 기본값 그대로 — 그림 경로가 멈추지 않게")
  void edgeCases_neverThrow() {
    assertThat(CardImageAppearance.forScene(null, "wearing a coat", true)).isNull();
    assertThat(CardImageAppearance.forScene(DEFAULT_CHILD, null, true)).isEqualTo(DEFAULT_CHILD);
    assertThat(CardImageAppearance.forScene("an orange hoodie", "wearing a coat", true)).isEqualTo("an orange hoodie");
  }

  @Test
  @DisplayName("조각으로 나눴다 다 넣어 조립하면 원래 생김새와 같다 — 첫 그림 프롬프트가 바뀌지 않게")
  void parseAndAssembleAll_roundTrips() {
    assertThat(CardImageAppearance.parse(DEFAULT_CHILD).assemble(true, true)).isEqualTo(DEFAULT_CHILD);
  }
}
