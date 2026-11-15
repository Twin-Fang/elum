package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.credit.core.CreditRefundHoldResolution;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditRefundHold;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPurchaseRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditRefundHoldRepository;
import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler;
import com.chuseok22.elumserver.license.core.ConsumableRefundResult;
import com.chuseok22.elumserver.license.core.StoreRefundOrigin;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 크레딧 구매 환불: 회수(알림·재확인·관리자), 환불 취소 재적립, 먼저 온 환불 보류 > 구매 확인 때 회수
 * 회수: 구매 기록 잠금 > 상태 확인 > 계정 잠금 > 적립 묶음의 남은 양만 0 > 원장 1줄 > REFUNDED (이미 쓴 양은 되돌리지 않음)
 */
@Slf4j
@Service
public class CreditPurchaseRefundService implements StoreConsumableRefundHandler {

  private final CreditAccountService accountService;
  private final AiCreditPurchaseRepository purchaseRepository;
  private final AiCreditGrantRepository grantRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  private final AiCreditRefundHoldRepository holdRepository;
  private final Clock clock;

  @Autowired
  public CreditPurchaseRefundService(
    CreditAccountService accountService, AiCreditPurchaseRepository purchaseRepository,
    AiCreditGrantRepository grantRepository, AiCreditLedgerRepository ledgerRepository,
    AiCreditRefundHoldRepository holdRepository
  ) {
    this(accountService, purchaseRepository, grantRepository, ledgerRepository, holdRepository, Clock.systemDefaultZone());
  }

  CreditPurchaseRefundService(
    CreditAccountService accountService, AiCreditPurchaseRepository purchaseRepository,
    AiCreditGrantRepository grantRepository, AiCreditLedgerRepository ledgerRepository,
    AiCreditRefundHoldRepository holdRepository, Clock clock
  ) {
    this.accountService = accountService;
    this.purchaseRepository = purchaseRepository;
    this.grantRepository = grantRepository;
    this.ledgerRepository = ledgerRepository;
    this.holdRepository = holdRepository;
    this.clock = clock;
  }

  @Override
  @Transactional
  public ConsumableRefundOutcome refund(SubscriptionSource store, String transactionId, StoreRefundOrigin origin) {
    Optional<AiCreditPurchase> purchase = purchaseRepository.findByStoreAndTransactionIdForUpdate(store, transactionId);
    if (purchase.isEmpty()) {
      return holdUnknownRefund(store, transactionId, origin);
    }
    return revoke(purchase.get(), origin, null, null);
  }

  @Override
  @Transactional
  public ConsumableRefundOutcome reverseRefund(SubscriptionSource store, String transactionId) {
    AiCreditPurchase purchase = purchaseRepository.findByStoreAndTransactionIdForUpdate(store, transactionId).orElse(null);
    if (purchase == null) {
      return releaseHold(store, transactionId);
    }
    if (purchase.getStatus() != CreditPurchaseStatus.REFUNDED) {
      return new ConsumableRefundOutcome(ConsumableRefundResult.NOT_REFUNDED, purchase.getMemberId());
    }
    AiCreditAccount account = accountService.lockAccountById(purchase.getAccountId());
    LocalDateTime now = LocalDateTime.now(clock);
    int restored = restoreRecovered(purchase);
    if (restored > 0) {
      AiCreditLedger line = CreditAccountService.ledgerLine(account.getId(), CreditLedgerType.ADJUST, restored,
        accountService.balance(account, now).available());
      line.setGrantId(purchase.getGrantId());
      line.setReason("크레딧 구매 환불 취소 재적립 " + purchase.getProductId());
      ledgerRepository.save(line);
    }
    purchase.setStatus(CreditPurchaseStatus.GRANTED);
    purchase.setRefundedAt(null);
    purchase.setRecoveredCredits(0);
    purchase.setRefundOrigin(null);
    purchaseRepository.save(purchase);
    log.info("[credit purchase] refund reversed : store={}, product={}, restored={}", store, purchase.getProductId(), restored);
    return new ConsumableRefundOutcome(ConsumableRefundResult.REVERSED, purchase.getMemberId());
  }

  @Override
  @Transactional(readOnly = true)
  public List<String> findGrantedTransactionIds(SubscriptionSource store, LocalDateTime since) {
    return purchaseRepository.findTransactionIds(store, CreditPurchaseStatus.GRANTED, since);
  }

  /// 관리자 건별 회수: 없는 구매면 UNKNOWN, 이미 환불이면 ALREADY_REFUNDED (원장 actor·사유에 관리자 남김)
  @Transactional
  public ConsumableRefundOutcome revokeByAdmin(String purchaseId, String actor, String reason) {
    return purchaseRepository.findByIdForUpdate(purchaseId)
      .map(purchase -> revoke(purchase, StoreRefundOrigin.ADMIN, actor, reason))
      .orElseGet(() -> new ConsumableRefundOutcome(ConsumableRefundResult.UNKNOWN, null));
  }

  /// 구매 적립 직후 같은 트랜잭션에서: 보류한 환불이 있으면 바로 회수 (회수했으면 true)
  @Transactional(propagation = Propagation.MANDATORY)
  public boolean applyHeldRefund(AiCreditPurchase purchase) {
    Optional<AiCreditRefundHold> hold = holdRepository
      .findByStoreAndTransactionId(purchase.getStore(), purchase.getTransactionId())
      .filter(AiCreditRefundHold::isPending);
    if (hold.isEmpty()) {
      return false;
    }
    revoke(purchase, StoreRefundOrigin.STORE_NOTIFICATION, null, null);
    resolveHold(hold.get(), CreditRefundHoldResolution.APPLIED);
    log.info("[credit purchase] held refund applied on verify : store={}, product={}",
      purchase.getStore(), purchase.getProductId());
    return true;
  }

  // 회수 1건: 이미 환불이면 그대로 > 남은 양 0 > 원장 > REFUNDED·회수량·계기
  private ConsumableRefundOutcome revoke(AiCreditPurchase purchase, StoreRefundOrigin origin, String actor, String adminReason) {
    if (purchase.getStatus() == CreditPurchaseStatus.REFUNDED) {
      return new ConsumableRefundOutcome(ConsumableRefundResult.ALREADY_REFUNDED, purchase.getMemberId());
    }
    AiCreditAccount account = accountService.lockAccountById(purchase.getAccountId());
    LocalDateTime now = LocalDateTime.now(clock);
    int recovered = recoverRemaining(purchase);
    if (recovered > 0) {
      int available = accountService.balance(account, now).available();
      AiCreditLedger line = CreditAccountService.ledgerLine(account.getId(), CreditLedgerType.ADJUST, -recovered, available);
      line.setGrantId(purchase.getGrantId());
      line.setReason(revokeReasonOf(purchase, origin, adminReason));
      if (actor != null) {
        line.setActor(actor);
      }
      ledgerRepository.save(line);
    }
    purchase.setStatus(CreditPurchaseStatus.REFUNDED);
    purchase.setRefundedAt(now);
    purchase.setRecoveredCredits(recovered);
    purchase.setRefundOrigin(origin);
    purchaseRepository.save(purchase);
    log.info("[credit purchase] refunded : store={}, product={}, origin={}, recovered={}, credits={}",
      purchase.getStore(), purchase.getProductId(), origin, recovered, purchase.getCredits());
    return new ConsumableRefundOutcome(ConsumableRefundResult.REVOKED, purchase.getMemberId());
  }

  // 모르는 거래: 스토어 알림만 보류 (재확인·관리자는 이미 아는 거래만 다룸)
  private ConsumableRefundOutcome holdUnknownRefund(SubscriptionSource store, String transactionId, StoreRefundOrigin origin) {
    if (origin != StoreRefundOrigin.STORE_NOTIFICATION) {
      return new ConsumableRefundOutcome(ConsumableRefundResult.UNKNOWN, null);
    }
    AiCreditRefundHold hold = holdRepository.findByStoreAndTransactionId(store, transactionId).orElseGet(AiCreditRefundHold::new);
    hold.setStore(store);
    hold.setTransactionId(transactionId);
    hold.setReceivedAt(LocalDateTime.now(clock));
    // 환불 취소로 풀렸던 보류에 다시 환불이 오면 다시 대기
    hold.setResolution(null);
    hold.setResolvedAt(null);
    holdRepository.save(hold);
    log.info("[credit purchase] refund held : unknown transaction : store={}", store);
    return new ConsumableRefundOutcome(ConsumableRefundResult.HELD, null);
  }

  // 모르는 거래의 환불 취소: 대기 중인 보류가 있으면 풂
  private ConsumableRefundOutcome releaseHold(SubscriptionSource store, String transactionId) {
    Optional<AiCreditRefundHold> hold = holdRepository.findByStoreAndTransactionId(store, transactionId)
      .filter(AiCreditRefundHold::isPending);
    if (hold.isEmpty()) {
      return new ConsumableRefundOutcome(ConsumableRefundResult.NOT_REFUNDED, null);
    }
    resolveHold(hold.get(), CreditRefundHoldResolution.REVERSED);
    log.info("[credit purchase] held refund released : store={}", store);
    return new ConsumableRefundOutcome(ConsumableRefundResult.HOLD_RELEASED, null);
  }

  private void resolveHold(AiCreditRefundHold hold, CreditRefundHoldResolution resolution) {
    hold.setResolution(resolution);
    hold.setResolvedAt(LocalDateTime.now(clock));
    holdRepository.save(hold);
  }

  // 적립 묶음의 남은 양만 0 으로 (회수한 양을 돌려줌)
  private int recoverRemaining(AiCreditPurchase purchase) {
    AiCreditGrant grant = grantOf(purchase);
    if (grant == null || grant.getRemaining() <= 0) {
      return 0;
    }
    int recovered = grant.getRemaining();
    grant.setRemaining(0);
    grantRepository.save(grant);
    return recovered;
  }

  // 회수한 양을 같은 묶음에 되돌림 (묶음 지급량을 넘지 않게)
  private int restoreRecovered(AiCreditPurchase purchase) {
    AiCreditGrant grant = grantOf(purchase);
    if (grant == null || purchase.getRecoveredCredits() <= 0) {
      return 0;
    }
    int restored = Math.min(purchase.getRecoveredCredits(), grant.getAmount() - grant.getRemaining());
    grant.setRemaining(grant.getRemaining() + restored);
    grantRepository.save(grant);
    return restored;
  }

  private AiCreditGrant grantOf(AiCreditPurchase purchase) {
    return purchase.getGrantId() == null ? null : grantRepository.findById(purchase.getGrantId()).orElse(null);
  }

  // 원장 사유: 계기별 (관리자는 입력 사유를 덧붙임)
  private static String revokeReasonOf(AiCreditPurchase purchase, StoreRefundOrigin origin, String adminReason) {
    String reason = "크레딧 구매 환불 회수 " + purchase.getProductId() + " (" + origin.getLabel() + ")";
    return adminReason == null || adminReason.isBlank() ? reason : reason + ": " + adminReason.trim();
  }
}
