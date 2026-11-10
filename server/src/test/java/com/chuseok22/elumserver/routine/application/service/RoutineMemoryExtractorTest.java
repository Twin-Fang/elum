package com.chuseok22.elumserver.routine.application.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineMemoryAi;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 수정 찾기 한 건: 깨지면 꺼짐·Pro 아님·비용 상한에서도 AI 가 불리거나, AI 실패가 사용자 동작으로 번지거나, 같은 일과를 다시 시도한다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryExtractorTest {

  @Mock private RoutineMemoryExtractionStore store;
  @Mock private RoutineMemoryAi ai;
  @Mock private AiDailyBudgetGuard aiDailyBudgetGuard;
  @InjectMocks private RoutineMemoryExtractor extractor;

  private static RoutineMemoryExtractionStore.ExtractionJob job() {
    return new RoutineMemoryExtractionStore.ExtractionJob("r1", "아침", "p1", "member-a", AppLocale.KO, List.of(),
      List.of(), RoutineMemoryAi.ExtractionInput.of(List.of(), List.of(), List.of(), List.of()));
  }

  @Test
  @DisplayName("하루 AI 비용 상한이면 선점도 AI 호출도 하지 않는다 (놓친 것 줍기가 나중에 다시 본다)")
  void budgetReached_skipsEverything() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(true);

    extractor.extract("r1");

    verify(store, never()).claim(anyString());
    verify(ai, never()).extract(any());
  }

  @Test
  @DisplayName("선점하지 못했거나 대상이 아니면(꺼짐·Pro 아님·고친 것 없음) AI 를 부르지 않는다")
  void notClaimed_doesNotCallAi() {
    when(store.claim("r1")).thenReturn(Optional.empty());

    extractor.extract("r1");

    verify(ai, never()).extract(any());
    verify(store, never()).apply(any(), any());
  }

  @Test
  @DisplayName("선점하면 AI 결과를 반영한다")
  void claimed_callsAiAndApplies() {
    RoutineMemoryAi.ExtractionResult result = new RoutineMemoryAi.ExtractionResult(List.of(), List.of());
    when(store.claim("r1")).thenReturn(Optional.of(job()));
    when(ai.extract(any())).thenReturn(result);

    extractor.extract("r1");

    verify(store).apply(any(RoutineMemoryExtractionStore.ExtractionJob.class),
      org.mockito.ArgumentMatchers.eq(result));
  }

  @Test
  @DisplayName("AI 가 실패해도 던지지 않고 FAILED 로 표시한다 — 확정 흐름이 막히거나 같은 일과를 다시 AI 로 보낸다")
  void aiFailure_marksFailedWithoutThrowing() {
    when(store.claim("r1")).thenReturn(Optional.of(job()));
    when(ai.extract(any())).thenThrow(new IllegalStateException("ai down"));

    extractor.extract("r1");

    verify(store).markFailed("r1");
    verify(store, never()).apply(any(), any());
  }

  @Test
  @DisplayName("선점 중 예외가 나도 던지지 않는다")
  void claimFailure_doesNotThrow() {
    when(store.claim("r1")).thenThrow(new IllegalStateException("db down"));

    extractor.extract("r1");

    verify(ai, never()).extract(any());
  }
}
