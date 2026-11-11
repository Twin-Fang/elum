package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.dto.response.CreditPurchaseResponse;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPurchaseResultStatus;
import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPurchaseRepository;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat.Pack;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.function.Supplier;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 스토어 거래 하나를 크레딧으로 적립: 꾸러미 확인 > 계정 잠금 > 기존 기록 확인 > 묶음·구매 기록·원장 저장
 * 적립 묶음은 PURCHASE · 만료 없음 · refId 가 거래 id. 같은 거래는 한 번만 (기록 확인 + 거래 유니크)
 */
@Slf4j
@Service
public class CreditPurchaseGrantService {

  private final CreditPackCatalog packCatalog;
  private final CreditAccountService accountService;
  private final AiCreditPurchaseRepository purchaseRepository;
  private final AiCreditGrantRepository grantRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  private final TransactionTemplate transaction;
  private final Clock clock;

  @Autowired
  public CreditPurchaseGrantService(
    CreditPackCatalog packCatalog, CreditAccountService accountService, AiCreditPurchaseRepository purchaseRepository,
    AiCreditGrantRepository grantRepository, AiCreditLedgerRepository ledgerRepository,
    PlatformTransactionManager transactionManager
  ) {
    this(packCatalog, accountService, purchaseRepository, grantRepository, ledgerRepository, transactionManager,
      Clock.systemDefaultZone());
  }

  CreditPurchaseGrantService(
    CreditPackCatalog packCatalog, CreditAccountService accountService, AiCreditPurchaseRepository purchaseRepository,
    AiCreditGrantRepository grantRepository, AiCreditLedgerRepository ledgerRepository,
    PlatformTransactionManager transactionManager, Clock clock
  ) {
    this.packCatalog = packCatalog;
    this.accountService = accountService;
    this.purchaseRepository = purchaseRepository;
    this.grantRepository = grantRepository;
    this.ledgerRepository = ledgerRepository;
    this.transaction = new TransactionTemplate(transactionManager);
    this.clock = clock;
  }

  /**
   * 트랜잭션 밖에서 부른다: 두 회원이 같은 새 거래를 동시에 보내 유니크에 걸리면 한 번 다시 해서 주인 불일치로 거절한다
   *
   * @throws CustomException 꾸러미에 없는 상품, 다른 회원에 적립된 거래
   */
  public CreditPurchaseResponse grantOnce(String memberId, SubscriptionSource store, String transactionId, String productId) {
    return retryOnceOnConflict(() -> transaction.execute(
      status -> grant(memberId, store, transactionId, productId)));
  }

  /// 구매 응답에 쓸 지금 사용 가능량 (계정이 없으면 0)
  public int availableOf(String memberId) {
    LocalDateTime now = LocalDateTime.now(clock);
    return accountService.findAccount(memberId).map(account -> accountService.balance(account, now).available()).orElse(0);
  }

  // 계정 잠금(MANDATORY) 때문에 호출하는 쪽이 만든 트랜잭션 안에서만 부른다
  private CreditPurchaseResponse grant(String memberId, SubscriptionSource store, String transactionId, String productId) {
    Pack pack = packCatalog.findPack(productId)
      .orElseThrow(() -> new CustomException(ErrorCode.SUBSCRIPTION_PRODUCT_NOT_ALLOWED));
    AiCreditAccount account = accountService.lockAccount(memberId);
    LocalDateTime now = LocalDateTime.now(clock);

    Optional<AiCreditPurchase> existing = purchaseRepository.findByStoreAndTransactionId(store, transactionId);
    if (existing.isPresent()) {
      return responseForExisting(existing.get(), account, memberId, now);
    }
    AiCreditGrant grant = new AiCreditGrant();
    grant.setAccountId(account.getId());
    grant.setSource(CreditGrantSource.PURCHASE);
    grant.setAmount(pack.credits());
    grant.setRemaining(pack.credits());
    grant.setValidFrom(now);
    // 구매 크레딧은 만료 없음 (null)
    grant.setExpiresAt(null);
    grant.setRefId(transactionId);
    int balanceBefore = accountService.balance(account, now).available();
    AiCreditGrant savedGrant = grantRepository.save(grant);

    AiCreditPurchase purchase = new AiCreditPurchase();
    purchase.setStore(store);
    purchase.setTransactionId(transactionId);
    purchase.setAccountId(account.getId());
    purchase.setMemberId(memberId);
    purchase.setProductId(productId);
    purchase.setCredits(pack.credits());
    purchase.setGrantId(savedGrant.getId());
    purchase.setStatus(CreditPurchaseStatus.GRANTED);
    // 유니크 충돌을 이 트랜잭션 안에서 바로 드러낸다
    purchaseRepository.saveAndFlush(purchase);

    AiCreditLedger line = CreditAccountService.ledgerLine(
      account.getId(), CreditLedgerType.GRANT, pack.credits(), balanceBefore + pack.credits());
    line.setGrantId(savedGrant.getId());
    line.setReason("크레딧 구매 " + productId);
    ledgerRepository.save(line);
    log.info("[credit purchase] granted : store={}, product={}, credits={}", store, productId, pack.credits());
    return new CreditPurchaseResponse(CreditPurchaseResultStatus.GRANTED, pack.credits(), balanceBefore + pack.credits());
  }

  // 같은 계정의 재시도면 ALREADY_GRANTED, 다른 계정이 먼저 받은 거래면 거절
  private CreditPurchaseResponse responseForExisting(
    AiCreditPurchase purchase, AiCreditAccount account, String memberId, LocalDateTime now
  ) {
    if (!purchase.getAccountId().equals(account.getId())) {
      log.warn("[credit purchase] rejected 400 : owned by other member : store={}, member={}",
        purchase.getStore(), memberId);
      throw new CustomException(ErrorCode.CREDIT_PURCHASE_OWNED_BY_OTHER_MEMBER);
    }
    return new CreditPurchaseResponse(
      CreditPurchaseResultStatus.ALREADY_GRANTED, purchase.getCredits(), accountService.balance(account, now).available());
  }

  private static <T> T retryOnceOnConflict(Supplier<T> call) {
    try {
      return call.get();
    } catch (DataIntegrityViolationException e) {
      log.info("[credit purchase] unique conflict, retry once");
      return call.get();
    }
  }
}
