package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import lombok.extern.slf4j.Slf4j;

/**
 * 예약 되돌리기 2종: 반환(RELEASED, 실패한 작업) · 만료(EXPIRED, TTL 지난 예약)
 * 둘 다 계정 행 잠금 안에서 부름 (트랜잭션 경계는 CreditReservationService)
 */
@Slf4j
class CreditReservationReturns {

  private final CreditAccountService accountService;
  private final AiCreditJobRepository jobRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  private final Clock clock;

  CreditReservationReturns(
    CreditAccountService accountService, AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    Clock clock
  ) {
    this.accountService = accountService;
    this.jobRepository = jobRepository;
    this.ledgerRepository = ledgerRepository;
    this.clock = clock;
  }

  /// 반환: RESERVED 일 때만 (정산·만료된 작업은 그대로)
  void releaseLocked(String jobId, String reason) {
    String accountId = jobRepository.findAccountIdById(jobId).orElse(null);
    if (accountId == null) {
      log.warn("반환할 크레딧 작업이 없다: jobId={}", jobId);
      return;
    }
    AiCreditAccount account = accountService.lockAccountById(accountId);
    AiCreditJob job = jobRepository.findById(jobId).orElse(null);
    if (job == null || job.getStatus() != CreditJobStatus.RESERVED) {
      return;
    }
    LocalDateTime now = LocalDateTime.now(clock);
    int balanceAfter = accountService.balance(account, now).available() + job.getReserved();
    job.setStatus(CreditJobStatus.RELEASED);
    job.setFinishedAt(now);
    job.setFailReason(reason);
    jobRepository.save(job);
    AiCreditLedger line = CreditAccountService.ledgerLine(accountId, CreditLedgerType.RELEASE, job.getReserved(), balanceAfter);
    line.setJobId(jobId);
    line.setPolicyVersion(job.getPolicyVersion());
    line.setReason(reason);
    ledgerRepository.save(line);
  }

  /// 만료: 시작이 TTL 보다 오래된 RESERVED 를 EXPIRED 로 풀고 돌려준 개수
  int expireStaleLocked(AiCreditAccount account, AiCreditPolicy policy, LocalDateTime now) {
    LocalDateTime threshold = now.minusMinutes(policy.getReservationTtlMinutes());
    List<AiCreditJob> stale = jobRepository.findByAccountIdAndStatus(account.getId(), CreditJobStatus.RESERVED).stream()
      .filter(job -> job.getStartedAt().isBefore(threshold))
      .toList();
    for (AiCreditJob job : stale) {
      int balanceAfter = accountService.balance(account, now).available() + job.getReserved();
      job.setStatus(CreditJobStatus.EXPIRED);
      job.setFinishedAt(now);
      job.setFailReason("예약 유지 시간(" + policy.getReservationTtlMinutes() + "분) 초과");
      jobRepository.save(job);
      AiCreditLedger line = CreditAccountService.ledgerLine(account.getId(), CreditLedgerType.RELEASE, job.getReserved(), balanceAfter);
      line.setJobId(job.getId());
      line.setPolicyVersion(job.getPolicyVersion());
      line.setReason("멈춘 예약 자동 반환");
      ledgerRepository.save(line);
      log.warn("멈춘 크레딧 예약을 만료시켰다: accountId={}, jobId={}, startedAt={}",
        account.getId(), job.getId(), job.getStartedAt());
    }
    return stale.size();
  }
}
