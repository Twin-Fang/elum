package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.dto.response.CreditSummaryResponse;
import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 보호자에게 보여 줄 크레딧 요약과 "지금 시작할 수 있는가" 판정 (#407).
 *
 * <p>조회도 쓰기가 있다 — 이번 주 지급을 만들고 멈춘 예약을 푼다. 그래서 계정을 잠근 트랜잭션 안에서 한다.
 * 장부를 못 읽으면 막는다(fail-closed, AI_CREDIT_UNAVAILABLE) — 0 을 돌려주면 보호자는 다 썼다고 믿는다.
 */
@Slf4j
@Service
public class CreditQueryService {

  /// 일과 하나의 최대 카드 수. RoutineAiPipeline.MAX_STEPS · RoutineService.STEP_MAX_COUNT 와 같은 값이다.
  public static final int MAX_CARDS_PER_ROUTINE = 10;

  private final CreditPolicyService policyService;
  private final CreditAccountService accountService;
  private final CreditReservationService reservationService;
  private final EntitlementService entitlementService;
  private final AiCreditJobRepository jobRepository;
  private final TransactionTemplate transaction;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public CreditQueryService(
    CreditPolicyService policyService, CreditAccountService accountService,
    CreditReservationService reservationService, EntitlementService entitlementService,
    AiCreditJobRepository jobRepository, PlatformTransactionManager transactionManager
  ) {
    this(policyService, accountService, reservationService, entitlementService, jobRepository,
      transactionManager, Clock.systemDefaultZone());
  }

  CreditQueryService(
    CreditPolicyService policyService, CreditAccountService accountService,
    CreditReservationService reservationService, EntitlementService entitlementService,
    AiCreditJobRepository jobRepository, PlatformTransactionManager transactionManager, Clock clock
  ) {
    this.policyService = policyService;
    this.accountService = accountService;
    this.reservationService = reservationService;
    this.entitlementService = entitlementService;
    this.jobRepository = jobRepository;
    this.transaction = new TransactionTemplate(transactionManager);
    this.clock = clock;
  }

  /**
   * 내 크레딧 요약. 꺼져 있으면 enabled=false · 0 · can*=true.
   *
   * @throws CustomException AI_CREDIT_UNAVAILABLE — 장부를 읽지 못했다
   */
  public CreditSummaryResponse getMine(String memberId) {
    AiCreditPolicy policy = currentPolicy();
    if (!policy.isEnabled()) {
      return CreditSummaryResponse.disabled(MAX_CARDS_PER_ROUTINE);
    }
    Snapshot snapshot = snapshot(memberId);
    CreditBalance balance = snapshot.balance();
    int routineText = policy.costOf(CreditAction.ROUTINE_TEXT);
    int cardImage = policy.costOf(CreditAction.CARD_IMAGE);
    List<CreditSummaryResponse.InProgress> inProgress = snapshot.reservedJobs().stream()
      .sorted(Comparator.comparing(AiCreditJob::getStartedAt, Comparator.nullsLast(Comparator.naturalOrder())))
      .map(job -> new CreditSummaryResponse.InProgress(job.getId(), job.getKind().name(), job.getStartedAt()))
      .toList();
    return new CreditSummaryResponse(
      true,
      balance.available(),
      balance.weeklyGrant(),
      balance.bonus(),
      balance.used(),
      balance.reserved(),
      balance.period().start(),
      balance.period().end(),
      new CreditSummaryResponse.Costs(routineText, cardImage),
      MAX_CARDS_PER_ROUTINE,
      inProgress,
      !snapshot.frozen() && balance.available() >= routineText,
      !snapshot.frozen() && balance.available() >= cardImage
    );
  }

  /**
   * AI 일과를 시작할 수 있는지 본다. 추가 질문처럼 차감은 없지만 곧 일과 생성으로 이어지는 호출이 앞에서 부른다
   * — 잔액 0 에서 질문을 만들어 주고 카드 만들기에서 막으면 보호자가 입력만 두 번 한다(스펙 §3).
   *
   * @throws CustomException AI_CREDIT_ACCOUNT_FROZEN · AI_CREDIT_INSUFFICIENT · AI_CREDIT_UNAVAILABLE
   */
  public void requireCanStartRoutine(String memberId) {
    AiCreditPolicy policy = currentPolicy();
    if (!policy.isEnabled()) {
      return;
    }
    Snapshot snapshot = snapshot(memberId);
    if (snapshot.frozen()) {
      throw new CustomException(ErrorCode.AI_CREDIT_ACCOUNT_FROZEN);
    }
    if (snapshot.balance().available() < policy.costOf(CreditAction.ROUTINE_TEXT)) {
      log.info("크레딧 부족 — 추가 질문을 막는다: memberId={}, available={}", memberId, snapshot.balance().available());
      throw new CustomException(ErrorCode.AI_CREDIT_INSUFFICIENT);
    }
  }

  private AiCreditPolicy currentPolicy() {
    try {
      return policyService.current();
    } catch (RuntimeException e) {
      log.error("크레딧 정책 조회 실패 — 막는다", e);
      throw new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE);
    }
  }

  /// 계정을 잠그고 멈춘 예약 정리 → 이번 주 지급 보장 → 잔액을 한 트랜잭션에서 읽는다.
  /// 지급량은 주 시작 때 정책으로 정한다(grantPolicyFor) — 주 중간 NEXT_PERIOD 발행이 이번 주로 새지 않게.
  private Snapshot snapshot(String memberId) {
    Snapshot snapshot;
    try {
      snapshot = transaction.execute(status -> {
        LocalDateTime now = LocalDateTime.now(clock);
        // expireStale 이 먼저 계정을 잠근다(같은 트랜잭션이라 아래 lockAccount 는 같은 행을 다시 받는다).
        reservationService.expireStale(memberId);
        AiCreditAccount account = accountService.lockAccount(memberId);
        accountService.ensureWeeklyGrant(account, policyService::grantPolicyFor, entitlementService.planOf(memberId), now);
        CreditBalance balance = accountService.balance(account, now);
        List<AiCreditJob> reserved = jobRepository.findByAccountIdAndStatus(account.getId(), CreditJobStatus.RESERVED);
        return new Snapshot(balance, reserved, account.isFrozen());
      });
    } catch (CustomException e) {
      throw e;
    } catch (RuntimeException e) {
      log.error("크레딧 조회 실패(장부 오류) — 막는다: memberId={}", memberId, e);
      throw new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE);
    }
    if (snapshot == null) {
      log.error("크레딧 조회 결과가 비었다: memberId={}", memberId);
      throw new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE);
    }
    return snapshot;
  }

  private record Snapshot(CreditBalance balance, List<AiCreditJob> reservedJobs, boolean frozen) {

  }
}
