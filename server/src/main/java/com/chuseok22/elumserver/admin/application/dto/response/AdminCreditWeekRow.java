package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.license.core.PlanType;
import java.time.LocalDateTime;

/**
 * 크레딧 계정 한 개의 한 주 요약 (#407 관리자 회원별 표 · 개요 합계의 재료).
 *
 * @param weeklyGrant 그 주 주간 지급량. 그 주에 지급받지 않았으면 null
 * @param bonus       그 주에 시작한 주간 외 지급(관리자 보너스 등) 합
 * @param used        그 주 실제 차감(CONSUME) 합
 * @param reserved    진행 중 예약 합 — 이번 주만 뜻이 있다(지난 주는 0)
 * @param remaining   이번 주: 지금 사용 가능량. 지난 주: 주간 지급이 주 말에 남긴 양(남음 + 만료)
 * @param lastUsedAt  마지막 실제 차감 시각(주와 무관)
 */
public record AdminCreditWeekRow(
  String accountId,
  String memberId,
  String username,
  String nickname,
  PlanType plan,
  boolean frozen,
  Integer weeklyGrant,
  long bonus,
  long used,
  long reserved,
  long remaining,
  long overage,
  long overageJobs,
  LocalDateTime lastUsedAt
) {

  /// 그 주 지급을 받았는데 남은 것이 없다.
  public boolean exhausted() {
    return weeklyGrant != null && remaining <= 0;
  }

  public AdminCreditWeekRow withMember(String username, String nickname, PlanType plan) {
    return new AdminCreditWeekRow(accountId, memberId, username, nickname, plan, frozen, weeklyGrant, bonus, used,
      reserved, remaining, overage, overageJobs, lastUsedAt);
  }
}
