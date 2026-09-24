package com.chuseok22.elumserver.credit.application.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;

import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

/**
 * 크레딧 저장소 넷을 메모리 목록으로 흉내 낸다.
 *
 * <p>호출마다 고정값을 돌려주는 목으로는 "예약하면 사용 가능량이 준다" 같은 흐름을 볼 수 없다. 저장한 것이
 * 다음 조회에 보여야 해서, 실제 쿼리와 같은 조건으로 거르는 목록을 둔다 (RoutineQuotaGuardTest 의 호출 기록과 같은 방식).
 */
/// 관리자 크레딧 테스트(admin 패키지)도 같은 저장소 흉내를 쓴다 — 그래서 public 이다.
public final class CreditTestStore {

  public final List<AiCreditAccount> accounts = new ArrayList<>();
  public final List<AiCreditGrant> grants = new ArrayList<>();
  public final List<AiCreditJob> jobs = new ArrayList<>();
  public final List<AiCreditLedger> ledger = new ArrayList<>();

  public void wire(
    AiCreditAccountRepository accountRepository, AiCreditGrantRepository grantRepository,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository
  ) {
    lenient().when(accountRepository.findByMemberId(anyString())).thenAnswer(inv -> accounts.stream()
      .filter(a -> inv.getArgument(0).equals(a.getMemberId())).findFirst());
    lenient().when(accountRepository.findByMemberIdForUpdate(anyString())).thenAnswer(inv -> accounts.stream()
      .filter(a -> inv.getArgument(0).equals(a.getMemberId())).findFirst());
    lenient().when(accountRepository.findByIdentityKey(anyString())).thenAnswer(inv -> accounts.stream()
      .filter(a -> inv.getArgument(0).equals(a.getIdentityKey())).findFirst());
    lenient().when(accountRepository.findByIdForUpdate(anyString())).thenAnswer(inv -> accounts.stream()
      .filter(a -> inv.getArgument(0).equals(a.getId())).findFirst());
    lenient().when(accountRepository.save(any(AiCreditAccount.class))).thenAnswer(inv -> {
      AiCreditAccount account = inv.getArgument(0);
      if (account.getId() == null) {
        account.setId(UUID.randomUUID().toString());
      }
      if (!accounts.contains(account)) {
        accounts.add(account);
      }
      return account;
    });

    lenient().when(grantRepository.findByAccountIdAndPeriodKey(anyString(), anyString())).thenAnswer(inv -> grants.stream()
      .filter(g -> g.getAccountId().equals(inv.getArgument(0)) && inv.getArgument(1).equals(g.getPeriodKey()))
      .findFirst());
    lenient().when(grantRepository.findByAccountIdAndRemainingGreaterThan(anyString(), anyInt())).thenAnswer(inv -> grants.stream()
      .filter(g -> g.getAccountId().equals(inv.getArgument(0)) && g.getRemaining() > inv.<Integer>getArgument(1))
      .toList());
    lenient().when(grantRepository.findByPeriodKey(anyString())).thenAnswer(inv -> grants.stream()
      .filter(g -> inv.getArgument(0).equals(g.getPeriodKey()))
      .toList());
    lenient().when(grantRepository.findAccountIdsByPeriodKeyAndSource(anyString(), any(CreditGrantSource.class)))
      .thenAnswer(inv -> grants.stream()
        .filter(g -> inv.getArgument(0).equals(g.getPeriodKey()) && g.getSource() == inv.getArgument(1))
        .map(AiCreditGrant::getAccountId)
        .toList());
    lenient().when(grantRepository.findById(anyString())).thenAnswer(inv -> grants.stream()
      .filter(g -> g.getId().equals(inv.getArgument(0))).findFirst());
    lenient().when(grantRepository.save(any(AiCreditGrant.class))).thenAnswer(inv -> {
      AiCreditGrant grant = inv.getArgument(0);
      if (grant.getId() == null) {
        grant.setId(UUID.randomUUID().toString());
      }
      if (!grants.contains(grant)) {
        grants.add(grant);
      }
      return grant;
    });

    lenient().when(jobRepository.findByAccountIdAndRequestKey(anyString(), anyString())).thenAnswer(inv -> jobs.stream()
      .filter(j -> j.getAccountId().equals(inv.getArgument(0)) && j.getRequestKey().equals(inv.getArgument(1)))
      .findFirst());
    lenient().when(jobRepository.findByAccountIdAndStatus(anyString(), any(CreditJobStatus.class))).thenAnswer(inv -> jobs.stream()
      .filter(j -> j.getAccountId().equals(inv.getArgument(0)) && j.getStatus() == inv.getArgument(1))
      .toList());
    lenient().when(jobRepository.findById(anyString())).thenAnswer(inv -> jobs.stream()
      .filter(j -> j.getId().equals(inv.getArgument(0))).findFirst());
    lenient().when(jobRepository.findAccountIdById(anyString())).thenAnswer(inv -> jobs.stream()
      .filter(j -> j.getId().equals(inv.getArgument(0))).findFirst().map(AiCreditJob::getAccountId));
    lenient().when(jobRepository.save(any(AiCreditJob.class))).thenAnswer(inv -> {
      AiCreditJob job = inv.getArgument(0);
      if (job.getId() == null) {
        job.setId(UUID.randomUUID().toString());
      }
      if (!jobs.contains(job)) {
        jobs.add(job);
      }
      return job;
    });

    lenient().when(ledgerRepository.save(any(AiCreditLedger.class))).thenAnswer(inv -> {
      AiCreditLedger line = inv.getArgument(0);
      ledger.add(line);
      return line;
    });
    // 메모리 목록엔 createdAt 이 찍히지 않는다(감사 리스너 없음) — 기간은 보지 않고 종류로만 더한다.
    lenient().when(ledgerRepository.sumDelta(anyString(), any(CreditLedgerType.class), any(), any())).thenAnswer(inv -> ledger.stream()
      .filter(l -> l.getAccountId().equals(inv.getArgument(0)) && l.getType() == inv.getArgument(1))
      .mapToLong(AiCreditLedger::getDelta).sum());
  }

  public AiCreditAccount account(String id, String memberId) {
    AiCreditAccount account = new AiCreditAccount();
    account.setId(id);
    account.setMemberId(memberId);
    accounts.add(account);
    return account;
  }

  public AiCreditGrant weekly(String accountId, LocalDateTime inWeek, int amount, int remaining) {
    CreditPeriod period = CreditPeriod.of(inWeek);
    AiCreditGrant grant = grant(accountId, CreditGrantSource.WEEKLY, amount, remaining, period.start(), period.end());
    grant.setPeriodKey(period.key());
    return grant;
  }

  public AiCreditGrant grant(
    String accountId, CreditGrantSource source, int amount, int remaining,
    LocalDateTime validFrom, LocalDateTime expiresAt
  ) {
    AiCreditGrant grant = new AiCreditGrant();
    grant.setId(UUID.randomUUID().toString());
    grant.setAccountId(accountId);
    grant.setSource(source);
    grant.setAmount(amount);
    grant.setRemaining(remaining);
    grant.setValidFrom(validFrom);
    grant.setExpiresAt(expiresAt);
    grants.add(grant);
    return grant;
  }

  public AiCreditJob reservedJob(String accountId, String requestKey, CreditJobKind kind, int reserved, LocalDateTime startedAt) {
    AiCreditJob job = new AiCreditJob();
    job.setId(UUID.randomUUID().toString());
    job.setAccountId(accountId);
    job.setRequestKey(requestKey);
    job.setKind(kind);
    job.setStatus(CreditJobStatus.RESERVED);
    job.setReserved(reserved);
    job.setStartedAt(startedAt);
    job.setCostSnapshot("{\"ROUTINE_TEXT\":1,\"CARD_IMAGE\":1,\"IMAGE_REGENERATE\":1}");
    job.setPolicyVersion(1);
    jobs.add(job);
    return job;
  }

  public List<AiCreditLedger> ledgerOf(CreditLedgerType type) {
    return ledger.stream().filter(l -> l.getType() == type).toList();
  }

  public Optional<AiCreditJob> job(String id) {
    return jobs.stream().filter(j -> Objects.equals(j.getId(), id)).findFirst();
  }
}
