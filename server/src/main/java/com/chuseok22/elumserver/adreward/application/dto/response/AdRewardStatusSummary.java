package com.chuseok22.elumserver.adreward.application.dto.response;

/**
 * 기간 안에 만든 세션의 보이는 상태별 건수 + 지급 크레딧 합
 * expired 는 늦은 콜백(EXPIRED)과 콜백 없이 지난 PENDING 을 합친 값, pending 은 아직 유효한 것만
 */
public record AdRewardStatusSummary(long granted, long rejected, long pending, long expired, long grantedCredits) {

  public long total() {
    return granted + rejected + pending + expired;
  }
}
