package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPurchaseRepository;
import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.Clock;
import java.time.LocalDateTime;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 크레딧 구매 환불 회수: 구매 기록 잠금 > 상태 확인 > 계정 잠금 > 적립 묶음의 남은 양만 0 > 원장 1줄 > 기록 REFUNDED
 * 이미 쓴 양은 되돌리지 않는다(잔액을 음수로 만들지 않음). 같은 환불이 두 번 와도 상태 확인으로 한 번만
 */
@Slf4j
@Service
public class CreditPurchaseRefundService implements StoreConsumableRefundHandler {

  private final CreditAccountService accountService;
  private final AiCreditPurchaseRepository purchaseRepository;
  private final AiCreditGrantRepository grantRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  private final Clock clock;

  @Autowired
  public CreditPurchaseRefundService(
    CreditAccountService accountService, AiCreditPurchaseRepository purchaseRepository,
    AiCreditGrantRepository grantRepository, AiCreditLedgerRepository ledgerRepository
  ) {
    this(accountService, purchaseRepository, grantRepository, ledgerRepository, Clock.systemDefaultZone());
  }

  CreditPurchaseRefundService(
    CreditAccountService accountService, AiCreditPurchaseRepository purchaseRepository,
    AiCreditGrantRepository grantRepository, AiCreditLedgerRepository ledgerRepository, Clock clock
  ) {
    this.accountService = accountService;
    this.purchaseRepository = purchaseRepository;
    this.grantRepository = grantRepository;
    this.ledgerRepository = ledgerRepository;
    this.clock = clock;
  }

  @Override
  @Transactional
  public void refund(SubscriptionSource store, String transactionId) {
    AiCreditPurchase purchase = purchaseRepository.findByStoreAndTransactionIdForUpdate(store, transactionId).orElse(null);
    if (purchase == null) {
      log.info("[credit purchase] refund ignored : unknown transaction : store={}", store);
      return;
    }
    if (purchase.getStatus() == CreditPurchaseStatus.REFUNDED) {
      return;
    }
    AiCreditAccount account = accountService.lockAccountById(purchase.getAccountId());
    LocalDateTime now = LocalDateTime.now(clock);
    int recovered = recoverRemaining(purchase);
    if (recovered > 0) {
      int available = accountService.balance(account, now).available();
      AiCreditLedger line = CreditAccountService.ledgerLine(account.getId(), CreditLedgerType.ADJUST, -recovered, available);
      line.setGrantId(purchase.getGrantId());
      line.setReason("크레딧 구매 환불 회수 " + purchase.getProductId());
      ledgerRepository.save(line);
    }
    purchase.setStatus(CreditPurchaseStatus.REFUNDED);
    purchase.setRefundedAt(now);
    purchaseRepository.save(purchase);
    log.info("[credit purchase] refunded : store={}, product={}, recovered={}, credits={}",
      store, purchase.getProductId(), recovered, purchase.getCredits());
  }

  // 적립 묶음의 남은 양만 0 으로 (회수한 양을 돌려줌)
  private int recoverRemaining(AiCreditPurchase purchase) {
    if (purchase.getGrantId() == null) {
      return 0;
    }
    AiCreditGrant grant = grantRepository.findById(purchase.getGrantId()).orElse(null);
    if (grant == null || grant.getRemaining() <= 0) {
      return 0;
    }
    int recovered = grant.getRemaining();
    grant.setRemaining(0);
    grantRepository.save(grant);
    return recovered;
  }
}
