package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.application.dto.request.CardSplitRequest;
import com.chuseok22.elumserver.routine.application.dto.response.CardSplitSuggestionResponse;
import com.chuseok22.elumserver.routine.core.RoutineMemorySafetyFilter;
import com.chuseok22.elumserver.routine.core.RoutineStepTextLimits;
import com.chuseok22.elumserver.routine.infrastructure.ai.CardSplitAi;
import java.util.ArrayList;
import java.util.List;

/**
 * 카드 나누기 검증: AI 안(장수 2~3, 제목·설명 길이, 금지 낱말·연락처), 적용 요청(장수 2~3, 제목·설명 길이)
 * AI 안은 하나라도 어긋나면 안 전체를 버림 (부분 채택 없음)
 */
final class CardSplitValidator {

  static final int MIN_CARDS = 2;
  static final int MAX_CARDS = 3;
  static final String STATUS_SUGGESTED = "SUGGESTED";
  static final String STATUS_ALREADY_SHORT = "ALREADY_SHORT";

  private CardSplitValidator() {
  }

  /// 검증 결과: 통과하면 응답 안, 걸리면 rejectionReason (로그용 짧은 영문, 카드 글 없음)
  record SuggestionResult(CardSplitSuggestionResponse suggestion, String rejectionReason) {

    boolean isAccepted() {
      return rejectionReason == null;
    }
  }

  /// AI 안 > 응답 안 (ALREADY_SHORT 는 cards 를 보지 않음)
  static SuggestionResult validateSuggestion(CardSplitAi.RawSuggestion raw) {
    if (STATUS_ALREADY_SHORT.equals(raw.status())) {
      return new SuggestionResult(CardSplitSuggestionResponse.alreadyShort(), null);
    }
    if (!STATUS_SUGGESTED.equals(raw.status())) {
      return rejected("unknown status");
    }
    if (raw.cards().size() < MIN_CARDS || raw.cards().size() > MAX_CARDS) {
      return rejected("card count");
    }
    List<CardSplitSuggestionResponse.Card> cards = new ArrayList<>();
    for (CardSplitAi.RawCard rawCard : raw.cards()) {
      String title = rawCard.title().trim();
      String description = rawCard.description().trim();
      String reason = textRejectionReason(title, description);
      if (reason != null) {
        return rejected(reason);
      }
      cards.add(new CardSplitSuggestionResponse.Card(title, description));
    }
    return new SuggestionResult(CardSplitSuggestionResponse.suggested(cards), null);
  }

  /// 적용 요청이 쓸 수 있는가 (장수·제목 비어 있지 않음·길이). 카드 추가·수정과 같은 글 규칙이라 금지 낱말은 보지 않음
  static boolean isApplicable(List<CardSplitRequest.Card> cards) {
    if (cards == null || cards.size() < MIN_CARDS || cards.size() > MAX_CARDS) {
      return false;
    }
    return cards.stream().allMatch(card -> card != null && card.title() != null
      && !card.title().isBlank() && card.title().trim().length() <= RoutineStepTextLimits.TITLE_MAX_LENGTH
      && (card.description() == null
      || card.description().trim().length() <= RoutineStepTextLimits.DESCRIPTION_MAX_LENGTH));
  }

  private static String textRejectionReason(String title, String description) {
    if (title.isEmpty()) {
      return "blank title";
    }
    if (title.length() > RoutineStepTextLimits.TITLE_MAX_LENGTH
      || description.length() > RoutineStepTextLimits.DESCRIPTION_MAX_LENGTH) {
      return "too long";
    }
    if (RoutineMemorySafetyFilter.hasForbiddenTermOrContact(title)
      || RoutineMemorySafetyFilter.hasForbiddenTermOrContact(description)) {
      return "forbidden term";
    }
    return null;
  }

  private static SuggestionResult rejected(String reason) {
    return new SuggestionResult(null, reason);
  }
}
