package com.chuseok22.elumserver.credit.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.license.core.PlanType;
import jakarta.persistence.EntityManager;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CreditAccountServiceTest {

  private static final String MEMBER_ID = "m1";
  private static final String ACCOUNT_ID = "acc1";
  /// 2026-09-23(수) 15:00 — 2026-W39 (09-21 ~ 09-28).
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 23, 15, 0);
  private static final LocalDateTime LAST_WEEK = NOW.minusWeeks(1);

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
  private CreditAccountService service;
  private AiCreditPolicy policy;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    service = new CreditAccountService(accountRepository, grantRepository, jobRepository, ledgerRepository, entityManager);
    policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(1);
    policy.setEnabled(true);
    policy.setWeeklyGrantJson("{\"FREE\":100,\"PRO\":300}");
  }

  // --- 주간 지급 ---

  @Test
  @DisplayName("(a) 이번 주 지급이 없으면 WEEKLY 100 을 만들고 GRANT 원장을 남긴다")
  void ensureWeeklyGrant_createsWhenMissing() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);

    service.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);

    assertThat(store.grants).singleElement().satisfies(grant -> {
      assertThat(grant.getSource()).isEqualTo(CreditGrantSource.WEEKLY);
      assertThat(grant.getAmount()).isEqualTo(100);
      assertThat(grant.getRemaining()).isEqualTo(100);
      assertThat(grant.getPeriodKey()).isEqualTo("2026-W39");
      assertThat(grant.getValidFrom()).isEqualTo(LocalDateTime.of(2026, 9, 21, 0, 0));
      assertThat(grant.getExpiresAt()).isEqualTo(LocalDateTime.of(2026, 9, 28, 0, 0));
      assertThat(grant.getPolicyVersion()).isEqualTo(1);
    });
    assertThat(store.ledgerOf(CreditLedgerType.GRANT)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isEqualTo(100);
      assertThat(line.getBalanceAfter()).isEqualTo(100);
      assertThat(line.getGrantId()).isEqualTo(store.grants.get(0).getId());
    });
  }

  @Test
  @DisplayName("플랜별 지급량을 쓴다")
  void ensureWeeklyGrant_usesPlanAmount() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);

    service.ensureWeeklyGrant(account, policy, PlanType.PRO, NOW);

    assertThat(store.grants).singleElement().extracting(AiCreditGrant::getAmount).isEqualTo(300);
  }

  @Test
  @DisplayName("(b) 이번 주 지급이 이미 있으면 새로 만들지 않는다 — 다 써서 0 이어도")
  void ensureWeeklyGrant_idempotent() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);
    store.weekly(ACCOUNT_ID, NOW, 100, 0);

    service.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);

    assertThat(store.grants).hasSize(1);
    assertThat(store.ledger).isEmpty();
  }

  @Test
  @DisplayName("(c) 지난 주 WEEKLY 에 남은 30 은 0 으로 만들고 EXPIRE −30 을 남긴다 — 이월 없음")
  void ensureWeeklyGrant_expiresLastWeek() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);
    AiCreditGrant lastWeek = store.weekly(ACCOUNT_ID, LAST_WEEK, 100, 30);

    service.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);

    assertThat(lastWeek.getRemaining()).isZero();
    assertThat(store.ledgerOf(CreditLedgerType.EXPIRE)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isEqualTo(-30);
      assertThat(line.getGrantId()).isEqualTo(lastWeek.getId());
      assertThat(line.getBalanceAfter()).isZero();
    });
    // 만료가 먼저, 새 지급이 나중 — 잔액 흐름이 30 → 0 → 100 으로 읽힌다.
    List<CreditLedgerType> order = store.ledger.stream().map(AiCreditLedger::getType).toList();
    assertThat(order).containsExactly(CreditLedgerType.EXPIRE, CreditLedgerType.GRANT);
    assertThat(store.ledgerOf(CreditLedgerType.GRANT).get(0).getBalanceAfter()).isEqualTo(100);
  }

  @Test
  @DisplayName("기한이 지난 보너스도 남은 양을 EXPIRE 로 정리한다")
  void ensureWeeklyGrant_expiresEndedBonus() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);
    AiCreditGrant bonus = store.grant(ACCOUNT_ID, CreditGrantSource.ADMIN_BONUS, 10, 4,
      NOW.minusDays(10), NOW.minusDays(1));

    service.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW);

    assertThat(bonus.getRemaining()).isZero();
    assertThat(store.ledgerOf(CreditLedgerType.EXPIRE)).singleElement()
      .extracting(AiCreditLedger::getDelta).isEqualTo(-4);
  }

  // --- 잔액 ---

  @Test
  @DisplayName("(d) WEEKLY 72 + 무기한 보너스 30 − 예약 1 → 사용 가능 101, 보너스 30")
  void balance_sumsValidGrantsMinusReserved() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);
    store.weekly(ACCOUNT_ID, NOW, 100, 72);
    store.grant(ACCOUNT_ID, CreditGrantSource.ADMIN_BONUS, 30, 30, NOW.minusDays(1), null);
    store.reservedJob(ACCOUNT_ID, "k1", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusMinutes(1));
    AiCreditLedger consumed = new AiCreditLedger();
    consumed.setAccountId(ACCOUNT_ID);
    consumed.setType(CreditLedgerType.CONSUME);
    consumed.setDelta(-28);
    store.ledger.add(consumed);

    CreditBalance balance = service.balance(account, NOW);

    assertThat(balance.available()).isEqualTo(101);
    assertThat(balance.bonus()).isEqualTo(30);
    assertThat(balance.weeklyGrant()).isEqualTo(100);
    assertThat(balance.reserved()).isEqualTo(1);
    assertThat(balance.used()).isEqualTo(28);
    assertThat(balance.period().key()).isEqualTo("2026-W39");
  }

  @Test
  @DisplayName("(e) 기한이 지났거나 아직 시작 전인 묶음은 잔액에 넣지 않는다")
  void balance_excludesInvalidGrants() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);
    store.weekly(ACCOUNT_ID, NOW, 100, 10);
    store.grant(ACCOUNT_ID, CreditGrantSource.ADMIN_BONUS, 50, 50, NOW.minusDays(9), NOW.minusDays(1));
    store.grant(ACCOUNT_ID, CreditGrantSource.ADMIN_BONUS, 50, 50, NOW.plusDays(1), null);

    CreditBalance balance = service.balance(account, NOW);

    assertThat(balance.available()).isEqualTo(10);
    assertThat(balance.bonus()).isZero();
  }

  @Test
  @DisplayName("예약이 남은 양보다 많아도 사용 가능은 0 아래로 내려가지 않는다")
  void balance_neverNegative() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);
    store.weekly(ACCOUNT_ID, NOW, 100, 1);
    store.reservedJob(ACCOUNT_ID, "k1", CreditJobKind.ROUTINE_CREATE, 3, NOW);

    assertThat(service.balance(account, NOW).available()).isZero();
  }

  @Test
  @DisplayName("차감할 묶음은 만료 임박 순이고 무기한은 마지막이다")
  void spendableGrants_expiringFirst() {
    AiCreditGrant forever = store.grant(ACCOUNT_ID, CreditGrantSource.ADMIN_BONUS, 5, 5, NOW.minusDays(1), null);
    AiCreditGrant weekly = store.weekly(ACCOUNT_ID, NOW, 100, 2);
    AiCreditGrant tomorrow = store.grant(ACCOUNT_ID, CreditGrantSource.ADMIN_BONUS, 5, 5, NOW.minusDays(1), NOW.plusDays(1));

    assertThat(service.spendableGrants(ACCOUNT_ID, NOW)).containsExactly(tomorrow, weekly, forever);
  }

  // --- 계정 ---

  @Test
  @DisplayName("계정이 없으면 만들고 잠금 조회로 돌려준다")
  void lockAccount_createsWhenMissing() {
    AiCreditAccount locked = service.lockAccount(MEMBER_ID);

    assertThat(locked.getMemberId()).isEqualTo(MEMBER_ID);
    assertThat(store.accounts).hasSize(1);
    verify(accountRepository).findByIdForUpdate(locked.getId());
  }

  @Test
  @DisplayName("계정이 있으면 회원 id 로 바로 잠가 읽는다 — 잠그지 않은 조회를 먼저 하지 않는다")
  void lockAccount_locksExisting() {
    store.account(ACCOUNT_ID, MEMBER_ID);

    AiCreditAccount locked = service.lockAccount(MEMBER_ID);

    assertThat(locked.getId()).isEqualTo(ACCOUNT_ID);
    assertThat(store.accounts).hasSize(1);
    verify(accountRepository).findByMemberIdForUpdate(MEMBER_ID);
    // 잠그지 않은 조회가 먼저 엔티티를 올려 두면 잠금 조회가 그 옛 인스턴스를 돌려준다.
    verify(accountRepository, never()).findByMemberId(MEMBER_ID);
  }

  @Test
  @DisplayName("잠근 뒤 행을 다시 읽어 잠그기 전 상태(동결 전)를 돌려주지 않는다")
  void lockAccount_returnsStateReadAfterLock() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);
    // 잠그기 전에 1차 캐시에 올라온 인스턴스는 ACTIVE, 그 사이 관리자가 DB 에서 동결했다.
    doAnswer(inv -> {
      inv.<AiCreditAccount>getArgument(0).setStatus(CreditAccountStatus.FROZEN);
      return null;
    }).when(entityManager).refresh(account);

    AiCreditAccount locked = service.lockAccount(MEMBER_ID);

    assertThat(locked.isFrozen()).isTrue();
  }

  @Test
  @DisplayName("id 로 잠글 때도 잠근 뒤 다시 읽는다")
  void lockAccountById_refreshesAfterLock() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);

    service.lockAccountById(ACCOUNT_ID);

    InOrder order = inOrder(accountRepository, entityManager);
    order.verify(accountRepository).findByIdForUpdate(ACCOUNT_ID);
    order.verify(entityManager).refresh(account);
  }

  // --- 신원 ---

  @Test
  @DisplayName("(f) 신원 키는 provider:providerUserId 의 SHA-256 hex 64자 — V26 의 Postgres 식과 같은 값")
  void identityKey_deterministicSha256() {
    String key = CreditAccountService.identityKey("KAKAO", "kakao-9999");

    assertThat(key).hasSize(64).isEqualTo(CreditAccountService.identityKey("KAKAO", "kakao-9999"));
    assertThat(key).isEqualTo("6672bee5a9af278ca81072975b2a420419702079f9b6436cffe7f7ba682fcee0");
    assertThat(CreditAccountService.identityKey("NAVER", "kakao-9999")).isNotEqualTo(key);
  }

  @Test
  @DisplayName("재가입 — 떼어진 계정의 신원이 같으면 새 회원에 다시 붙인다(주간 사용량을 잇는다)")
  void linkIdentity_reattachesDetachedAccount() {
    AiCreditAccount detached = store.account(ACCOUNT_ID, null);
    detached.setIdentityKey("hash");

    service.linkIdentity("m2", "hash");

    assertThat(detached.getMemberId()).isEqualTo("m2");
    assertThat(store.accounts).hasSize(1);
  }

  @Test
  @DisplayName("처음 보는 신원이면 새 계정을 만든다")
  void linkIdentity_createsNew() {
    service.linkIdentity("m2", "hash");

    assertThat(store.accounts).singleElement().satisfies(account -> {
      assertThat(account.getMemberId()).isEqualTo("m2");
      assertThat(account.getIdentityKey()).isEqualTo("hash");
    });
  }

  @Test
  @DisplayName("신원 없이 먼저 만든 회원 계정에는 신원을 채운다")
  void linkIdentity_fillsMissingIdentity() {
    AiCreditAccount account = store.account(ACCOUNT_ID, MEMBER_ID);

    service.linkIdentity(MEMBER_ID, "hash");

    assertThat(account.getIdentityKey()).isEqualTo("hash");
    assertThat(store.accounts).hasSize(1);
  }

  @Test
  @DisplayName("다른 회원이 쓰고 있는 신원 계정은 빼앗지 않는다")
  void linkIdentity_doesNotStealLiveAccount() {
    AiCreditAccount other = store.account(ACCOUNT_ID, "other");
    other.setIdentityKey("hash");

    service.linkIdentity("m2", "hash");

    assertThat(other.getMemberId()).isEqualTo("other");
  }

  @Test
  @DisplayName("완전 삭제는 회원 식별자만 뗀다")
  void detachMember_delegates() {
    service.detachMember(MEMBER_ID);

    verify(accountRepository).detachMember(MEMBER_ID);
  }
}
