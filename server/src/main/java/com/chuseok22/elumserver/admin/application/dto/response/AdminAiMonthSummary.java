package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/**
 * AI 모니터링 이번 달 요약: 호출·실패율·비용(USD, 원), 일과 1건 평균 비용(원), 제공자별 비용 비율
 * averageCostKrwPerRoutine: 성공한 일과 생성이 없으면 null
 */
public record AdminAiMonthSummary(
  long callCount,
  double failurePercent,
  double costUsd,
  long costKrw,
  Long averageCostKrwPerRoutine,
  List<ProviderCost> providerCosts
) {

  /** 제공자 비용이 이번 달 전체에서 차지하는 비율(%) — 막대 폭·괄호 숫자용, 전체 0 이면 0 */
  public int costPercentOf(ProviderCost providerCost) {
    return costUsd <= 0 ? 0 : (int) Math.round(providerCost.costUsd() * 100 / costUsd);
  }

  /** 제공자 줄 > 비용 (USD 큰 순) */
  public record ProviderCost(String laneLabel, double costUsd) {
  }
}
