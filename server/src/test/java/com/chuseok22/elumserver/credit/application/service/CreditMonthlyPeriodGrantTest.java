package com.chuseok22.elumserver.credit.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPeriodUnit;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.license.core.PlanType;
import jakarta.persistence.EntityManager;
import java.time.LocalDateTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 달 주기 지급: 설정이 MONTH 일 때 지급·만료·전환이 한 달 단위로 맞는가
@ExtendWith(MockitoExtension.class)
class CreditMonthlyPeriodGrantTest {

  private static final String ACCOUNT_ID = "acc1";
  /// 2026-11-10(화) 15:00 — 2026-M11 (11-01 ~ 12-01), 주로는 2026-W46
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 10, 15, 0);

  @Mock
  private AiCreditAccountRepository accountRepository;
  @Mock
  private AiCreditGrantRepository grantRepository;
  @Mock
  private AiCreditJobRepository jobRepository;
  @Mock
  private AiCreditLedgerRepository ledgerRepository;
  @Mock
  private EntityManager entityManager;

  private final CreditTestStore store = new CreditTestStore();
  private AiCreditPolicy policy;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(1);
    policy.setEnabled(true);
    policy.setWeeklyGrantJson("{\"FREE\":10,\"PRO\":100}");
  }

  private CreditAccountService serviceWith(CreditPeriodUnit unit) {
    return new CreditAccountService(accountRepository, grantRepository, jobRepository, ledgerRepository,
      CreditTestStore.periodSettingsOf(unit), entityManager);
  }

  @Test
  @DisplayName("MONTH 면 이번 달 1일 0시 ~ 다음 달 1일 0시 지급을 달 키로 만든다 — 주 단위로 만들면 월 지급이 매주 다시 생긴다")
  void monthlyGrant_usesMonthPeriodAndKey() {
    AiCreditAccount account = store.account(ACCOUNT_ID, "m1");

    serviceWith(CreditPeriodUnit.MONTH).ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);

    assertThat(store.grants).singleElement().satisfies(grant -> {
      assertThat(grant.getSource()).isEqualTo(CreditGrantSource.WEEKLY);
      assertThat(grant.getAmount()).isEqualTo(10);
      assertThat(grant.getPeriodKey()).isEqualTo("2026-M11");
      assertThat(grant.getValidFrom()).isEqualTo(LocalDateTime.of(2026, 11, 1, 0, 0));
      assertThat(grant.getExpiresAt()).isEqualTo(LocalDateTime.of(2026, 12, 1, 0, 0));
    });
  }

  @Test
  @DisplayName("같은 달에 몇 번을 조회해도 지급은 한 번이다 — 두 번 지급되면 크레딧이 공짜로 늘어난다")
  void monthlyGrant_notDuplicatedInSameMonth() {
    AiCreditAccount account = store.account(ACCOUNT_ID, "m1");
    CreditAccountService service = serviceWith(CreditPeriodUnit.MONTH);

    service.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);
    service.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW.plusWeeks(2));
    service.ensureWeeklyGrant(account, policy, PlanType.FREE, LocalDateTime.of(2026, 11, 30, 23, 59));

    assertThat(store.grants).hasSize(1);
    assertThat(store.ledgerOf(CreditLedgerType.GRANT)).hasSize(1);
  }

  @Test
  @DisplayName("다음 달 1일 0시에 지난 달 남은 양은 EXPIRE 로 사라지고 새 달 지급이 생긴다 — 이월되면 달 한도가 무의미해진다")
  void newMonth_expiresLastMonthAndGrantsAgain() {
    AiCreditAccount account = store.account(ACCOUNT_ID, "m1");
    CreditAccountService service = serviceWith(CreditPeriodUnit.MONTH);
    service.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);
    store.grants.get(0).setRemaining(4);

    service.ensureWeeklyGrant(account, policy, PlanType.FREE, LocalDateTime.of(2026, 12, 1, 0, 0));

    assertThat(store.grants).extracting(AiCreditGrant::getPeriodKey).containsExactly("2026-M11", "2026-M12");
    assertThat(store.grants.get(0).getRemaining()).isZero();
    assertThat(store.ledgerOf(CreditLedgerType.EXPIRE)).singleElement().extracting(line -> line.getDelta()).isEqualTo(-4);
    assertThat(store.grants.get(1).getRemaining()).isEqualTo(10);
  }

  @Test
  @DisplayName("WEEK 에서 MONTH 로 바꾼 직후 받은 주간 지급분은 유효한 채로 남고 이번 달 지급이 한 번 새로 생긴다")
  void switchWeekToMonth_keepsWeeklyGrantAndAddsOneMonthlyGrant() {
    AiCreditAccount account = store.account(ACCOUNT_ID, "m1");
    // 전환 전에 이번 주(2026-W46, 11-09 ~ 11-16) 지급을 받아 6 이 남았다
    AiCreditGrant thisWeek = store.weekly(ACCOUNT_ID, NOW, 100, 6);
    thisWeek.setPeriodKey("2026-W46");
    CreditAccountService monthService = serviceWith(CreditPeriodUnit.MONTH);

    monthService.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);
    monthService.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW.plusHours(1));

    assertThat(thisWeek.getRemaining()).isEqualTo(6);
    assertThat(store.ledgerOf(CreditLedgerType.EXPIRE)).isEmpty();
    assertThat(store.grants).extracting(AiCreditGrant::getPeriodKey).containsExactly("2026-W46", "2026-M11");
    // 주간 6 + 이번 달 10 = 16 을 쓸 수 있고, 월 지급량은 달 지급 하나만 센다
    CreditBalance balance = monthService.balance(account, NOW);
    assertThat(balance.available()).isEqualTo(16);
    assertThat(balance.weeklyGrant()).isEqualTo(10);
    assertThat(balance.period().key()).isEqualTo("2026-M11");
    // 주간 지급분은 원래 만료(다음 월요일)가 지나면 그때 정리된다
    monthService.ensureWeeklyGrant(account, policy, PlanType.FREE, LocalDateTime.of(2026, 11, 16, 0, 0));
    assertThat(thisWeek.getRemaining()).isZero();
  }

  @Test
  @DisplayName("MONTH 에서 WEEK 로 되돌려도 이번 달 지급분은 달 끝까지 유효하고 이번 주 지급이 한 번 새로 생긴다")
  void switchMonthToWeek_keepsMonthlyGrantAndAddsOneWeeklyGrant() {
    AiCreditAccount account = store.account(ACCOUNT_ID, "m1");
    CreditAccountService monthService = serviceWith(CreditPeriodUnit.MONTH);
    monthService.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);
    CreditAccountService weekService = serviceWith(CreditPeriodUnit.WEEK);

    weekService.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);
    weekService.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);

    assertThat(store.grants).extracting(AiCreditGrant::getPeriodKey).containsExactly("2026-M11", "2026-W46");
    assertThat(store.grants.get(0).getRemaining()).isEqualTo(10);
    assertThat(store.ledgerOf(CreditLedgerType.EXPIRE)).isEmpty();
  }

  @Test
  @DisplayName("달 중간에 Pro 가 되면 이번 달 지급을 Pro 몫까지 한 번만 올린다 — 주 주기와 같은 방식")
  void monthlyGrant_topsUpToProAmountOnce() {
    AiCreditAccount account = store.account(ACCOUNT_ID, "m1");
    CreditAccountService service = serviceWith(CreditPeriodUnit.MONTH);
    service.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);

    service.ensureWeeklyGrant(account, policy, PlanType.PRO, NOW.plusDays(1));
    service.ensureWeeklyGrant(account, policy, PlanType.PRO, NOW.plusDays(2));

    assertThat(store.grants).singleElement().satisfies(grant -> {
      assertThat(grant.getAmount()).isEqualTo(100);
      assertThat(grant.getRemaining()).isEqualTo(100);
    });
    assertThat(store.ledgerOf(CreditLedgerType.GRANT)).hasSize(2);
  }
}
