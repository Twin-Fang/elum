package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;

/// 관리자 크레딧 쓰기가 남기는 원장 한 줄 조립: 조정, 수동 반환, 정책 즉시 적용 공통
final class AdminCreditLedgerLine {

  private AdminCreditLedgerLine() {
  }

  static AiCreditLedger of(
    String accountId, CreditLedgerType type, int delta, int balanceAfter, String actor, String reason
  ) {
    AiCreditLedger line = new AiCreditLedger();
    line.setAccountId(accountId);
    line.setType(type);
    line.setDelta(delta);
    line.setBalanceAfter(Math.max(0, balanceAfter));
    line.setActor(actor == null || actor.isBlank() ? "admin" : actor);
    line.setReason(reason != null && reason.length() > 500 ? reason.substring(0, 500) : reason);
    return line;
  }
}
