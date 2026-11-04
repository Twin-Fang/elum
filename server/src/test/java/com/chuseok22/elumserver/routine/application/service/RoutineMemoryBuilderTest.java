package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineMemoryAi;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * AI 메모 갱신 주기 (#1082). 깨지면 AI 실패 한 번이 예약 작업 전체를 멈추거나 매 주기 같은 호출을 되풀이한다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryBuilderTest {

  @Mock private RoutineMemoryBuildStore routineMemoryBuildStore;
  @Mock private RoutineMemoryAi routineMemoryAi;
  @Mock private AiDailyBudgetGuard aiDailyBudgetGuard;
  @InjectMocks private RoutineMemoryBuilder builder;

  private RoutineMemoryBuildStore.BuildJob job(String profileId) {
    return new RoutineMemoryBuildStore.BuildJob(profileId, List.of("r-" + profileId),
      RoutineMemoryAi.MemoryInput.of(List.of(), List.of(), List.of(), List.of(), 10), "member-1", AppLocale.KO, "하늘이");
  }

  @Test
  @DisplayName("AI 가 실패한 이룸이는 실패 기록(하루 뒤 재시도)만 남기고 다음 이룸이는 계속 갱신, 맥락은 비운다")
  void aiFailure_isIsolatedPerProfile() {
    when(routineMemoryBuildStore.findPendingProfileIds()).thenReturn(List.of("p1", "p2"));
    when(routineMemoryBuildStore.prepare("p1")).thenReturn(job("p1"));
    when(routineMemoryBuildStore.prepare("p2")).thenReturn(job("p2"));
    when(routineMemoryAi.buildLines(any()))
      .thenThrow(new IllegalStateException("529"))
      .thenReturn(List.of("카드를 잘게 나눠요"));

    RoutineMemoryBuilder.RunResult result = builder.runOnce();

    assertThat(result.failed()).isEqualTo(1);
    assertThat(result.built()).isEqualTo(1);
    verify(routineMemoryBuildStore).recordFailure("p1");
    verify(routineMemoryBuildStore, never()).recordFailure("p2");
    assertThat(AiCallContext.currentMemberId()).isNull();
  }

  @Test
  @DisplayName("하루 AI 비용 상한에 닿으면 이번 주기는 AI 를 부르지 않는다 (일과 만들기가 우선)")
  void budgetReached_stopsRun() {
    when(routineMemoryBuildStore.findPendingProfileIds()).thenReturn(List.of("p1"));
    when(aiDailyBudgetGuard.isReached()).thenReturn(true);

    builder.runOnce();

    verify(routineMemoryBuildStore, never()).prepare(any());
    verify(routineMemoryAi, never()).buildLines(any());
  }
}
