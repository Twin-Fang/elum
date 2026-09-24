package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.license.core.PlanType;
import java.util.Map;

/**
 * 새로 발행할 크레딧 정책 (#407). 관리자 정책 화면의 폼 값이다.
 *
 * @param grantApply NEXT_PERIOD | IMMEDIATE ({@code AiCreditPolicy.GRANT_APPLY_*})
 * @param reason     필수 — 나중에 "왜 이 숫자였지"에 답하려면 있어야 한다
 */
public record PolicyDraft(
  boolean enabled,
  Map<PlanType, Integer> weeklyGrant,
  Map<CreditAction, Integer> actionCosts,
  int reservationTtlMinutes,
  String grantApply,
  String reason
) {

}
