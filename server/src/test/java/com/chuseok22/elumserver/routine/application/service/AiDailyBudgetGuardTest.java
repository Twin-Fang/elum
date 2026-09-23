package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.AiCallStats;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 서비스 전체 하루 AI 비용 상한 (#368).
 *
 * <p>실제 AI 를 부르지 않는다. 기록 표의 오늘 합계만 흉내 낸다.
 */
@ExtendWith(MockitoExtension.class)
class AiDailyBudgetGuardTest {

  /// 2026-09-23 00:30 한국 시각 = 전날 15:30 UTC. 하루 경계를 UTC 로 잡으면 여기서 어긋난다.
  private static final Clock JUST_AFTER_MIDNIGHT_KST =
    Clock.fixed(Instant.parse("2026-09-22T15:30:00Z"), ZoneId.of("Asia/Seoul"));

  @Mock
  private AiCallLogRepository aiCallLogRepository;

  @Mock
  private SystemConfigService systemConfigService;

  private AiDailyBudgetGuard guard;

  /// 가드가 합계를 물은 시작 시각.
  private final AtomicReference<LocalDateTime> askedFrom = new AtomicReference<>();

  @BeforeEach
  void setUp() {
    guard = new AiDailyBudgetGuard(aiCallLogRepository, systemConfigService, JUST_AFTER_MIDNIGHT_KST);
  }

  private void budget(double usd) {
    when(systemConfigService.getDouble(ConfigKey.AI_DAILY_BUDGET_USD)).thenReturn(usd);
  }

  private void spentToday(double usd) {
    lenient().when(aiCallLogRepository.statsSince(any(LocalDateTime.class))).thenAnswer(invocation -> {
      askedFrom.set(invocation.getArgument(0));
      return stats(usd);
    });
  }

  /// 기간 합계 쿼리의 결과 한 줄. 가드는 비용만 읽지만 나머지 칸도 실제처럼 채운다.
  private static AiCallStats stats(double totalCostUsd) {
    return new AiCallStats() {
      @Override public long getTotalCount() { return 100; }
      @Override public long getSuccessCount() { return 98; }
      @Override public double getAvgLatencyMs() { return 4200; }
      @Override public long getTotalTokens() { return 120_000; }
      @Override public double getTotalCostUsd() { return totalCostUsd; }
    };
  }

  private void assertRejectsNewRoutine() {
    assertThatThrownBy(() -> guard.guard())
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.AI_DAILY_BUDGET_EXCEEDED));
  }

  @Test
  @DisplayName("꺼져 있으면(-1) 얼마를 썼든 통과한다 — 기본값이라 배포만으로 동작이 바뀌지 않는다")
  void off_alwaysPasses() {
    budget(-1);
    spentToday(500);

    assertThat(guard.isReached()).isFalse();
    assertThatCode(() -> guard.guard()).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("오늘 쓴 비용이 상한 아래면 통과한다")
  void belowBudget_passes() {
    budget(10);
    spentToday(9.99);

    assertThat(guard.isReached()).isFalse();
    assertThatCode(() -> guard.guard()).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("상한에 닿으면 새 일과를 거절한다 — 계정 한도와 다른 코드로")
  void reachedBudget_rejects() {
    budget(10);
    spentToday(10);

    assertThat(guard.isReached()).isTrue();
    assertRejectsNewRoutine();
  }

  @Test
  @DisplayName("0 이면 오늘 새 일과 만들기를 바로 멈춘다 — 급할 때 끄는 스위치")
  void zeroBudget_stopsEverything() {
    budget(0);
    spentToday(0);

    assertRejectsNewRoutine();
  }

  @Test
  @DisplayName("오늘 한국 시각 0시부터 센다")
  void countsFromTodayMidnightKst() {
    budget(10);
    spentToday(1);

    guard.isReached();

    assertThat(askedFrom.get()).isEqualTo(LocalDateTime.of(2026, 9, 23, 0, 0));
  }

  @Test
  @DisplayName("집계가 실패하면 통과시킨다 — DB 문제 하나로 모든 보호자가 막히면 안 된다")
  void queryFails_passes() {
    budget(10);
    when(aiCallLogRepository.statsSince(any(LocalDateTime.class)))
      .thenThrow(new RuntimeException("DB 장애"));

    assertThat(guard.isReached()).isFalse();
    assertThatCode(() -> guard.guard()).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("-1 이 아닌 음수나 숫자가 아닌 값은 끈 것으로 본다 — 잘못 넣은 값으로 전부 멈추지 않는다")
  void invalidBudget_treatedAsOff() {
    spentToday(500);

    budget(-5);
    assertThat(guard.isReached()).isFalse();

    budget(Double.NaN);
    assertThat(guard.isReached()).isFalse();
  }
}
