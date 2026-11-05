package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 정산 원장 줄 쓰기: 예약 풀기 > 일과 글 무료 0 줄 > 묶음별 차감 > 무료 다시 그리기 0 줄 > 초과 줄
 * 계정 행 잠금 안에서 CreditReservationService.settle 이 부름 (작업 상태 갱신은 settle)
 */
class CreditSettlementLedger {

  private final CreditAccountService accountService;
  private final AiCreditLedgerRepository ledgerRepository;

  CreditSettlementLedger(CreditAccountService accountService, AiCreditLedgerRepository ledgerRepository) {
    this.accountService = accountService;
    this.ledgerRepository = ledgerRepository;
  }

  /// 정산 결과: 실제 차감, 차감 못 한 초과, 정산 뒤 사용 가능 잔액(음수 가능, 응답은 0 에서 멈춤)
  record SettledAmounts(int deducted, int overage, int balanceAfter) {
  }

  SettledAmounts writeLines(
    String accountId, AiCreditAccount account, String jobId, AiCreditJob job, int imageCount, LocalDateTime now
  ) {
    int hold = job.getStatus() == CreditJobStatus.RESERVED ? job.getReserved() : 0;
    int charge = CreditJobCharges.chargeOf(job, imageCount);
    int running = accountService.balance(account, now).available();

    if (hold > 0) {
      running += hold;
      AiCreditLedger unhold = CreditAccountService.ledgerLine(accountId, CreditLedgerType.RELEASE, hold, running);
      unhold.setJobId(jobId);
      unhold.setPolicyVersion(job.getPolicyVersion());
      unhold.setReason("정산 — 예약을 실제 차감으로 바꾼다");
      ledgerRepository.save(unhold);
    }

    // 초과를 허용하지 않는 종류(그림 한 장)는 남은 만큼만 청구한다. 반환·만료 뒤 늦게 끝나 잔액이 모자라도
    // 초과로 남기지 않는다 — 시작할 때 "잔액 안에서만"이라고 약속한 작업이다.
    if (!job.getKind().overageAllowed()) {
      charge = Math.min(charge, Math.max(0, running));
    }
    // 일과 글 무료: 그림 차감 줄보다 먼저 0 짜리 글 사용 줄을 남김 (내역에 "무료" 글 줄, 그림 줄은 그 위) (#1110)
    if (CreditFreeRoutineTextAllowance.isFreeRoutineTextJob(job)) {
      AiCreditLedger freeText = CreditAccountService.ledgerLine(accountId, CreditLedgerType.CONSUME, 0, running);
      freeText.setJobId(jobId);
      freeText.setAction(CreditAction.ROUTINE_TEXT);
      freeText.setPolicyVersion(job.getPolicyVersion());
      freeText.setReason(CreditFreeRoutineTextAllowance.FREE_ROUTINE_TEXT_REASON);
      ledgerRepository.save(freeText);
    }

    int left = Math.min(charge, running);
    int deducted = 0;
    List<AiCreditGrant> grants = accountService.spendableGrants(accountId, now);
    for (AiCreditGrant grant : grants) {
      if (left == 0) {
        break;
      }
      int take = Math.min(left, grant.getRemaining());
      grant.setRemaining(grant.getRemaining() - take);
      left -= take;
      deducted += take;
      running -= take;
      AiCreditLedger consume = CreditAccountService.ledgerLine(accountId, CreditLedgerType.CONSUME, -take, running);
      consume.setJobId(jobId);
      consume.setGrantId(grant.getId());
      consume.setAction(CreditJobCharges.reserveAction(job.getKind()));
      consume.setPolicyVersion(job.getPolicyVersion());
      ledgerRepository.save(consume);
    }

    // 무료 다시 그리기: 차감 0 이어도 사용 내역에 "무료" 줄이 보이게 0 짜리 사용 줄을 남김
    if (deducted == 0 && CreditFreeRegenerateAllowance.isFreeRegenerateJob(job, imageCount)) {
      AiCreditLedger free = CreditAccountService.ledgerLine(accountId, CreditLedgerType.CONSUME, 0, running);
      free.setJobId(jobId);
      free.setAction(CreditAction.IMAGE_REGENERATE);
      free.setPolicyVersion(job.getPolicyVersion());
      free.setReason(CreditFreeRegenerateAllowance.FREE_REGENERATE_REASON);
      ledgerRepository.save(free);
    }

    int overage = charge - deducted;
    if (overage > 0) {
      AiCreditLedger over = CreditAccountService.ledgerLine(accountId, CreditLedgerType.OVERAGE, 0, running);
      over.setJobId(jobId);
      over.setPolicyVersion(job.getPolicyVersion());
      over.setReason("초과 " + overage + " — 청구 " + charge + " 중 잔액이 모자라 차감하지 못한 몫");
      ledgerRepository.save(over);
    }

    return new SettledAmounts(deducted, overage, running);
  }
}
