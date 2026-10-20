package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.application.service.AiCallStatsService.JudgeInput;
import com.chuseok22.elumserver.ai.core.AiProviderHealth;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 제공자 상태 판정 (최신순 입력, 창 = 최근 60분)
 * 깨지면 크레딧이 바닥났는데 대시보드는 "정상"이나 "호출 없음"으로 보인다
 */
class AiCallStatsServiceHealthTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 20, 12, 0);
  private static final LocalDateTime WINDOW_START = NOW.minusMinutes(60);
  private static final String NO_CREDITS = "429 Too Many Requests: You have no credits remaining";

  private static JudgeInput success(int minutesAgo) {
    return new JudgeInput(true, null, NOW.minusMinutes(minutesAgo));
  }

  private static JudgeInput failure(int minutesAgo, String message) {
    return new JudgeInput(false, message, NOW.minusMinutes(minutesAgo));
  }

  @Test
  @DisplayName("가장 최근 호출이 크레딧 오류면 창 밖(3시간 전)이어도 크레딧 소진 의심")
  void creditFailureOutsideWindowStillAlerts() {
    List<JudgeInput> outcomes = List.of(failure(180, NO_CREDITS), success(300));

    assertThat(AiCallStatsService.judgeHealth(outcomes, WINDOW_START)).isEqualTo(AiProviderHealth.CREDIT_EXHAUSTED);
  }

  @Test
  @DisplayName("크레딧 오류 뒤에 성공이 있으면 소진으로 보지 않는다 (충전됨)")
  void successAfterCreditFailureClearsIt() {
    List<JudgeInput> outcomes = List.of(success(5), failure(30, NO_CREDITS));

    assertThat(AiCallStatsService.judgeHealth(outcomes, WINDOW_START)).isEqualTo(AiProviderHealth.HEALTHY);
  }

  @Test
  @DisplayName("창 안 3건 이상 중 절반 이상 실패면 오류 늘어남, 2건뿐이면 판단하지 않는다")
  void degradedNeedsEnoughCalls() {
    String rateLimit = "429 Rate limit reached";
    assertThat(AiCallStatsService.judgeHealth(
      List.of(failure(1, rateLimit), failure(2, rateLimit), success(3)), WINDOW_START))
      .isEqualTo(AiProviderHealth.DEGRADED);
    assertThat(AiCallStatsService.judgeHealth(
      List.of(failure(1, rateLimit), success(3)), WINDOW_START))
      .isEqualTo(AiProviderHealth.HEALTHY);
  }

  @Test
  @DisplayName("창 안에 호출이 없으면 호출 없음 (정상으로 단정하지 않음)")
  void noCallsInWindowIsIdle() {
    assertThat(AiCallStatsService.judgeHealth(List.of(success(120)), WINDOW_START)).isEqualTo(AiProviderHealth.IDLE);
    assertThat(AiCallStatsService.judgeHealth(List.of(), WINDOW_START)).isEqualTo(AiProviderHealth.IDLE);
  }
}
