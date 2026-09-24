package com.chuseok22.elumserver.credit.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.PlanType;
import jakarta.persistence.EntityManager;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.transaction.PlatformTransactionManager;

@ExtendWith(MockitoExtension.class)
class CreditReservationServiceTest {

  private static final String MEMBER_ID = "m1";
  private static final String ACCOUNT_ID = "acc1";
  /// 2026-09-23(수) 15:00 한국 시각 — 2026-W39.
  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-09-23T06:00:00Z"), ZoneId.of("Asia/Seoul"));
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 23, 15, 0);

  @Mock
  private AiCreditAccountRepository accountRepository;
  @Mock
  private AiCreditGrantRepository grantRepository;
  @Mock
  private AiCreditJobRepository jobRepository;
  @Mock
  private AiCreditLedgerRepository ledgerRepository;
  @Mock
  private CreditPolicyService policyService;
  @Mock
  private EntitlementService entitlementService;

  private final CreditTestStore store = new CreditTestStore();
  private CreditAccountService accountService;
  private CreditReservationService service;
  private AiCreditPolicy policy;
  private AiCreditAccount account;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    accountService = new CreditAccountService(
      accountRepository, grantRepository, jobRepository, ledgerRepository, mock(EntityManager.class));
    // 트랜잭션 관리자는 목 — 트랜잭션 경계는 단위 테스트가 볼 수 없고, 안의 계산만 본다.
    service = new CreditReservationService(policyService, accountService, entitlementService,
      jobRepository, ledgerRepository, mock(PlatformTransactionManager.class), CLOCK);

    policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(1);
    policy.setEnabled(true);
    policy.setWeeklyGrantJson("{\"FREE\":100,\"PRO\":100}");
    policy.setActionCostsJson("{\"ROUTINE_TEXT\":1,\"CARD_IMAGE\":1,\"IMAGE_REGENERATE\":1}");
    policy.setReservationTtlMinutes(15);
    lenient().when(policyService.current()).thenReturn(policy);
    lenient().when(policyService.grantPolicyFor(any())).thenReturn(policy);
    lenient().when(entitlementService.planOf(anyString())).thenReturn(PlanType.FREE);

    account = store.account(ACCOUNT_ID, MEMBER_ID);
  }

  /// 이번 주 지급을 미리 만들어 둔다 — 남은 양을 테스트가 정한다.
  private AiCreditGrant weeklyRemaining(int remaining) {
    return store.weekly(ACCOUNT_ID, NOW, 100, remaining);
  }

  private int available() {
    return accountService.balance(account, NOW).available();
  }

  private static void assertRejectedWith(Runnable call, ErrorCode expected) {
    assertThatThrownBy(call::run)
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(expected));
  }

  // --- 예약 ---

  @Test
  @DisplayName("(a) 잔액 1 에서 일과 생성을 예약하면 RESERVED 이고 사용 가능은 0 이 된다")
  void reserve_holdsRoutineTextCost() {
    weeklyRemaining(1);

    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    assertThat(reservation.outcome()).isEqualTo(CreditReservation.Outcome.RESERVED);
    AiCreditJob job = store.job(reservation.jobId()).orElseThrow();
    assertThat(job.getStatus()).isEqualTo(CreditJobStatus.RESERVED);
    assertThat(job.getReserved()).isEqualTo(1);
    assertThat(job.getPolicyVersion()).isEqualTo(1);
    assertThat(job.getCostSnapshot()).isEqualTo(policy.getActionCostsJson());
    assertThat(job.getStartedAt()).isEqualTo(NOW);
    assertThat(available()).isZero();
    assertThat(store.ledgerOf(CreditLedgerType.RESERVE)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isEqualTo(-1);
      assertThat(line.getBalanceAfter()).isZero();
      assertThat(line.getJobId()).isEqualTo(job.getId());
    });
  }

  @Test
  @DisplayName("이번 주 지급이 없으면 예약하면서 만든다 — 첫 요청이 곧 지급 시점이다")
  void reserve_ensuresWeeklyGrant() {
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    assertThat(reservation.outcome()).isEqualTo(CreditReservation.Outcome.RESERVED);
    assertThat(store.grants).singleElement().extracting(AiCreditGrant::getPeriodKey).isEqualTo("2026-W39");
    assertThat(available()).isEqualTo(99);
  }

  @Test
  @DisplayName("(b) 잔액 0 이면 AI_CREDIT_INSUFFICIENT — 작업을 만들지 않는다")
  void reserve_insufficient() {
    weeklyRemaining(0);

    assertRejectedWith(() -> service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true),
      ErrorCode.AI_CREDIT_INSUFFICIENT);
    assertThat(store.jobs).isEmpty();
  }

  @Test
  @DisplayName("(c) 같은 키가 진행 중이면 AI_CREDIT_JOB_IN_PROGRESS")
  void reserve_sameKeyInProgress() {
    weeklyRemaining(10);
    service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    assertRejectedWith(() -> service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true),
      ErrorCode.AI_CREDIT_JOB_IN_PROGRESS);
    assertThat(store.jobs).hasSize(1);
  }

  @Test
  @DisplayName("(c) 같은 키가 이미 정산됐으면 ALREADY_SETTLED 와 저장된 일과 id — 다시 차감하지 않는다")
  void reserve_sameKeySettled() {
    weeklyRemaining(10);
    CreditReservation first = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);
    service.settle(first.jobId(), 3, 3, "routine-1", null);
    int ledgerSize = store.ledger.size();

    CreditReservation again = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    assertThat(again.outcome()).isEqualTo(CreditReservation.Outcome.ALREADY_SETTLED);
    assertThat(again.jobId()).isEqualTo(first.jobId());
    assertThat(again.routineId()).isEqualTo("routine-1");
    assertThat(store.ledger).hasSize(ledgerSize);
  }

  @Test
  @DisplayName("실패로 반환된 키로 다시 하면 같은 작업을 다시 예약한다 — 앱의 다시 하기는 같은 키를 쓴다")
  void reserve_sameKeyAfterRelease_reReserves() {
    weeklyRemaining(10);
    CreditReservation first = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);
    service.release(first.jobId(), "AI 실패");

    CreditReservation retry = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    assertThat(retry.outcome()).isEqualTo(CreditReservation.Outcome.RESERVED);
    assertThat(retry.jobId()).isEqualTo(first.jobId());
    AiCreditJob job = store.job(retry.jobId()).orElseThrow();
    assertThat(job.getStatus()).isEqualTo(CreditJobStatus.RESERVED);
    assertThat(job.getFailReason()).isNull();
    assertThat(job.getFinishedAt()).isNull();
    assertThat(available()).isEqualTo(9);
  }

  @Test
  @DisplayName("(g) 수동 카드 그림은 초과를 허용하지 않는다 — 잔액 0 이면 AI_CREDIT_INSUFFICIENT")
  void reserve_cardImageWithoutOverage() {
    weeklyRemaining(0);

    assertRejectedWith(() -> service.reserve(MEMBER_ID, CreditJobKind.CARD_IMAGE, "card-1", false),
      ErrorCode.AI_CREDIT_INSUFFICIENT);
  }

  @Test
  @DisplayName("수동 카드 그림은 CARD_IMAGE 단가만큼 예약한다")
  void reserve_cardImageCost() {
    policy.setActionCostsJson("{\"ROUTINE_TEXT\":1,\"CARD_IMAGE\":3}");
    weeklyRemaining(5);

    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.CARD_IMAGE, "card-1", false);

    assertThat(store.job(reservation.jobId()).orElseThrow().getReserved()).isEqualTo(3);
    assertThat(available()).isEqualTo(2);
  }

  @Test
  @DisplayName("(j) 크레딧이 꺼져 있으면 DISABLED — 계정도 원장도 건드리지 않는다")
  void reserve_disabled() {
    policy.setEnabled(false);

    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    assertThat(reservation.outcome()).isEqualTo(CreditReservation.Outcome.DISABLED);
    assertThat(reservation.jobId()).isNull();
    assertThat(store.ledger).isEmpty();
    assertThat(store.jobs).isEmpty();
  }

  @Test
  @DisplayName("(k) 동결된 계정은 잔액이 있어도 AI_CREDIT_ACCOUNT_FROZEN")
  void reserve_frozen() {
    weeklyRemaining(50);
    account.setStatus(CreditAccountStatus.FROZEN);

    assertRejectedWith(() -> service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true),
      ErrorCode.AI_CREDIT_ACCOUNT_FROZEN);
  }

  @Test
  @DisplayName("장부 DB 오류면 AI_CREDIT_UNAVAILABLE — 열어 두지 않는다(fail-closed)")
  void reserve_dbError_unavailable() {
    when(accountRepository.findByMemberIdForUpdate(MEMBER_ID)).thenThrow(new DataAccessResourceFailureException("down"));

    assertRejectedWith(() -> service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true),
      ErrorCode.AI_CREDIT_UNAVAILABLE);
  }

  @Test
  @DisplayName("정책을 못 읽어도 AI_CREDIT_UNAVAILABLE")
  void reserve_policyError_unavailable() {
    when(policyService.current()).thenThrow(new DataAccessResourceFailureException("down"));

    assertRejectedWith(() -> service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true),
      ErrorCode.AI_CREDIT_UNAVAILABLE);
  }

  // --- 정산 ---

  @Test
  @DisplayName("(d) 잔액 1 · 그림 8 → 차감 1, 초과 8, 잔액 0 — 일과는 끝까지 만든다")
  void settle_overageWhenShort() {
    weeklyRemaining(1);
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    CreditSettlement settlement = service.settle(reservation.jobId(), 8, 8, "routine-1", null);

    assertThat(settlement.charged()).isEqualTo(1);
    assertThat(settlement.overage()).isEqualTo(8);
    assertThat(settlement.balanceAfter()).isZero();
    AiCreditJob job = store.job(reservation.jobId()).orElseThrow();
    assertThat(job.getStatus()).isEqualTo(CreditJobStatus.SETTLED);
    assertThat(job.getCharged()).isEqualTo(1);
    assertThat(job.getOverage()).isEqualTo(8);
    assertThat(job.getImageCount()).isEqualTo(8);
    assertThat(job.getCardCount()).isEqualTo(8);
    assertThat(job.getRoutineId()).isEqualTo("routine-1");
    assertThat(job.getFinishedAt()).isEqualTo(NOW);
    assertThat(store.ledgerOf(CreditLedgerType.OVERAGE)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isZero();
      assertThat(line.getReason()).contains("8");
    });
    assertThat(available()).isZero();
  }

  @Test
  @DisplayName("(e) 잔액 100 · 그림 4 → 차감 5, 잔액 95, 이번 주 사용 5")
  void settle_chargesTextPlusImages() {
    weeklyRemaining(100);
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    CreditSettlement settlement = service.settle(reservation.jobId(), 5, 4, "routine-1", null);

    assertThat(settlement.charged()).isEqualTo(5);
    assertThat(settlement.overage()).isZero();
    assertThat(settlement.balanceAfter()).isEqualTo(95);
    assertThat(store.ledgerOf(CreditLedgerType.OVERAGE)).isEmpty();
    CreditBalance balance = accountService.balance(account, NOW);
    assertThat(balance.available()).isEqualTo(95);
    assertThat(balance.used()).isEqualTo(5);
    assertThat(balance.reserved()).isZero();
    // 원장 누적이 사용 가능량과 맞는다: 예약 −1, 정산 때 예약 해제 +1, 차감 −5.
    assertThat(store.ledger.stream().mapToInt(AiCreditLedger::getDelta).sum()).isEqualTo(-5);
  }

  @Test
  @DisplayName("(f) WEEKLY 2 + 무기한 보너스 10 에서 5 를 쓰면 주간부터 — WEEKLY 0, 보너스 7")
  void settle_consumesExpiringFirst() {
    AiCreditGrant weekly = weeklyRemaining(2);
    AiCreditGrant bonus = store.grant(ACCOUNT_ID, CreditGrantSource.ADMIN_BONUS, 10, 10, NOW.minusDays(1), null);
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    service.settle(reservation.jobId(), 4, 4, "routine-1", null);

    assertThat(weekly.getRemaining()).isZero();
    assertThat(bonus.getRemaining()).isEqualTo(7);
    assertThat(store.ledgerOf(CreditLedgerType.CONSUME))
      .extracting(AiCreditLedger::getGrantId, AiCreditLedger::getDelta)
      .containsExactly(
        org.assertj.core.groups.Tuple.tuple(weekly.getId(), -2),
        org.assertj.core.groups.Tuple.tuple(bonus.getId(), -3));
  }

  @Test
  @DisplayName("정산은 시작 때 단가를 쓴다 — 진행 중에 정책이 바뀌어도")
  void settle_usesSnapshotCosts() {
    policy.setActionCostsJson("{\"ROUTINE_TEXT\":2,\"CARD_IMAGE\":3}");
    weeklyRemaining(100);
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);
    policy.setActionCostsJson("{\"ROUTINE_TEXT\":1,\"CARD_IMAGE\":1}");

    CreditSettlement settlement = service.settle(reservation.jobId(), 2, 2, "routine-1", null);

    assertThat(settlement.charged()).isEqualTo(2 + 3 * 2);
  }

  @Test
  @DisplayName("수동 카드 그림 정산은 그림 단가 × 장수")
  void settle_cardImage() {
    weeklyRemaining(10);
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.CARD_IMAGE, "card-1", false);

    CreditSettlement settlement = service.settle(reservation.jobId(), 0, 1, "routine-1", "step-1");

    assertThat(settlement.charged()).isEqualTo(1);
    assertThat(settlement.balanceAfter()).isEqualTo(9);
    assertThat(store.job(reservation.jobId()).orElseThrow().getStepId()).isEqualTo("step-1");
  }

  @Test
  @DisplayName("수동 카드 그림은 반환된 뒤 잔액 0 에서 정산돼도 초과를 남기지 않는다 — 차감 0 · 초과 0")
  void settle_cardImageAfterRelease_neverRecordsOverage() {
    weeklyRemaining(1);
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.CARD_IMAGE, "card-1", false);
    // 관리자·TTL 이 먼저 풀고, 그 사이 다른 작업이 잔액을 다 썼다.
    service.release(reservation.jobId(), "관리자 반환");
    store.grants.forEach(grant -> grant.setRemaining(0));

    CreditSettlement settlement = service.settle(reservation.jobId(), 0, 1, "routine-1", "step-1");

    assertThat(settlement.charged()).isZero();
    assertThat(settlement.overage()).isZero();
    AiCreditJob job = store.job(reservation.jobId()).orElseThrow();
    assertThat(job.getStatus()).isEqualTo(CreditJobStatus.SETTLED);
    assertThat(job.getOverage()).isZero();
    assertThat(store.ledgerOf(CreditLedgerType.OVERAGE)).isEmpty();
  }

  @Test
  @DisplayName("수동 카드 그림은 남은 만큼만 차감한다 — 모자란 몫을 초과로 적지 않는다")
  void settle_cardImage_capsChargeToAvailable() {
    policy.setActionCostsJson("{\"ROUTINE_TEXT\":1,\"CARD_IMAGE\":3}");
    weeklyRemaining(3);
    AiCreditJob job = store.reservedJob(ACCOUNT_ID, "card-1", CreditJobKind.CARD_IMAGE, 1, NOW);
    job.setCostSnapshot(policy.getActionCostsJson());

    CreditSettlement settlement = service.settle(job.getId(), 0, 2, "routine-1", "step-1");

    // 청구 6(3×2) 중 예약 1 + 사용 가능 2 = 3 만 차감하고 나머지는 버린다.
    assertThat(settlement.charged()).isEqualTo(3);
    assertThat(settlement.overage()).isZero();
    assertThat(store.ledgerOf(CreditLedgerType.OVERAGE)).isEmpty();
  }

  @Test
  @DisplayName("초과 허용 여부가 작업 종류와 어긋나면 예약하지 않는다 — 종류가 정산 규칙을 정한다")
  void reserve_rejectsOverageFlagMismatch() {
    weeklyRemaining(10);

    assertThatThrownBy(() -> service.reserve(MEMBER_ID, CreditJobKind.CARD_IMAGE, "card-1", true))
      .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", false))
      .isInstanceOf(IllegalArgumentException.class);
    assertThat(store.jobs).isEmpty();
  }

  @Test
  @DisplayName("이번 주 첫 지급은 주 시작 때 정책(grantPolicyFor) 지급량으로 만든다 — 지금 정책이 아니다")
  void reserve_weeklyGrantUsesGrantPolicy() {
    policy.setWeeklyGrantJson("{\"FREE\":0,\"PRO\":0}");
    policy.setVersion(2);
    AiCreditPolicy atPeriodStart = AiCreditPolicy.disabledDefault();
    atPeriodStart.setVersion(1);
    atPeriodStart.setEnabled(true);
    atPeriodStart.setWeeklyGrantJson("{\"FREE\":100,\"PRO\":100}");
    when(policyService.grantPolicyFor(any())).thenReturn(atPeriodStart);

    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    assertThat(reservation.outcome()).isEqualTo(CreditReservation.Outcome.RESERVED);
    assertThat(store.grants).singleElement().satisfies(grant -> {
      assertThat(grant.getAmount()).isEqualTo(100);
      assertThat(grant.getPolicyVersion()).isEqualTo(1);
    });
    assertThat(store.job(reservation.jobId()).orElseThrow().getPolicyVersion()).as("단가는 지금 정책").isEqualTo(2);
  }

  @Test
  @DisplayName("이미 정산된 작업을 다시 정산하면 그대로 돌려준다(멱등) — 두 번 차감하지 않는다")
  void settle_idempotent() {
    weeklyRemaining(100);
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);
    CreditSettlement first = service.settle(reservation.jobId(), 4, 4, "routine-1", null);
    int ledgerSize = store.ledger.size();

    CreditSettlement again = service.settle(reservation.jobId(), 4, 4, "routine-1", null);

    assertThat(again.charged()).isEqualTo(first.charged());
    assertThat(again.overage()).isEqualTo(first.overage());
    assertThat(again.balanceAfter()).isEqualTo(95);
    assertThat(store.ledger).hasSize(ledgerSize);
  }

  @Test
  @DisplayName("TTL 로 만료된 뒤 끝난 작업도 청구한다 — 예약은 이미 풀렸으니 다시 풀지 않는다")
  void settle_afterExpiry_chargesWithoutDoubleRelease() {
    weeklyRemaining(10);
    AiCreditJob job = store.reservedJob(ACCOUNT_ID, "key-1", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusMinutes(20));
    service.expireStale(MEMBER_ID);
    assertThat(job.getStatus()).isEqualTo(CreditJobStatus.EXPIRED);
    long releases = store.ledgerOf(CreditLedgerType.RELEASE).size();

    CreditSettlement settlement = service.settle(job.getId(), 2, 2, "routine-1", null);

    assertThat(settlement.charged()).isEqualTo(3);
    assertThat(settlement.balanceAfter()).isEqualTo(7);
    assertThat(store.ledgerOf(CreditLedgerType.RELEASE)).hasSize((int) releases);
    assertThat(job.getStatus()).isEqualTo(CreditJobStatus.SETTLED);
  }

  @Test
  @DisplayName("없는 작업을 정산하면 AI_CREDIT_UNAVAILABLE — 일과 저장과 함께 되돌린다")
  void settle_unknownJob() {
    assertRejectedWith(() -> service.settle("nope", 1, 0, "routine-1", null), ErrorCode.AI_CREDIT_UNAVAILABLE);
  }

  // --- 반환 · 만료 ---

  @Test
  @DisplayName("(h) 반환하면 RELEASED 이고 잔액이 되돌아온다")
  void release_restoresBalance() {
    weeklyRemaining(1);
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    service.release(reservation.jobId(), "AI 생성 실패");

    AiCreditJob job = store.job(reservation.jobId()).orElseThrow();
    assertThat(job.getStatus()).isEqualTo(CreditJobStatus.RELEASED);
    assertThat(job.getFailReason()).isEqualTo("AI 생성 실패");
    assertThat(job.getFinishedAt()).isEqualTo(NOW);
    assertThat(available()).isEqualTo(1);
    assertThat(store.ledgerOf(CreditLedgerType.RELEASE)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isEqualTo(1);
      assertThat(line.getBalanceAfter()).isEqualTo(1);
    });
  }

  @Test
  @DisplayName("정산된 작업은 반환하지 않는다")
  void release_ignoresSettled() {
    weeklyRemaining(10);
    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);
    service.settle(reservation.jobId(), 1, 0, "routine-1", null);
    int ledgerSize = store.ledger.size();

    service.release(reservation.jobId(), "늦은 실패");

    assertThat(store.job(reservation.jobId()).orElseThrow().getStatus()).isEqualTo(CreditJobStatus.SETTLED);
    assertThat(store.ledger).hasSize(ledgerSize);
  }

  @Test
  @DisplayName("반환이 실패해도 호출자에게 예외를 던지지 않는다 — TTL 만료가 복구한다")
  void release_failureDoesNotPropagate() {
    when(jobRepository.findAccountIdById("job-x")).thenThrow(new DataAccessResourceFailureException("down"));

    assertThatCode(() -> service.release("job-x", "실패")).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("(i) TTL 15분을 넘긴 예약(16분)은 EXPIRED 로 풀고, 14분짜리는 둔다")
  void expireStale_releasesOldReservations() {
    weeklyRemaining(10);
    AiCreditJob stale = store.reservedJob(ACCOUNT_ID, "old", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusMinutes(16));
    AiCreditJob fresh = store.reservedJob(ACCOUNT_ID, "new", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusMinutes(14));

    int expired = service.expireStale(MEMBER_ID);

    assertThat(expired).isEqualTo(1);
    assertThat(stale.getStatus()).isEqualTo(CreditJobStatus.EXPIRED);
    assertThat(stale.getFinishedAt()).isEqualTo(NOW);
    assertThat(fresh.getStatus()).isEqualTo(CreditJobStatus.RESERVED);
    assertThat(store.ledgerOf(CreditLedgerType.RELEASE)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isEqualTo(1);
      assertThat(line.getJobId()).isEqualTo(stale.getId());
    });
    assertThat(available()).isEqualTo(9);
  }

  @Test
  @DisplayName("예약은 멈춘 예약을 먼저 풀고 잔액을 본다 — 멈춘 예약 때문에 부족으로 막히지 않는다")
  void reserve_expiresStaleFirst() {
    weeklyRemaining(1);
    store.reservedJob(ACCOUNT_ID, "old", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusMinutes(30));

    CreditReservation reservation = service.reserve(MEMBER_ID, CreditJobKind.ROUTINE_CREATE, "key-1", true);

    assertThat(reservation.outcome()).isEqualTo(CreditReservation.Outcome.RESERVED);
  }
}
