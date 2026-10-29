package com.chuseok22.elumserver.common.application.alert;

import java.time.Duration;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 장애 알림 종류 3개: 5xx 급증, AI 하루 비용 상한 도달, AI 제공자 연속 실패 (#648)
 * fixedCooldown: 종류 고유 재발송 간격 (null 이면 설정 쿨다운)
 */
@Getter
@AllArgsConstructor
public enum IncidentAlertType {

  SERVER_ERROR_SURGE("5xx 급증", null),
  // 상한은 자정까지 풀리지 않음 > 날짜별 1회
  AI_DAILY_BUDGET_REACHED("AI 하루 비용 상한 도달", Duration.ofHours(24)),
  AI_PROVIDER_CONSECUTIVE_FAILURE("AI 제공자 연속 실패", null),
  ;

  private final String label;
  private final Duration fixedCooldown;

  /** 이 종류의 재발송 간격 (고유값 없으면 설정값) */
  public Duration cooldownOr(Duration configuredCooldown) {
    return fixedCooldown == null ? configuredCooldown : fixedCooldown;
  }
}
