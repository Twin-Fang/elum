package com.chuseok22.elumserver.credit.application.service.purchase;

import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.apple.itunes.storekit.model.Type;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.dto.response.CreditPurchaseResponse;
import com.chuseok22.elumserver.license.application.service.store.AppleSubscriptionService;
import com.chuseok22.elumserver.license.application.service.store.StoreLogValues;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings;
import com.chuseok22.elumserver.license.application.service.store.StoreVerifyRejectedException;
import com.chuseok22.elumserver.license.core.StoreVerifyRejectReason;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier.Verified;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * App Store 크레딧 구매 확인: 판매 켜짐 > 서명·번들·환경(구독과 같은 검증기·설정) > 소모성 거래 > 취소 안 됨 > 꾸러미 상품 > 적립
 * Apple 서버를 다시 부르지 않는다 (서명된 거래가 근거, 환불은 서버 알림으로 회수)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AppleCreditPurchaseService {

  private final CreditPackCatalog packCatalog;
  private final StoreSubscriptionSettings settings;
  private final AppleSignedDataVerifier verifier;
  private final CreditPurchaseGrantService grantService;

  /**
   * @throws CustomException 판매·스토어 꺼짐 403, 서명·거래 종류·상품·다른 계정 거래 400
   */
  public CreditPurchaseResponse verify(String memberId, String signedTransaction) {
    if (!packCatalog.isSaleEnabled()) {
      throw new CustomException(ErrorCode.CREDIT_PACK_SALE_DISABLED);
    }
    if (!settings.isAppleEnabled()) {
      throw new CustomException(ErrorCode.SUBSCRIPTION_STORE_DISABLED);
    }
    try {
      JWSTransactionDecodedPayload transaction = verifiedConsumable(signedTransaction);
      return grantService.grantOnce(
        memberId, SubscriptionSource.APPLE_IAP, transaction.getTransactionId(), transaction.getProductId());
    } catch (StoreVerifyRejectedException e) {
      log.warn("[credit purchase] rejected 400 : {} : store=APPLE_IAP, member={}",
        e.getReason(), StoreLogValues.mask(memberId));
      throw new CustomException(e.getReason().getErrorCode());
    }
  }

  // 서명 검증 > 소모성·취소 안 됨·거래 id 확인
  private JWSTransactionDecodedPayload verifiedConsumable(String signedTransaction) {
    if (signedTransaction == null || signedTransaction.isBlank()
      || signedTransaction.length() > AppleSubscriptionService.SIGNED_DATA_MAX_LENGTH) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "signed data length");
    }
    Verified<JWSTransactionDecodedPayload> verified =
      verifier.verifyTransaction(signedTransaction.trim(), settings.appleVerifyContext());
    JWSTransactionDecodedPayload transaction = verified.payload();
    if (transaction.getType() != Type.CONSUMABLE) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.NOT_CONSUMABLE, String.valueOf(transaction.getType()));
    }
    if (transaction.getRevocationDate() != null) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.PURCHASE_NOT_FOUND, "revoked");
    }
    if (transaction.getTransactionId() == null || transaction.getTransactionId().isBlank()
      || transaction.getProductId() == null) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "transactionId");
    }
    return transaction;
  }
}
