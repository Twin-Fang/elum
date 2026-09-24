package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditJobRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditOverview;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditWeekRow;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.CreditJobCost;
import com.chuseok22.elumserver.common.OfflineHibernate;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditPolicyService;
import com.chuseok22.elumserver.credit.application.service.CreditTestStore;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository.AccountTotal;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.routine.application.service.AiDailyBudgetGuard;
import jakarta.persistence.EntityManager;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Root;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;

@ExtendWith(MockitoExtension.class)
class AdminCreditQueryServiceTest {

  /// 2026-09-23(수) 15:00 한국 시각 — 2026-W39.
  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-09-23T06:00:00Z"), ZoneId.of("Asia/Seoul"));
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 23, 15, 0);

  @Mock
  private CreditPolicyService policyService;
  @Mock
  private AiCreditAccountRepository accountRepository;
  @Mock
  private AiCreditGrantRepository grantRepository;
  @Mock
  private AiCreditJobRepository jobRepository;
  @Mock
  private AiCreditLedgerRepository ledgerRepository;
  @Mock
  private AiCallLogRepository aiCallLogRepository;
  @Mock
  private SubscriptionRepository subscriptionRepository;
  @Mock
  private MemberRepository memberRepository;
  @Mock
  private ProfileGuardianRepository profileGuardianRepository;
  @Mock
  private EntitlementService entitlementService;
  @Mock
  private AiDailyBudgetGuard dailyBudgetGuard;

  private final CreditTestStore store = new CreditTestStore();
  private AdminCreditQueryService service;
  private AiCreditPolicy policy;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    CreditAccountService accountService =
      new CreditAccountService(accountRepository, grantRepository, jobRepository, ledgerRepository,
      org.mockito.Mockito.mock(jakarta.persistence.EntityManager.class));
    policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(1);
    policy.setEnabled(true);
    policy.setReservationTtlMinutes(15);
    lenient().when(policyService.current()).thenReturn(policy);
    service = new AdminCreditQueryService(policyService, accountService, accountRepository, grantRepository,
      jobRepository, ledgerRepository, aiCallLogRepository, subscriptionRepository, memberRepository,
      profileGuardianRepository, entitlementService, dailyBudgetGuard, CLOCK);

    lenient().when(accountRepository.findAll()).thenAnswer(inv -> store.accounts);
    lenient().when(ledgerRepository.sumDeltaOfPeriodGrantsByAccount(any(), anyString())).thenReturn(List.of());
    lenient().when(ledgerRepository.sumDeltaByAccount(any(), any(), any())).thenReturn(List.of());
    lenient().when(ledgerRepository.lastAtByAccount(any())).thenReturn(List.of());
    lenient().when(grantRepository.sumNonWeeklyGrantedByAccount(any(), any(), any())).thenReturn(List.of());
    lenient().when(grantRepository.sumValidNonWeeklyRemainingByAccount(any(), any())).thenReturn(List.of());
    lenient().when(jobRepository.sumReservedByAccount(any())).thenReturn(List.of());
    lenient().when(jobRepository.sumOverageByAccount(any(), any())).thenReturn(List.of());
  }

  private static AccountTotal total(String accountId, long value) {
    return new AccountTotal() {
      @Override
      public String getAccountId() {
        return accountId;
      }

      @Override
      public long getTotal() {
        return value;
      }
    };
  }

  @Test
  @DisplayName("주 키 — 틀리거나 미래면 이번 주, 지난 주는 그 주")
  void periodOf() {
    assertThat(service.periodOf(null).key()).isEqualTo("2026-W39");
    assertThat(service.periodOf("엉망").key()).isEqualTo("2026-W39");
    assertThat(service.periodOf("2026-W52").key()).isEqualTo("2026-W39");
    CreditPeriod past = service.periodOf("2026-W37");
    assertThat(past.key()).isEqualTo("2026-W37");
    assertThat(past.start()).isEqualTo(LocalDateTime.of(2026, 9, 7, 0, 0));
  }

  @Test
  @DisplayName("이번 주 남음 = 주간 남음 + 유효 보너스 − 예약, 다 쓰면 소진")
  void weekRows_currentWeek() {
    store.account("a1", "m1");
    store.account("a2", "m2");
    store.weekly("a1", NOW, 100, 30);
    store.weekly("a2", NOW, 100, 0);
    when(grantRepository.sumValidNonWeeklyRemainingByAccount(eq(CreditGrantSource.WEEKLY), any()))
      .thenReturn(List.of(total("a1", 10)));
    when(jobRepository.sumReservedByAccount(CreditJobStatus.RESERVED)).thenReturn(List.of(total("a1", 2)));
    when(ledgerRepository.sumDeltaByAccount(eq(CreditLedgerType.CONSUME), any(), any()))
      .thenReturn(List.of(total("a1", -70), total("a2", -100)));

    List<AdminCreditWeekRow> rows = service.weekRows(CreditPeriod.of(NOW), NOW);

    AdminCreditWeekRow a1 = rows.stream().filter(r -> r.accountId().equals("a1")).findFirst().orElseThrow();
    AdminCreditWeekRow a2 = rows.stream().filter(r -> r.accountId().equals("a2")).findFirst().orElseThrow();
    assertThat(a1.remaining()).isEqualTo(38);
    assertThat(a1.used()).isEqualTo(70);
    assertThat(a1.reserved()).isEqualTo(2);
    assertThat(a1.exhausted()).isFalse();
    assertThat(a2.exhausted()).isTrue();
  }

  @Test
  @DisplayName("지난 주 남음 = 그 주 지급의 남음 + 만료된 양 — 예약은 보지 않는다")
  void weekRows_pastWeekAddsBackExpired() {
    store.account("a1", "m1");
    LocalDateTime lastWeek = NOW.minusWeeks(1);
    store.weekly("a1", lastWeek, 100, 0);
    when(ledgerRepository.sumDeltaOfPeriodGrantsByAccount(CreditLedgerType.EXPIRE, CreditPeriod.of(lastWeek).key()))
      .thenReturn(List.of(total("a1", -25)));

    List<AdminCreditWeekRow> rows = service.weekRows(CreditPeriod.of(lastWeek), NOW);

    assertThat(rows).singleElement().satisfies(row -> {
      assertThat(row.remaining()).isEqualTo(25);
      assertThat(row.reserved()).isZero();
    });
  }

  @Test
  @DisplayName("개요 — 멈춘 예약은 지금 − TTL 기준으로 세고, 사용 0 이면 크레딧당 원가는 null")
  void overview_warningsAndZeroGuard() {
    when(jobRepository.countByStatusAndStartedAtBefore(CreditJobStatus.RESERVED, NOW.minusMinutes(15))).thenReturn(2L);
    when(jobRepository.countSettledWithoutCallLog(eq(CreditJobStatus.SETTLED), any(), any())).thenReturn(3L);
    when(aiCallLogRepository.sumCostByModelBetween(any(), any())).thenReturn(List.of());
    when(jobRepository.sumCostByKind(any(), any(), any())).thenReturn(List.of());
    when(dailyBudgetGuard.isReached()).thenReturn(true);

    AdminCreditOverview overview = service.overview(null);

    assertThat(overview.stuckCount()).isEqualTo(2);
    assertThat(overview.mismatchCount()).isEqualTo(3);
    assertThat(overview.budgetReached()).isTrue();
    assertThat(overview.costPerCredit()).isNull();
    assertThat(overview.current()).isTrue();
    assertThat(overview.nextKey()).isNull();
    assertThat(overview.prevKey()).isEqualTo("2026-W38");
    assertThat(overview.hasWarning()).isTrue();
  }

  @Test
  @DisplayName("작업 줄 — 청구가 있는데 연결 호출 0 이면 불일치, TTL 넘긴 예약은 멈춤")
  void jobRows_flagMismatchAndStuck() {
    store.account("a1", "m1");
    AiCreditJob settled = store.reservedJob("a1", "k1", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusHours(1));
    settled.setStatus(CreditJobStatus.SETTLED);
    settled.setCharged(3);
    AiCreditJob linked = store.reservedJob("a1", "k2", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusHours(1));
    linked.setStatus(CreditJobStatus.SETTLED);
    linked.setCharged(3);
    AiCreditJob stuck = store.reservedJob("a1", "k3", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusMinutes(20));
    AiCreditJob fresh = store.reservedJob("a1", "k4", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusMinutes(5));
    Page<AiCreditJob> page = new PageImpl<>(List.of(settled, linked, stuck, fresh));
    when(jobRepository.findAll(org.mockito.ArgumentMatchers.<Specification<AiCreditJob>>any(), any(Pageable.class)))
      .thenReturn(page);
    when(accountRepository.findAllById(any())).thenReturn(store.accounts);
    when(aiCallLogRepository.sumCostByCreditJobIds(any())).thenReturn(List.of(cost(linked.getId(), 4, 0.02)));

    Page<AdminCreditJobRow> rows = service.jobs(
      new AdminCreditQueryService.JobFilter(null, null, null, null, false, false, null), 0);

    assertThat(rows.getContent()).extracting(AdminCreditJobRow::mismatch).containsExactly(true, false, false, false);
    assertThat(rows.getContent()).extracting(AdminCreditJobRow::stuck).containsExactly(false, false, true, false);
    assertThat(rows.getContent().get(1).callCount()).isEqualTo(4);
    assertThat(rows.getContent().get(0).memberId()).isEqualTo("m1");
  }

  private static CreditJobCost cost(String jobId, long calls, double usd) {
    return new CreditJobCost() {
      @Override
      public String getCreditJobId() {
        return jobId;
      }

      @Override
      public long getCallCount() {
        return calls;
      }

      @Override
      public double getTotalCostUsd() {
        return usd;
      }
    };
  }

  @Test
  @DisplayName("작업 탐색 조건은 필터를 모두 켜도 엔티티 모델로 해석된다(서버를 띄우지 않고)")
  void jobSpec_resolvesAgainstModel() {
    AdminCreditQueryService.JobFilter all = new AdminCreditQueryService.JobFilter(
      CreditJobStatus.SETTLED, CreditJobKind.ROUTINE_CREATE, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30),
      true, true, "abc");
    try (OfflineHibernate hibernate = OfflineHibernate.open();
         EntityManager em = hibernate.sessionFactory().createEntityManager()) {
      CriteriaBuilder cb = em.getCriteriaBuilder();
      CriteriaQuery<AiCreditJob> query = cb.createQuery(AiCreditJob.class);
      Root<AiCreditJob> root = query.from(AiCreditJob.class);
      query.select(root).where(AdminCreditQueryService.specOf(all).toPredicate(root, query, cb));

      assertThatCode(() -> em.createQuery(query)).doesNotThrowAnyException();
    }
  }
}
