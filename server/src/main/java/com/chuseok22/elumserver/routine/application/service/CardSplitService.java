package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.CardSplitRequest;
import com.chuseok22.elumserver.routine.application.dto.response.CardSplitSuggestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.CardSplitAi;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 이 카드 더 쉽게(Pro): 카드 한 장 > AI 가 2~3장으로 나눈 안(저장 없음), 고른 안 적용(카드 교체)
 * 안 받기: 권한 > Pro 확인 > 짧은 카드 거름 > 하루 비용 상한 > AI > 검증. 크레딧 없음
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CardSplitService {

  /// 제목+설명이 이 글자 수 이하면 AI 를 부르지 않고 이미 짧은 카드로 봄
  static final int ALREADY_SHORT_MAX_LENGTH = 12;

  private final CardSplitStepWriter cardSplitStepWriter;
  private final EntitlementService entitlementService;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;
  private final CardSplitAi cardSplitAi;
  private final PictogramPicker pictogramPicker;

  /// 안 받기 (저장 없음). AI 실패·검증 어긋남은 502 CARD_SPLIT_FAILED
  public CardSplitSuggestionResponse suggest(Caller caller, String routineId, String stepId) {
    CardSplitStepWriter.SplitSource source = cardSplitStepWriter.readSource(caller, routineId, stepId);
    entitlementService.requireAllowed(caller.memberId(), Entitlement.CARD_SPLIT);

    // 이미 아주 짧은 카드 (AI 호출 없음)
    if (source.title().trim().length() + source.description().trim().length() <= ALREADY_SHORT_MAX_LENGTH) {
      log.info("[card split] already short : decided before ai");
      return CardSplitSuggestionResponse.alreadyShort();
    }

    aiDailyBudgetGuard.guard();

    CardSplitAi.RawSuggestion raw = requestSuggestion(caller.memberId(), source);
    CardSplitValidator.SuggestionResult validation = CardSplitValidator.validateSuggestion(raw);
    if (!validation.isAccepted()) {
      log.warn("[card split] rejected 502 : reason={}", validation.rejectionReason());
      throw new CustomException(ErrorCode.CARD_SPLIT_FAILED);
    }
    return restoreNickname(validation.suggestion(), source);
  }

  /// 고른 안 적용: 권한 > Pro 확인 > 입력 검증 > 새 카드 픽토그램 고르기(트랜잭션 밖) > 한 트랜잭션으로 교체
  public RoutineResponse apply(Caller caller, String routineId, String stepId, CardSplitRequest request) {
    CardSplitStepWriter.SplitSource source = cardSplitStepWriter.readSource(caller, routineId, stepId);
    entitlementService.requireAllowed(caller.memberId(), Entitlement.CARD_SPLIT);
    List<CardSplitRequest.Card> cards = request == null ? null : request.cards();
    if (!CardSplitValidator.isApplicable(cards)) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    List<String> pictogramIds = pickPictogramIds(caller.memberId(), source, cards);
    return cardSplitStepWriter.replaceStep(caller, routineId, stepId, cards, pictogramIds);
  }

  // AI 호출: 회원·일과 언어를 세우고 호출 뒤 되돌림. 이름은 자리표시로 가려 보냄 (실패는 모두 CARD_SPLIT_FAILED)
  private CardSplitAi.RawSuggestion requestSuggestion(String memberId, CardSplitStepWriter.SplitSource source) {
    String maskedTitle = NicknamePlaceholder.mask(source.title().trim(), source.nickname(), source.language());
    String maskedDescription = NicknamePlaceholder.mask(source.description().trim(), source.nickname(), source.language());
    String previousMemberId = AiCallContext.currentMemberId();
    AiCallContext.setMemberId(memberId);
    try {
      return AiCallContext.callWithContentLocale(source.language(),
        () -> cardSplitAi.requestSuggestion(maskedTitle, maskedDescription));
    } catch (RuntimeException e) {
      log.warn("[card split] ai failed 502 : error={}", e.getClass().getSimpleName());
      throw new CustomException(ErrorCode.CARD_SPLIT_FAILED);
    } finally {
      AiCallContext.setMemberId(previousMemberId);
    }
  }

  // AI 응답의 자리표시 > 실제 이름
  private static CardSplitSuggestionResponse restoreNickname(
    CardSplitSuggestionResponse suggestion, CardSplitStepWriter.SplitSource source
  ) {
    if (suggestion.status() == CardSplitSuggestionResponse.Status.ALREADY_SHORT) {
      return suggestion;
    }
    return CardSplitSuggestionResponse.suggested(suggestion.cards().stream()
      .map(card -> new CardSplitSuggestionResponse.Card(
        NicknamePlaceholder.restore(card.title(), source.nickname(), source.language()),
        NicknamePlaceholder.restore(card.description(), source.nickname(), source.language())))
      .toList());
  }

  // 카드 직접 더하기와 같은 기본 그림: 새 카드마다 무료 픽토그램 (던지지 않음, 실패는 폴백 id)
  private List<String> pickPictogramIds(
    String memberId, CardSplitStepWriter.SplitSource source, List<CardSplitRequest.Card> cards
  ) {
    List<String> pictogramIds = new ArrayList<>();
    for (CardSplitRequest.Card card : cards) {
      String maskedTitle = NicknamePlaceholder.mask(card.title().trim(), source.nickname(), source.language());
      String maskedDescription = NicknamePlaceholder.mask(
        card.description() == null ? "" : card.description().trim(), source.nickname(), source.language());
      pictogramIds.add(AiCallContext.callWithContentLocale(source.language(),
        () -> pictogramPicker.pick(memberId, maskedTitle, maskedDescription, source.pictogramSet())));
    }
    return pictogramIds;
  }
}
