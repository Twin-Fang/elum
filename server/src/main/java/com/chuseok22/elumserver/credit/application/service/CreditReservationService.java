package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.PlanType;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 크레딧 예약 → 정산 / 반환 / 만료 (#407).
 *
 * <pre>
 *   reserve ──(계정 잠금)── 사용 가능 ≥ 예약량? ──▶ RESERVED ──┬── 저장 성공 ─▶ settle  (차감 = min(청구, 사용 가능+예약), 나머지는 초과)
 *                                                             ├── 실패 ──────▶ release (예약 반환)
 *                                                             └── TTL 초과 ──▶ expireStale (다음 조회·예약 때)
 * </pre>
 *
 * <p>모든 증감은 계정 행 잠금 안에서 일어난다. 장부를 못 읽으면 막는다(fail-closed, AI_CREDIT_UNAVAILABLE).
 */
@Slf4j
@Service
public class CreditReservationService {

  private final CreditPolicyService policyService;
  private final CreditAccountService accountService;
  private final EntitlementService entitlementService;
  private final AiCreditJobRepository jobRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  /// 예약: 호출자 트랜잭션이 있으면 합류(수동 카드 저장 안), 없으면 짧게 새로 연다(일과 생성 전).
  private final TransactionTemplate joinOrNew;
  /// 반환: 호출자가 롤백하는 중에도 반환은 남아야 한다.
  private final TransactionTemplate alwaysNew;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public CreditReservationService(
    CreditPolicyService policyService, CreditAccountService accountService, EntitlementService entitlementService,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    PlatformTransactionManager transactionManager
  ) {
    this(policyService, accountService, entitlementService, jobRepository, ledgerRepository,
      transactionManager, Clock.systemDefaultZone());
  }

  CreditReservationService(
    CreditPolicyService policyService, CreditAccountService accountService, EntitlementService entitlementService,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    PlatformTransactionManager transactionManager, Clock clock
  ) {
    this.policyService = policyService;
    this.accountService = accountService;
    this.entitlementService = entitlementService;
    this.jobRepository = jobRepository;
    this.ledgerRepository = ledgerRepository;
    this.joinOrNew = new TransactionTemplate(transactionManager);
    this.alwaysNew = new TransactionTemplate(transactionManager);
    this.alwaysNew.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    this.clock = clock;
  }

  /**
   * 생성 작업 하나를 예약한다.
   *
   * <p>거절(부족·진행 중·동결)은 트랜잭션을 정상으로 끝낸 <b>뒤에</b> 던진다. 안에서 던지면 호출자 트랜잭션
   * (수동 카드 저장)까지 롤백 전용이 되어, "그림만 건너뛰고 카드는 저장"이 불가능해진다. 거절 전에 한
   * 쓰기(이번 주 지급·멈춘 예약 정리)는 맞는 기록이라 남겨도 된다.
   *
   * @param allowOverage 정산에서 청구가 예약을 넘을 수 있는가. 일과 생성은 true(그림 수만큼 늘어난다),
   *                     수동 카드 그림은 false(청구 = 예약이라 초과가 생기지 않는다). 예약 규칙은 같다 —
   *                     어느 쪽이든 사용 가능 ≥ 예약량이어야 시작한다. 정산은 작업 종류
   *                     ({@link CreditJobKind#overageAllowed()})로 판단하므로 둘이 어긋나면 받지 않는다
   * @throws CustomException AI_CREDIT_JOB_IN_PROGRESS · AI_CREDIT_INSUFFICIENT · AI_CREDIT_ACCOUNT_FROZEN ·
   *                         AI_CREDIT_UNAVAILABLE(장부 DB 오류)
   * @throws IllegalArgumentException allowOverage 가 작업 종류와 어긋날 때(호출 코드 오류)
   */
  public CreditReservation reserve(String memberId, CreditJobKind kind, String requestKey, boolean allowOverage) {
    if (allowOverage != kind.overageAllowed()) {
      // 호출자가 기대한 정산 규칙과 실제 규칙이 다르면 청구가 조용히 어긋난다 — 예약 전에 막는다.
      throw new IllegalArgumentException(
        "초과 허용 여부가 작업 종류와 다르다: kind=" + kind + ", allowOverage=" + allowOverage);
    }
    ReserveResult result;
    try {
      AiCreditPolicy policy = policyService.current();
      if (!policy.isEnabled()) {
        return CreditReservation.disabled();
      }
      result = joinOrNew.execute(status -> reserveLocked(memberId, kind, requestKey, policy));
    } catch (CustomException e) {
      throw e;
    } catch (RuntimeException e) {
      log.error("크레딧 예약 실패(장부 오류) — 막는다: memberId={}, kind={}, requestKey={}", memberId, kind, requestKey, e);
      throw new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE);
    }
    if (result == null) {
      log.error("크레딧 예약 결과가 비었다: memberId={}, kind={}", memberId, kind);
      throw new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE);
    }
    if (result.rejection() != null) {
      log.info("크레딧 예약 거절: memberId={}, kind={}, reason={}, allowOverage={}",
        memberId, kind, result.rejection(), allowOverage);
      throw new CustomException(result.rejection());
    }
    return result.reservation();
  }

  /// 트랜잭션 안에서 판정한다. 거절은 예외가 아니라 값으로 돌려준다(위 reserve 설명).
  private ReserveResult reserveLocked(String memberId, CreditJobKind kind, String requestKey, AiCreditPolicy policy) {
    LocalDateTime now = LocalDateTime.now(clock);
    AiCreditAccount account = accountService.lockAccount(memberId);
    if (account.isFrozen()) {
      return ReserveResult.rejected(ErrorCode.AI_CREDIT_ACCOUNT_FROZEN);
    }

    AiCreditJob existing = jobRepository.findByAccountIdAndRequestKey(account.getId(), requestKey).orElse(null);
    if (existing != null && existing.getStatus() == CreditJobStatus.SETTLED) {
      return ReserveResult.of(CreditReservation.alreadySettled(existing.getId(), existing.getRoutineId()));
    }

    // 멈춘 예약을 먼저 풀어야 그 예약 때문에 부족으로 막히지 않는다. 같은 키가 방금 만료됐다면 아래에서 다시 쓴다.
    expireStaleLocked(account, policy, now);
    if (existing != null && existing.getStatus() == CreditJobStatus.RESERVED) {
      return ReserveResult.rejected(ErrorCode.AI_CREDIT_JOB_IN_PROGRESS);
    }

    accountService.ensureWeeklyGrant(account, policyService::grantPolicyFor, planOf(account), now);
    int cost = policy.costOf(reserveAction(kind));
    int available = accountService.balance(account, now).available();
    if (available < cost) {
      return ReserveResult.rejected(ErrorCode.AI_CREDIT_INSUFFICIENT);
    }

    // 반환·만료된 같은 키는 새 행 대신 그 행을 다시 쓴다 — (account_id, request_key) 유니크이고,
    // 앱의 "다시 하기"는 같은 키로 온다.
    AiCreditJob job = existing != null ? existing : new AiCreditJob();
    job.setAccountId(account.getId());
    job.setRequestKey(requestKey);
    job.setKind(kind);
    job.setStatus(CreditJobStatus.RESERVED);
    job.setReserved(cost);
    job.setCharged(0);
    job.setOverage(0);
    job.setPolicyVersion(policy.getVersion());
    job.setCostSnapshot(policy.getActionCostsJson());
    job.setStartedAt(now);
    job.setFinishedAt(null);
    job.setFailReason(null);
    AiCreditJob saved = jobRepository.save(job);

    AiCreditLedger line = CreditAccountService.ledgerLine(account.getId(), CreditLedgerType.RESERVE, -cost, available - cost);
    line.setJobId(saved.getId());
    line.setAction(reserveAction(kind));
    line.setPolicyVersion(policy.getVersion());
    ledgerRepository.save(line);
    return ReserveResult.of(CreditReservation.reserved(saved.getId()));
  }

  /**
   * 작업을 정산한다. 호출자 트랜잭션(일과 저장)에 합류한다 — 정산이 실패하면 일과 저장도 함께 되돌린다.
   *
   * <p>청구는 시작 때 단가(cost_snapshot)로 계산한다. 차감 = min(청구, 사용 가능 + 이 작업 예약), 모자란 몫은
   * 초과로 기록하고 잔액은 0 에서 멈춘다 — 잔액이 있을 때 시작한 일과는 끝까지 만든다. 초과는 일과 생성만
   * 남긴다 — 그림 한 장(CARD_IMAGE·IMAGE_REGENERATE)은 모자란 몫을 버리고 초과 0 으로 정산한다.
   * 이미 정산했으면 그대로 돌려준다(멱등). TTL 로 만료된 뒤 끝난 작업도 청구한다(예약은 이미 풀렸다).
   */
  @Transactional
  public CreditSettlement settle(String jobId, int cardCount, int imageCount, String routineId, String stepId) {
    LocalDateTime now = LocalDateTime.now(clock);
    // 계정을 잠근 뒤에 작업을 읽는다 — 먼저 읽으면 그 사이 다른 트랜잭션의 정산을 못 본다.
    String accountId = jobRepository.findAccountIdById(jobId).orElseThrow(() -> unknownJob(jobId));
    AiCreditAccount account = accountService.lockAccountById(accountId);
    AiCreditJob job = jobRepository.findById(jobId).orElseThrow(() -> unknownJob(jobId));

    if (job.getStatus() == CreditJobStatus.SETTLED) {
      return new CreditSettlement(job.getCharged(), job.getOverage(), accountService.balance(account, now).available());
    }

    // 주 경계를 걸친 작업은 정산 시점의 유효 묶음에서 차감한다 — 새 주 지급이 없으면 먼저 만든다.
    AiCreditPolicy policy = policyService.current();
    if (policy.isEnabled()) {
      accountService.ensureWeeklyGrant(account, policyService::grantPolicyFor, planOf(account), now);
    }

    int hold = job.getStatus() == CreditJobStatus.RESERVED ? job.getReserved() : 0;
    int charge = chargeOf(job, imageCount);
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
      consume.setAction(reserveAction(job.getKind()));
      consume.setPolicyVersion(job.getPolicyVersion());
      ledgerRepository.save(consume);
    }

    int overage = charge - deducted;
    if (overage > 0) {
      AiCreditLedger over = CreditAccountService.ledgerLine(accountId, CreditLedgerType.OVERAGE, 0, running);
      over.setJobId(jobId);
      over.setPolicyVersion(job.getPolicyVersion());
      over.setReason("초과 " + overage + " — 청구 " + charge + " 중 잔액이 모자라 차감하지 못한 몫");
      ledgerRepository.save(over);
    }

    job.setStatus(CreditJobStatus.SETTLED);
    job.setCharged(deducted);
    job.setOverage(overage);
    job.setCardCount(cardCount);
    job.setImageCount(imageCount);
    job.setRoutineId(routineId);
    job.setStepId(stepId);
    job.setFinishedAt(now);
    jobRepository.save(job);
    return new CreditSettlement(deducted, overage, Math.max(0, running));
  }

  /**
   * 같은 멱등 키로 이미 정산한 일과 id. 잠그지 않고 읽기만 한다.
   *
   * <p>일과 생성이 쿨다운·한도·예산 검사보다 <b>먼저</b> 부른다 — 응답을 놓친 앱이 같은 키로 다시 보냈는데
   * "너무 잦다"·"한도 초과"로 막히면 이미 만든(청구한) 일과를 영영 못 받는다. 못 읽으면 비워 돌려주고
   * 원래 흐름(예약 안의 같은 확인)에 맡긴다 — 여기서 막으면 장부 오류가 한도 검사보다 앞서 보인다.
   */
  public Optional<String> findSettledRoutineId(String memberId, String requestKey) {
    try {
      return accountService.findAccount(memberId)
        .flatMap(account -> jobRepository.findByAccountIdAndRequestKey(account.getId(), requestKey))
        .filter(job -> job.getStatus() == CreditJobStatus.SETTLED)
        .map(AiCreditJob::getRoutineId);
    } catch (RuntimeException e) {
      log.warn("멱등 키 선조회 실패 — 예약 단계에서 다시 본다: memberId={}, requestKey={}", memberId, requestKey, e);
      return Optional.empty();
    }
  }

  /**
   * 예약을 돌려준다. RESERVED 일 때만 — 정산·만료된 작업은 그대로 둔다.
   *
   * <p>새 트랜잭션에서 한다. 호출자가 롤백하는 중(일과 저장 실패)에도 반환은 남아야 한다. 실패해도 호출자에게
   * 던지지 않는다 — 원래 실패를 가리면 안 되고, 남은 예약은 TTL 만료가 풀어 준다. 대신 error 로 남겨
   * 관리자 "멈춘 예약"과 맞춰 볼 수 있게 한다.
   */
  public void release(String jobId, String reason) {
    try {
      alwaysNew.executeWithoutResult(status -> releaseLocked(jobId, reason));
    } catch (RuntimeException e) {
      log.error("크레딧 예약 반환 실패 — TTL 만료가 복구한다: jobId={}, reason={}", jobId, reason, e);
    }
  }

  private void releaseLocked(String jobId, String reason) {
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

  /**
   * TTL 이 지난 예약을 EXPIRED 로 풀고 돌려준 개수를 센다. 잔액 조회·예약 전에 부른다.
   *
   * <p>서버가 작업 도중 죽으면 반환도 정산도 오지 않는다. 배치 없이 다음 조회 때 풀어 잔액이 영영 묶이지 않게 한다.
   */
  @Transactional
  public int expireStale(String memberId) {
    AiCreditAccount account = accountService.lockAccount(memberId);
    return expireStaleLocked(account, policyService.current(), LocalDateTime.now(clock));
  }

  private int expireStaleLocked(AiCreditAccount account, AiCreditPolicy policy, LocalDateTime now) {
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

  /// 예약량·원장 action 을 정하는 행동. 일과 생성은 글 단가만 예약한다(그림 수는 끝나야 안다).
  private static CreditAction reserveAction(CreditJobKind kind) {
    return switch (kind) {
      case ROUTINE_CREATE -> CreditAction.ROUTINE_TEXT;
      case CARD_IMAGE -> CreditAction.CARD_IMAGE;
      case IMAGE_REGENERATE -> CreditAction.IMAGE_REGENERATE;
    };
  }

  /// 시작 때 단가로 청구를 계산한다.
  private static int chargeOf(AiCreditJob job, int imageCount) {
    String costs = job.getCostSnapshot();
    int images = Math.max(0, imageCount);
    return switch (job.getKind()) {
      case ROUTINE_CREATE -> AiCreditPolicy.costFrom(costs, CreditAction.ROUTINE_TEXT)
        + AiCreditPolicy.costFrom(costs, CreditAction.CARD_IMAGE) * images;
      case CARD_IMAGE -> AiCreditPolicy.costFrom(costs, CreditAction.CARD_IMAGE) * images;
      case IMAGE_REGENERATE -> AiCreditPolicy.costFrom(costs, CreditAction.IMAGE_REGENERATE) * images;
    };
  }

  private PlanType planOf(AiCreditAccount account) {
    // 떼어진 계정(완전 삭제 뒤)은 회원이 없다 — Free 로 본다.
    return account.getMemberId() == null ? PlanType.FREE : entitlementService.planOf(account.getMemberId());
  }

  private static CustomException unknownJob(String jobId) {
    log.error("정산할 크레딧 작업이 없다: jobId={}", jobId);
    return new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE);
  }

  /// 예약 판정 결과. 거절이면 rejection 에 코드가 있다.
  private record ReserveResult(CreditReservation reservation, ErrorCode rejection) {

    static ReserveResult of(CreditReservation reservation) {
      return new ReserveResult(reservation, null);
    }

    static ReserveResult rejected(ErrorCode code) {
      return new ReserveResult(null, code);
    }
  }
}
