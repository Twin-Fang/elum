package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.credit.application.service.PolicyDraft;

/**
 * 크레딧 정책 발행 영향 미리보기 (#407). 지난 4주 실제 사용으로 추정한다.
 *
 * @param exhaustedBefore 지난 4주 주별 수요(사용+초과)가 지금 지급량 이상이었던 계정 수의 주 평균
 * @param exhaustedAfter  같은 수요를 새 지급량에 댄 추정
 * @param usdPerCredit    지난 4주 실제 USD ÷ 사용 크레딧. 사용이 0 이면 null
 * @param immediateAccounts IMMEDIATE 면 이번 주 지급을 바로 고칠 계정 수
 * @param immediateDelta    그 계정들 이번 주 지급 총량 변화(차감은 남은 양까지만이라 실제 반영은 이보다 작을 수 있다)
 * @param disabling       켜진 정책을 끈다 — 기존 횟수 한도(아래 두 값)가 다시 적용된다
 */
public record CreditPolicyPreview(
  PolicyDraft draft,
  long targetAccounts,
  long freeAccounts,
  long proAccounts,
  long weeklyTotalBefore,
  long weeklyTotalAfter,
  double exhaustedBefore,
  double exhaustedAfter,
  Double usdPerCredit,
  Double estimatedWeeklyUsdBefore,
  Double estimatedWeeklyUsdAfter,
  boolean immediate,
  long immediateAccounts,
  long immediateDelta,
  boolean disabling,
  int freeRoutinePerDay,
  int freeRoutinePerWeek
) {

  public long weeklyTotalChange() {
    return weeklyTotalAfter - weeklyTotalBefore;
  }
}
