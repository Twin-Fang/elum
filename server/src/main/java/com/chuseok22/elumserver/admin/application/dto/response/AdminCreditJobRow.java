package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;

/**
 * 크레딧 작업 한 줄과 연결된 AI 호출 대조 (#407).
 *
 * @param callCount 이 작업에 연결된 ai_call_log 건수
 * @param costUsd   연결된 호출의 추정 비용 합
 * @param stuck     예약 유지 시간이 지났는데 아직 RESERVED — 서버가 작업 도중 멈췄을 수 있다
 */
public record AdminCreditJobRow(
  AiCreditJob job,
  String memberId,
  String username,
  long callCount,
  double costUsd,
  boolean stuck
) {

  /// 청구(차감·초과)가 있었는데 연결된 호출 기록이 없다 — 호출 기록이 빠졌거나 작업 id 를 못 실었다.
  public boolean mismatch() {
    return job.getStatus() == CreditJobStatus.SETTLED && (job.getCharged() + job.getOverage()) > 0 && callCount == 0;
  }

  public boolean releasable() {
    return job.getStatus() == CreditJobStatus.RESERVED;
  }
}
