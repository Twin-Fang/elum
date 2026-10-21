package com.chuseok22.elumserver.ai.application.dto.response;

/** 크레딧 작업 1건에 연결된 호출 요약: 호출 수, 성공 수, 추정 비용 합 (USD) */
public record AiCreditJobCallSummary(String creditJobId, long callCount, long successCount, double totalCostUsd) {

  public long failureCount() {
    return callCount - successCount;
  }
}
