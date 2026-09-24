package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.credit.application.service.CreditBalance;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.license.core.PlanType;
import java.util.List;
import org.springframework.data.domain.Page;

/**
 * 관리자 크레딧 회원 상세 (#407).
 *
 * @param account 크레딧 계정. 아직 없으면 null — 첫 요청이나 관리자 지급 때 만들어진다
 * @param balance 지금 잔액(읽기만 — 이번 주 지급·멈춘 예약 정리는 하지 않는다). 계정이 없으면 null
 * @param grants  지금 쓸 수 있는 묶음, 차감 순서대로
 * @param ledgerType 원장 종류 필터. null 이면 전체
 */
public record AdminCreditMemberDetail(
  String memberId,
  String username,
  String nickname,
  PlanType plan,
  AiCreditAccount account,
  CreditBalance balance,
  List<AiCreditGrant> grants,
  Page<AdminCreditJobRow> jobs,
  Page<AiCreditLedger> ledger,
  CreditLedgerType ledgerType,
  AiCreditPolicy policy
) {

  public boolean frozen() {
    return account != null && account.isFrozen();
  }

  public int available() {
    return balance == null ? 0 : balance.available();
  }
}
