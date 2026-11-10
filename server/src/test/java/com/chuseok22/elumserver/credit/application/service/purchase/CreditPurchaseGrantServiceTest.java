package com.chuseok22.elumserver.credit.application.service.purchase;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.dto.response.CreditPurchaseResponse;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditTestStore;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPeriodUnit;
import com.chuseok22.elumserver.credit.core.CreditPurchaseResultStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPurchaseRepository;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import jakarta.persistence.EntityManager;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.PlatformTransactionManager;

/// 크레딧 구매 적립: 같은 거래는 한 번만, 다른 회원 거래·꾸러미 밖 상품은 거절, 구매분은 만료 없음
@ExtendWith(MockitoExtension.class)
class CreditPurchaseGrantServiceTest {

  private static final String TRANSACTION_ID = "2000000000000001";
  private static final String PRODUCT_ID = "elum_credit_150";
  /// 2026-11-10(화) 15:00 한국 시각 — 2026-W46
  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-11-10T06:00:00Z"), ZoneId.of("Asia/Seoul"));
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
  private AiCreditPurchaseRepository purchaseRepository;
  @Mock
  private EntityManager entityManager;

  private final CreditTestStore store = new CreditTestStore();
  private CreditAccountService accountService;
  private CreditPurchaseGrantService service;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    store.wirePurchases(purchaseRepository);
    accountService = new CreditAccountService(accountRepository, grantRepository, jobRepository, ledgerRepository,
      CreditTestStore.weekPeriodSettings(), entityManager);
    SystemConfigService config = mock(SystemConfigService.class);
    lenient().when(config.getBoolean(ConfigKey.CREDIT_PACK_SALE_ENABLED)).thenReturn(true);
    lenient().when(config.getString(ConfigKey.CREDIT_PACK_PRODUCTS)).thenReturn(ConfigKey.CREDIT_PACK_PRODUCTS.getDefaultValue());
    service = new CreditPurchaseGrantService(new CreditPackCatalog(config), accountService, purchaseRepository,
      grantRepository, ledgerRepository, mock(PlatformTransactionManager.class), CLOCK);
    store.account("acc-a", "member-a");
    store.account("acc-b", "member-b");
  }

  private CreditPurchaseResponse buy(String memberId, String transactionId) {
    return service.grantOnce(memberId, SubscriptionSource.APPLE_IAP, transactionId, PRODUCT_ID);
  }

  @Test
  @DisplayName("같은 거래가 두 번 오면 한 번만 적립한다 — 두 번 적립되면 결제 한 번에 크레딧이 두 배가 된다")
  void sameTransactionTwice_grantsOnce() {
    CreditPurchaseResponse first = buy("member-a", TRANSACTION_ID);
    CreditPurchaseResponse second = buy("member-a", TRANSACTION_ID);

    assertThat(first.status()).isEqualTo(CreditPurchaseResultStatus.GRANTED);
    assertThat(first.grantedCredits()).isEqualTo(150);
    assertThat(first.available()).isEqualTo(150);
    assertThat(second.status()).isEqualTo(CreditPurchaseResultStatus.ALREADY_GRANTED);
    assertThat(second.available()).isEqualTo(150);
    assertThat(store.grants).hasSize(1);
    assertThat(store.purchases).hasSize(1);
    assertThat(store.ledgerOf(CreditLedgerType.GRANT)).singleElement().satisfies(line -> assertThat(line.getDelta()).isEqualTo(150));
  }

  @Test
  @DisplayName("적립 묶음은 구매 출처에 만료가 없고 거래 id 를 근거로 남긴다")
  void grant_isPurchaseSourceWithoutExpiry() {
    buy("member-a", TRANSACTION_ID);

    assertThat(store.grants).singleElement().satisfies(grant -> {
      assertThat(grant.getSource()).isEqualTo(CreditGrantSource.PURCHASE);
      assertThat(grant.getAmount()).isEqualTo(150);
      assertThat(grant.getExpiresAt()).isNull();
      assertThat(grant.getRefId()).isEqualTo(TRANSACTION_ID);
    });
  }

  @Test
  @DisplayName("다른 회원에 이미 적립된 거래는 거절한다 — 남의 결제로 크레딧을 받을 수 없다")
  void transactionOfOtherMember_isRejected() {
    buy("member-a", TRANSACTION_ID);

    assertErrorCode(() -> buy("member-b", TRANSACTION_ID), ErrorCode.CREDIT_PURCHASE_OWNED_BY_OTHER_MEMBER);
    assertThat(store.grants).hasSize(1);
    assertThat(store.grants.get(0).getAccountId()).isEqualTo("acc-a");
  }

  @Test
  @DisplayName("두 회원이 같은 새 거래를 동시에 보내 유니크에 걸리면 먼저 쓴 쪽만 받는다")
  void concurrentNewTransaction_uniqueConflict_secondMemberRejected() {
    AiCreditPurchase winner = new AiCreditPurchase();
    winner.setStore(SubscriptionSource.APPLE_IAP);
    winner.setTransactionId(TRANSACTION_ID);
    winner.setAccountId("acc-a");
    winner.setCredits(150);
    // 첫 조회는 비어 있고(아직 커밋 전) 저장에서 유니크 충돌, 재시도 때는 먼저 쓴 기록이 보인다
    when(purchaseRepository.findByStoreAndTransactionId(SubscriptionSource.APPLE_IAP, TRANSACTION_ID))
      .thenReturn(Optional.empty(), Optional.of(winner));
    when(purchaseRepository.saveAndFlush(org.mockito.ArgumentMatchers.any(AiCreditPurchase.class)))
      .thenThrow(new DataIntegrityViolationException("uk_ai_credit_purchase_transaction"));

    assertErrorCode(() -> buy("member-b", TRANSACTION_ID), ErrorCode.CREDIT_PURCHASE_OWNED_BY_OTHER_MEMBER);
  }

  @Test
  @DisplayName("꾸러미 목록에 없는 상품은 적립하지 않는다 — 설정에 없는 상품 ID 로 임의의 크레딧을 만들 수 없다")
  void productOutsidePacks_isRejected() {
    assertErrorCode(
      () -> service.grantOnce("member-a", SubscriptionSource.APPLE_IAP, TRANSACTION_ID, "elum_pro_monthly"),
      ErrorCode.SUBSCRIPTION_PRODUCT_NOT_ALLOWED);
    assertThat(store.grants).isEmpty();
    assertThat(store.purchases).isEmpty();
  }

  @Test
  @DisplayName("구매분은 주기가 바뀌어도 만료되지 않고, 이번 주기 지급과 따로 남는다")
  void purchasedGrant_survivesPeriodChange() {
    buy("member-a", TRANSACTION_ID);
    AiCreditPolicy policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(1);
    policy.setEnabled(true);
    policy.setWeeklyGrantJson("{\"FREE\":10,\"PRO\":100}");
    AiCreditAccount account = store.accounts.get(0);

    // 3주 뒤 · 두 달 뒤 지급 보장(만료 정리 포함)
    accountService.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW.plusWeeks(3));
    accountService.ensureWeeklyGrant(account, policy, PlanType.FREE, NOW.plusMonths(2));

    AiCreditGrant purchased = store.grants.stream()
      .filter(grant -> grant.getSource() == CreditGrantSource.PURCHASE).findFirst().orElseThrow();
    assertThat(purchased.getRemaining()).isEqualTo(150);
    assertThat(store.ledgerOf(CreditLedgerType.EXPIRE)).extracting(line -> line.getGrantId())
      .doesNotContain(purchased.getId());
    assertThat(accountService.balance(account, NOW.plusMonths(2)).available()).isEqualTo(160);
  }

  @Test
  @DisplayName("달 주기로 바뀌어도 구매분은 그대로다")
  void purchasedGrant_survivesSwitchToMonth() {
    buy("member-a", TRANSACTION_ID);
    CreditAccountService monthService = new CreditAccountService(accountRepository, grantRepository, jobRepository,
      ledgerRepository, CreditTestStore.periodSettingsOf(CreditPeriodUnit.MONTH), entityManager);
    AiCreditPolicy policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(1);
    policy.setEnabled(true);
    policy.setWeeklyGrantJson("{\"FREE\":10,\"PRO\":100}");

    monthService.ensureWeeklyGrant(store.accounts.get(0), policy, PlanType.FREE, NOW.plusMonths(1));

    assertThat(monthService.balance(store.accounts.get(0), NOW.plusMonths(1)).available()).isEqualTo(160);
  }

  private static void assertErrorCode(Runnable call, ErrorCode errorCode) {
    assertThatThrownBy(call::run)
      .isInstanceOfSatisfying(CustomException.class, e -> assertThat(e.getErrorCode()).isEqualTo(errorCode));
  }
}
