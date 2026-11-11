package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.routine.application.dto.request.CardSplitRequest;
import com.chuseok22.elumserver.routine.application.dto.response.CardSplitSuggestionResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.CardSplitAi;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class CardSplitValidatorTest {

  private static CardSplitAi.RawCard raw(String title, String description) {
    return new CardSplitAi.RawCard(title, description);
  }

  @Test
  @DisplayName("2장·3장 안은 글을 다듬어 통과한다 — 막으면 정상 안이 502 가 된다")
  void acceptsTwoOrThreeCards() {
    CardSplitValidator.SuggestionResult two = CardSplitValidator.validateSuggestion(new CardSplitAi.RawSuggestion(
      "SUGGESTED", List.of(raw(" 컵에 물 담기 ", "컵에 물을 담아요."), raw("칫솔질하기", "칫솔로 이를 닦아요."))));
    CardSplitValidator.SuggestionResult three = CardSplitValidator.validateSuggestion(new CardSplitAi.RawSuggestion(
      "SUGGESTED", List.of(raw("가", "나"), raw("다", "라"), raw("마", "바"))));

    assertThat(two.isAccepted()).isTrue();
    assertThat(two.suggestion().status()).isEqualTo(CardSplitSuggestionResponse.Status.SUGGESTED);
    assertThat(two.suggestion().cards().get(0).title()).isEqualTo("컵에 물 담기");
    assertThat(three.isAccepted()).isTrue();
  }

  @Test
  @DisplayName("ALREADY_SHORT 는 cards 가 차 있어도 빈 목록으로 통과한다")
  void alreadyShort_ignoresCards() {
    CardSplitValidator.SuggestionResult result = CardSplitValidator.validateSuggestion(
      new CardSplitAi.RawSuggestion("ALREADY_SHORT", List.of(raw("가", "나"))));

    assertThat(result.isAccepted()).isTrue();
    assertThat(result.suggestion().status()).isEqualTo(CardSplitSuggestionResponse.Status.ALREADY_SHORT);
    assertThat(result.suggestion().cards()).isEmpty();
  }

  @Test
  @DisplayName("장수 1·4, 모르는 상태, 빈 제목, 긴 글, 진단 낱말은 안 전체를 버린다")
  void rejectsBadSuggestions() {
    List<CardSplitAi.RawSuggestion> bad = List.of(
      new CardSplitAi.RawSuggestion("SUGGESTED", List.of(raw("가", "나"))),
      new CardSplitAi.RawSuggestion("SUGGESTED", List.of(raw("1", "a"), raw("2", "b"), raw("3", "c"), raw("4", "d"))),
      new CardSplitAi.RawSuggestion("MAYBE", List.of(raw("가", "나"), raw("다", "라"))),
      new CardSplitAi.RawSuggestion("SUGGESTED", List.of(raw(" ", "나"), raw("다", "라"))),
      new CardSplitAi.RawSuggestion("SUGGESTED", List.of(raw("가".repeat(101), "나"), raw("다", "라"))),
      new CardSplitAi.RawSuggestion("SUGGESTED", List.of(raw("가", "나".repeat(301)), raw("다", "라"))),
      new CardSplitAi.RawSuggestion("SUGGESTED", List.of(raw("가", "자폐가 있어도 할 수 있어요."), raw("다", "라"))),
      new CardSplitAi.RawSuggestion("SUGGESTED", List.of(raw("가", "나"), raw("연락 010-1234-5678", "라"))));

    bad.forEach(suggestion -> assertThat(CardSplitValidator.validateSuggestion(suggestion).isAccepted())
      .as(suggestion.toString()).isFalse());
  }

  @Test
  @DisplayName("적용 요청은 2~3장, 제목 있음, 길이 안일 때만 쓸 수 있고 설명은 비워도 된다")
  void isApplicable_followsCardEditRules() {
    CardSplitRequest.Card ok = new CardSplitRequest.Card("제목", "설명");
    CardSplitRequest.Card emptyDescription = new CardSplitRequest.Card("제목", null);

    assertThat(CardSplitValidator.isApplicable(List.of(ok, emptyDescription))).isTrue();
    assertThat(CardSplitValidator.isApplicable(List.of(ok))).isFalse();
    assertThat(CardSplitValidator.isApplicable(List.of(ok, ok, ok, ok))).isFalse();
    assertThat(CardSplitValidator.isApplicable(null)).isFalse();
    assertThat(CardSplitValidator.isApplicable(List.of(ok, new CardSplitRequest.Card(" ", "설명")))).isFalse();
    assertThat(CardSplitValidator.isApplicable(List.of(ok, new CardSplitRequest.Card("가".repeat(101), "")))).isFalse();
    assertThat(CardSplitValidator.isApplicable(List.of(ok, new CardSplitRequest.Card("제목", "나".repeat(301))))).isFalse();
  }
}
