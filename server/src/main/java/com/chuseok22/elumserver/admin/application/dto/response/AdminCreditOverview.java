package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import java.util.List;

/**
 * 관리자 크레딧 개요 한 주 (#407).
 *
 * @param nextKey       다음 주 키. 이번 주를 보고 있으면 null(미래는 없다)
 * @param current       고른 주가 이번 주인가 — 예약·남음이 "지금" 값이다
 * @param costPerCredit 그 주 실제 USD ÷ 사용 크레딧. 사용이 0 이면 null(화면은 "—")
 * @param stuckCount    멈춘 예약 수(주와 무관, 지금 기준)
 * @param mismatchCount 그 주에 정산한 작업 중 연결 호출이 없는 것
 */
public record AdminCreditOverview(
  CreditPeriod period,
  String prevKey,
  String nextKey,
  boolean current,
  long activeAccounts,
  long granted,
  long bonusGranted,
  long used,
  long reserved,
  long remaining,
  long overageJobs,
  long overageCredits,
  long releasedJobs,
  long exhaustedAccounts,
  double totalUsd,
  Double costPerCredit,
  List<ModelCost> modelCosts,
  List<KindCost> kindCosts,
  long stuckCount,
  long mismatchCount,
  boolean budgetReached,
  AiCreditPolicy policy
) {

  public boolean hasWarning() {
    return stuckCount > 0 || mismatchCount > 0 || !policy.isEnabled() || budgetReached;
  }

  public record ModelCost(String model, long calls, double usd) {

  }

  /// 행동(작업 종류)별 작업당 평균. 작업이 0 이면 줄을 만들지 않는다.
  public record KindCost(CreditJobKind kind, long jobs, long calls, double usd) {

    public double avgUsd() {
      return jobs == 0 ? 0 : usd / jobs;
    }

    public double avgCalls() {
      return jobs == 0 ? 0 : (double) calls / jobs;
    }
  }
}
