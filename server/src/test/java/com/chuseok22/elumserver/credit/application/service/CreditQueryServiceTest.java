package com.chuseok22.elumserver.credit.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.dto.response.CreditSummaryResponse;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.PlanType;
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

/**
 * 크레딧 요약 조회와 시작 가능 판정 (#407 Task S5). 저장소는 메모리 목록(CreditTestStore)이다.
 */
@ExtendWith(MockitoExtension.class)
class CreditQueryServiceTest {

  private static final String MEMBER_ID = "m1";
  private static final String ACCOUNT_ID = "acc1";
  /// 2026-09-23(수) 15:00 한국 시각 — 2026-W39 (09-21 ~ 09-28).
  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-09-23T06:00:00Z"), ZoneId.of("Asia/Seoul"));
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 23, 15, 0);

  @Mock private AiCreditAccountRepository accountRepository;
  @Mock private AiCreditGrantRepository grantRepository;
  @Mock private AiCreditJobRepository jobRepository;
  @Mock private AiCreditLedgerRepository ledgerRepository;
  @Mock private CreditPolicyService policyService;
  @Mock private EntitlementService entitlementService;

  private final CreditTestStore store = new CreditTestStore();
  private CreditQueryService service;
  private AiCreditPolicy policy;
  private AiCreditAccount account;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    CreditAccountService accountService =
      new CreditAccountService(accountRepository, grantRepository, jobRepository, ledgerRepository,
        org.mockito.Mockito.mock(jakarta.persistence.EntityManager.class));
    PlatformTransactionManager tx = mock(PlatformTransactionManager.class);
    CreditReservationService reservationService = new CreditReservationService(
      policyService, accountService, entitlementService, jobRepository, ledgerRepository, tx, CLOCK);
    service = new CreditQueryService(policyService, accountService, reservationService, entitlementService,
      jobRepository, tx, CLOCK);

    policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(1);
    policy.setEnabled(true);
    policy.setWeeklyGrantJson("{\"FREE\":100,\"PRO\":100}");
    policy.setActionCostsJson("{\"ROUTINE_TEXT\":1,\"CARD_IMAGE\":2,\"IMAGE_REGENERATE\":1}");
    policy.setReservationTtlMinutes(15);
    lenient().when(policyService.current()).thenReturn(policy);
    lenient().when(policyService.grantPolicyFor(org.mockito.ArgumentMatchers.any())).thenReturn(policy);
    lenient().when(entitlementService.planOf(anyString())).thenReturn(PlanType.FREE);

    account = store.account(ACCOUNT_ID, MEMBER_ID);
  }

  @Test
  @DisplayName("값 매핑: 주간 72 + 보너스 30 − 예약 1 → 사용 가능 101, 주기·단가·진행 중 작업까지 채운다")
  void getMine_mapsBalance() {
    store.weekly(ACCOUNT_ID, NOW, 100, 72);
    store.grant(ACCOUNT_ID, CreditGrantSource.ADMIN_BONUS, 30, 30, NOW.minusDays(1), null);
    store.reservedJob(ACCOUNT_ID, "key-1", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusMinutes(1));

    CreditSummaryResponse summary = service.getMine(MEMBER_ID);

    assertThat(summary.enabled()).isTrue();
    assertThat(summary.available()).isEqualTo(101);
    assertThat(summary.weeklyGrant()).isEqualTo(100);
    assertThat(summary.bonus()).isEqualTo(30);
    assertThat(summary.reserved()).isEqualTo(1);
    assertThat(summary.periodStart()).isEqualTo(LocalDateTime.of(2026, 9, 21, 0, 0));
    assertThat(summary.nextResetAt()).isEqualTo(LocalDateTime.of(2026, 9, 28, 0, 0));
    assertThat(summary.costs()).isEqualTo(new CreditSummaryResponse.Costs(1, 2));
    assertThat(summary.maxCardsPerRoutine()).isEqualTo(10);
    assertThat(summary.inProgress()).singleElement().satisfies(job -> {
      assertThat(job.kind()).isEqualTo("ROUTINE_CREATE");
      assertThat(job.startedAt()).isEqualTo(NOW.minusMinutes(1));
    });
    assertThat(summary.canStartRoutine()).isTrue();
    assertThat(summary.canGenerateImage()).isTrue();
  }

  @Test
  @DisplayName("이번 주 지급이 없으면 조회하면서 만든다")
  void getMine_ensuresWeeklyGrant() {
    CreditSummaryResponse summary = service.getMine(MEMBER_ID);

    assertThat(summary.available()).isEqualTo(100);
    assertThat(summary.weeklyGrant()).isEqualTo(100);
    assertThat(store.grants).singleElement().extracting(g -> g.getPeriodKey()).isEqualTo("2026-W39");
  }

  @Test
  @DisplayName("TTL 지난 예약은 조회 때 풀린다 — 진행 중에서 빠지고 사용 가능이 돌아온다")
  void getMine_expiresStaleReservations() {
    store.weekly(ACCOUNT_ID, NOW, 100, 10);
    store.reservedJob(ACCOUNT_ID, "old", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusMinutes(16));

    CreditSummaryResponse summary = service.getMine(MEMBER_ID);

    assertThat(summary.inProgress()).isEmpty();
    assertThat(summary.available()).isEqualTo(10);
    assertThat(store.jobs).singleElement().extracting(j -> j.getStatus()).isEqualTo(CreditJobStatus.EXPIRED);
  }

  @Test
  @DisplayName("canStartRoutine = 사용 가능 ≥ 글 단가 · canGenerateImage = 사용 가능 ≥ 그림 단가")
  void getMine_canFlagsFollowCosts() {
    store.weekly(ACCOUNT_ID, NOW, 100, 1);

    CreditSummaryResponse summary = service.getMine(MEMBER_ID);

    assertThat(summary.canStartRoutine()).isTrue();
    assertThat(summary.canGenerateImage()).as("그림 단가 2 > 사용 가능 1").isFalse();
  }

  @Test
  @DisplayName("잔액 0 이면 둘 다 false")
  void getMine_exhausted() {
    store.weekly(ACCOUNT_ID, NOW, 100, 0);

    CreditSummaryResponse summary = service.getMine(MEMBER_ID);

    assertThat(summary.available()).isZero();
    assertThat(summary.canStartRoutine()).isFalse();
    assertThat(summary.canGenerateImage()).isFalse();
  }

  @Test
  @DisplayName("동결 계정은 잔액이 있어도 시작할 수 없다")
  void getMine_frozen_cannotStart() {
    store.weekly(ACCOUNT_ID, NOW, 100, 50);
    account.setStatus(CreditAccountStatus.FROZEN);

    CreditSummaryResponse summary = service.getMine(MEMBER_ID);

    assertThat(summary.available()).isEqualTo(50);
    assertThat(summary.canStartRoutine()).isFalse();
    assertThat(summary.canGenerateImage()).isFalse();
  }

  @Test
  @DisplayName("정책이 꺼져 있으면 enabled=false · 0 · 빈 값 · can*=true — 장부를 건드리지 않는다")
  void getMine_disabled() {
    policy.setEnabled(false);

    CreditSummaryResponse summary = service.getMine(MEMBER_ID);

    assertThat(summary.enabled()).isFalse();
    assertThat(summary.available()).isZero();
    assertThat(summary.periodStart()).isNull();
    assertThat(summary.nextResetAt()).isNull();
    assertThat(summary.inProgress()).isEmpty();
    assertThat(summary.canStartRoutine()).isTrue();
    assertThat(summary.canGenerateImage()).isTrue();
    assertThat(store.grants).isEmpty();
  }

  @Test
  @DisplayName("장부를 읽지 못하면 0 을 돌려주지 않고 AI_CREDIT_UNAVAILABLE")
  void getMine_ledgerError_unavailable() {
    when(accountRepository.findByMemberIdForUpdate(MEMBER_ID)).thenThrow(new DataAccessResourceFailureException("db down"));

    assertThatThrownBy(() -> service.getMine(MEMBER_ID))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_CREDIT_UNAVAILABLE);
  }

  // --- 시작 가능 판정(추가 질문 앞) ---

  @Test
  @DisplayName("잔액 0 이면 추가 질문 앞에서 AI_CREDIT_INSUFFICIENT")
  void requireCanStart_exhausted_insufficient() {
    store.weekly(ACCOUNT_ID, NOW, 100, 0);

    assertThatThrownBy(() -> service.requireCanStartRoutine(MEMBER_ID))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_CREDIT_INSUFFICIENT);
  }

  @Test
  @DisplayName("동결 계정은 AI_CREDIT_ACCOUNT_FROZEN")
  void requireCanStart_frozen() {
    store.weekly(ACCOUNT_ID, NOW, 100, 50);
    account.setStatus(CreditAccountStatus.FROZEN);

    assertThatThrownBy(() -> service.requireCanStartRoutine(MEMBER_ID))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_CREDIT_ACCOUNT_FROZEN);
  }

  @Test
  @DisplayName("잔액이 있거나 정책이 꺼져 있으면 통과한다")
  void requireCanStart_passes() {
    store.weekly(ACCOUNT_ID, NOW, 100, 1);
    assertThatCode(() -> service.requireCanStartRoutine(MEMBER_ID)).doesNotThrowAnyException();

    policy.setEnabled(false);
    store.grants.get(0).setRemaining(0);
    assertThatCode(() -> service.requireCanStartRoutine(MEMBER_ID)).doesNotThrowAnyException();
  }
}
