package com.chuseok22.elumserver.credit.application.service.purchase;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditTestStore;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPurchaseRepository;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
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

/// 환불 회수: 남은 양만 회수, 이미 쓴 양은 건드리지 않음, 같은 환불은 한 번만
@ExtendWith(MockitoExtension.class)
class CreditPurchaseRefundServiceTest {

  private static final String TRANSACTION_ID = "2000000000000001";
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
  private CreditPurchaseRefundService service;
  private AiCreditAccount account;
  private AiCreditPurchase purchase;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    store.wirePurchases(purchaseRepository);
    accountService = new CreditAccountService(accountRepository, grantRepository, jobRepository, ledgerRepository,
      CreditTestStore.weekPeriodSettings(), entityManager);
    service = new CreditPurchaseRefundService(accountService, purchaseRepository, grantRepository, ledgerRepository, CLOCK);
    account = store.account("acc-a", "member-a");
  }

  // 50개를 사서 32개를 쓴 구매(남은 18) + 이번 주 지급 6 남음
  private AiCreditGrant givenPurchaseWithRemaining(int remaining) {
    AiCreditGrant grant = store.grant("acc-a", CreditGrantSource.PURCHASE, 50, remaining, NOW.minusDays(3), null);
    grant.setId("grant-purchase");
    store.weekly("acc-a", NOW, 10, 6);
    purchase = new AiCreditPurchase();
    purchase.setId("purchase-1");
    purchase.setStore(SubscriptionSource.APPLE_IAP);
    purchase.setTransactionId(TRANSACTION_ID);
    purchase.setAccountId("acc-a");
    purchase.setProductId("elum_credit_50");
    purchase.setCredits(50);
    purchase.setGrantId("grant-purchase");
    purchase.setStatus(CreditPurchaseStatus.GRANTED);
    store.purchases.add(purchase);
    return grant;
  }

  @Test
  @DisplayName("환불은 구매 묶음의 남은 양만 회수한다 — 이미 쓴 양을 음수로 만들면 다른 크레딧까지 줄어든다")
  void refund_recoversOnlyRemaining() {
    AiCreditGrant grant = givenPurchaseWithRemaining(18);

    service.refund(SubscriptionSource.APPLE_IAP, TRANSACTION_ID);

    assertThat(grant.getRemaining()).isZero();
    assertThat(grant.getAmount()).isEqualTo(50);
    assertThat(purchase.getStatus()).isEqualTo(CreditPurchaseStatus.REFUNDED);
    assertThat(purchase.getRefundedAt()).isEqualTo(NOW);
    assertThat(store.ledgerOf(CreditLedgerType.ADJUST)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isEqualTo(-18);
      assertThat(line.getBalanceAfter()).isEqualTo(6);
      assertThat(line.getGrantId()).isEqualTo("grant-purchase");
    });
    assertThat(accountService.balance(account, NOW).available()).isEqualTo(6);
  }

  @Test
  @DisplayName("같은 환불이 두 번 와도 한 번만 회수한다 — 두 번째가 원장을 또 쌓으면 잔액 기록이 어긋난다")
  void refundTwice_recoversOnce() {
    givenPurchaseWithRemaining(18);

    service.refund(SubscriptionSource.APPLE_IAP, TRANSACTION_ID);
    service.refund(SubscriptionSource.APPLE_IAP, TRANSACTION_ID);

    assertThat(store.ledgerOf(CreditLedgerType.ADJUST)).hasSize(1);
    assertThat(accountService.balance(account, NOW).available()).isEqualTo(6);
  }

  @Test
  @DisplayName("구매분을 다 쓴 뒤의 환불은 회수할 것이 없어 원장을 남기지 않고 기록만 환불로 바꾼다")
  void refund_afterFullyUsed_marksRefundedWithoutLedger() {
    AiCreditGrant grant = givenPurchaseWithRemaining(0);

    service.refund(SubscriptionSource.APPLE_IAP, TRANSACTION_ID);

    assertThat(grant.getRemaining()).isZero();
    assertThat(store.ledgerOf(CreditLedgerType.ADJUST)).isEmpty();
    assertThat(purchase.getStatus()).isEqualTo(CreditPurchaseStatus.REFUNDED);
    assertThat(accountService.balance(account, NOW).available()).isEqualTo(6);
  }

  @Test
  @DisplayName("모르는 거래의 환불 알림은 아무것도 바꾸지 않는다")
  void refund_unknownTransaction_doesNothing() {
    givenPurchaseWithRemaining(18);

    service.refund(SubscriptionSource.GOOGLE_IAP, "GPA.0000-0000-0000-00000");

    assertThat(purchase.getStatus()).isEqualTo(CreditPurchaseStatus.GRANTED);
    assertThat(store.ledger).isEmpty();
  }
}
