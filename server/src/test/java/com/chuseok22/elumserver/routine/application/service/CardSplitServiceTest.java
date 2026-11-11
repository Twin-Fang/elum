package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.PictogramSet;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.CardSplitRequest;
import com.chuseok22.elumserver.routine.application.dto.response.CardSplitSuggestionResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.CardSplitAi;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 이 카드 더 쉽게: Pro 확인·짧은 카드 거름·비용 상한이 AI 호출을 막는가, AI 안이 검증을 거쳐 나가는가
@ExtendWith(MockitoExtension.class)
class CardSplitServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final String LONG_TITLE = "아침에 일어나서 양치하고 세수해요";
  private static final CardSplitStepWriter.SplitSource LONG_SOURCE = new CardSplitStepWriter.SplitSource(
    LONG_TITLE, "일어나서 양치도 하고 세수도 해요.", "하늘", AppLocale.KO, PictogramSet.MULBERRY);

  @Mock private CardSplitStepWriter cardSplitStepWriter;
  @Mock private EntitlementService entitlementService;
  @Mock private AiDailyBudgetGuard aiDailyBudgetGuard;
  @Mock private CardSplitAi cardSplitAi;
  @Mock private PictogramPicker pictogramPicker;
  @InjectMocks private CardSplitService cardSplitService;

  private static CardSplitAi.RawSuggestion twoCards() {
    return new CardSplitAi.RawSuggestion("SUGGESTED", List.of(
      new CardSplitAi.RawCard("양치해요", "이룸이가 이를 닦아요."), new CardSplitAi.RawCard("세수해요", "물로 얼굴을 씻어요.")));
  }

  @Test
  @DisplayName("Pro 아니면 403 CARD_SPLIT_PRO_REQUIRED 이고 AI·쿨다운·비용 상한을 건드리지 않는다")
  void suggest_rejectsFreeBeforeAnyCost() {
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(LONG_SOURCE);
    doThrow(new CustomException(ErrorCode.CARD_SPLIT_PRO_REQUIRED))
      .when(entitlementService).requireAllowed("member-1", Entitlement.CARD_SPLIT);

    assertThatThrownBy(() -> cardSplitService.suggest(GUARDIAN, "r1", "s1"))
      .extracting("errorCode").isEqualTo(ErrorCode.CARD_SPLIT_PRO_REQUIRED);
    verifyNoInteractions(cardSplitAi, aiDailyBudgetGuard);
  }

  @Test
  @DisplayName("아주 짧은 카드는 AI 를 부르지 않고 ALREADY_SHORT — 비용·쿨다운을 쓰지 않는다")
  void suggest_shortCardIsAnsweredWithoutAi() {
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(new CardSplitStepWriter.SplitSource(
      "손 씻기", "비누로 씻어요.", "하늘", AppLocale.KO, PictogramSet.MULBERRY));

    CardSplitSuggestionResponse response = cardSplitService.suggest(GUARDIAN, "r1", "s1");

    assertThat(response.status()).isEqualTo(CardSplitSuggestionResponse.Status.ALREADY_SHORT);
    assertThat(response.cards()).isEmpty();
    verifyNoInteractions(cardSplitAi, aiDailyBudgetGuard);
  }

  @Test
  @DisplayName("AI 에는 이름을 자리표시로 가려 보내고, 응답의 자리표시는 실제 이름으로 되돌린다")
  void suggest_masksNameToAiAndRestoresInResponse() {
    CardSplitStepWriter.SplitSource source = new CardSplitStepWriter.SplitSource(
      "하늘이 양치하고 세수해요", "하늘이 일어나서 양치도 하고 세수도 해요.", "하늘", AppLocale.KO, PictogramSet.MULBERRY);
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(source);
    when(cardSplitAi.requestSuggestion(anyString(), anyString())).thenReturn(twoCards());

    CardSplitSuggestionResponse response = cardSplitService.suggest(GUARDIAN, "r1", "s1");

    verify(cardSplitAi).requestSuggestion(eq("이룸이 양치하고 세수해요"), eq("이룸이 일어나서 양치도 하고 세수도 해요."));
    verify(aiDailyBudgetGuard).guard();
    assertThat(response.status()).isEqualTo(CardSplitSuggestionResponse.Status.SUGGESTED);
    assertThat(response.cards()).hasSize(2);
    assertThat(response.cards().get(0).description()).isEqualTo("하늘이 이를 닦아요.");
  }

  @Test
  @DisplayName("하루 비용 상한에 닿으면 AI 를 부르기 전에 거절한다")
  void suggest_budgetReachedStopsBeforeAi() {
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(LONG_SOURCE);
    doThrow(new CustomException(ErrorCode.AI_DAILY_BUDGET_EXCEEDED)).when(aiDailyBudgetGuard).guard();

    assertThatThrownBy(() -> cardSplitService.suggest(GUARDIAN, "r1", "s1"))
      .extracting("errorCode").isEqualTo(ErrorCode.AI_DAILY_BUDGET_EXCEEDED);
    verifyNoInteractions(cardSplitAi);
  }

  @Test
  @DisplayName("AI 호출이 실패하면 502 CARD_SPLIT_FAILED — 원인 예외가 그대로 새지 않는다")
  void suggest_aiFailureBecomesCardSplitFailed() {
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(LONG_SOURCE);
    when(cardSplitAi.requestSuggestion(anyString(), anyString())).thenThrow(new IllegalStateException("timeout"));

    assertThatThrownBy(() -> cardSplitService.suggest(GUARDIAN, "r1", "s1"))
      .isInstanceOf(CustomException.class).extracting("errorCode").isEqualTo(ErrorCode.CARD_SPLIT_FAILED);
  }

  @Test
  @DisplayName("규칙에 어긋난 안(진단 낱말)은 502 CARD_SPLIT_FAILED 로 막고 앱에 내보내지 않는다")
  void suggest_invalidSuggestionBecomesCardSplitFailed() {
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(LONG_SOURCE);
    when(cardSplitAi.requestSuggestion(anyString(), anyString())).thenReturn(new CardSplitAi.RawSuggestion(
      "SUGGESTED", List.of(new CardSplitAi.RawCard("양치", "자폐가 있어도 해요."), new CardSplitAi.RawCard("세수", "씻어요."))));

    assertThatThrownBy(() -> cardSplitService.suggest(GUARDIAN, "r1", "s1"))
      .extracting("errorCode").isEqualTo(ErrorCode.CARD_SPLIT_FAILED);
  }

  @Test
  @DisplayName("AI 가 ALREADY_SHORT 라 하면 빈 목록으로 돌려준다")
  void suggest_aiSaysAlreadyShort() {
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(LONG_SOURCE);
    when(cardSplitAi.requestSuggestion(anyString(), anyString()))
      .thenReturn(new CardSplitAi.RawSuggestion("ALREADY_SHORT", List.of()));

    CardSplitSuggestionResponse response = cardSplitService.suggest(GUARDIAN, "r1", "s1");

    assertThat(response.status()).isEqualTo(CardSplitSuggestionResponse.Status.ALREADY_SHORT);
    assertThat(response.cards()).isEmpty();
  }

  @Test
  @DisplayName("적용 요청이 2~3장이 아니면 400 INVALID_INPUT_VALUE 이고 카드를 바꾸지 않는다")
  void apply_invalidInputIsRejectedBeforeWrite() {
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(LONG_SOURCE);

    assertThatThrownBy(() -> cardSplitService.apply(GUARDIAN, "r1", "s1",
      new CardSplitRequest(List.of(new CardSplitRequest.Card("하나뿐", "")))))
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_INPUT_VALUE);
    verify(cardSplitStepWriter, never()).replaceStep(any(), anyString(), anyString(), anyList(), anyList());
  }

  @Test
  @DisplayName("Pro 아니면 적용도 403 이다 — 안 받기만 막고 적용을 열어 두면 안 된다")
  void apply_rejectsFree() {
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(LONG_SOURCE);
    doThrow(new CustomException(ErrorCode.CARD_SPLIT_PRO_REQUIRED))
      .when(entitlementService).requireAllowed("member-1", Entitlement.CARD_SPLIT);

    assertThatThrownBy(() -> cardSplitService.apply(GUARDIAN, "r1", "s1", new CardSplitRequest(List.of())))
      .extracting("errorCode").isEqualTo(ErrorCode.CARD_SPLIT_PRO_REQUIRED);
    verify(cardSplitStepWriter, never()).replaceStep(any(), anyString(), anyString(), anyList(), anyList());
  }

  @Test
  @DisplayName("적용은 새 카드마다 픽토그램을 골라 교체에 넘긴다 — AI 그림·크레딧은 쓰지 않는다")
  void apply_picksPictogramPerCardAndReplaces() {
    when(cardSplitStepWriter.readSource(GUARDIAN, "r1", "s1")).thenReturn(LONG_SOURCE);
    when(pictogramPicker.pick(eq("member-1"), eq("양치해요"), anyString(), eq(PictogramSet.MULBERRY))).thenReturn("brush");
    when(pictogramPicker.pick(eq("member-1"), eq("세수해요"), anyString(), eq(PictogramSet.MULBERRY))).thenReturn("wash");
    List<CardSplitRequest.Card> cards = List.of(
      new CardSplitRequest.Card("양치해요", "이를 닦아요."), new CardSplitRequest.Card("세수해요", "얼굴을 씻어요."));

    cardSplitService.apply(GUARDIAN, "r1", "s1", new CardSplitRequest(cards));

    verify(cardSplitStepWriter).replaceStep(GUARDIAN, "r1", "s1", cards, List.of("brush", "wash"));
  }
}
