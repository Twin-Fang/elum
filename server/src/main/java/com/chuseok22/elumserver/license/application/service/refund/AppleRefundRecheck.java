package com.chuseok22.elumserver.license.application.service.refund;

import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler;
import com.chuseok22.elumserver.license.application.service.store.StoreLogValues;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings.AppleServerApiCredentials;
import com.chuseok22.elumserver.license.application.service.store.StoreTemporarilyUnavailableException;
import com.chuseok22.elumserver.license.application.service.store.StoreVerifyRejectedException;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.StoreRefundCheckFailureReason;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.entity.StoreRefundCheckRun;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseRepository;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier.AppleVerifyContext;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSubscriptionStatusClient;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * App Store 환불 재확인: 켜짐·키 확인 > 크레딧 구매 거래 조회 > Pro 구독 마지막 거래 조회 > revocationDate 있으면 회수
 * 거래마다 Server API 1회 (서명 다시 검증). 거래별 조회 실패는 건너뛰고 다음 거래, 하나라도 실패하면 TRANSACTION_LOOKUP_FAILED
 */
@Slf4j
@Component
public class AppleRefundRecheck {

  // 확인할 크레딧 구매 기간 (Apple 환불 요청 기한 여유 포함)
  static final Duration CONSUMABLE_LOOKBACK = Duration.ofDays(180);
  /// 거래 이력 종류
  static final String RECHECK_EVENT_TYPE = "RECHECK_REVOCATION";
  private static final Set<StorePurchaseState> ENTITLED_STATES = Set.of(StorePurchaseState.ACTIVE, StorePurchaseState.IN_GRACE_PERIOD);

  private final StoreSubscriptionSettings settings;
  private final AppleSubscriptionStatusClient apiClient;
  private final AppleSignedDataVerifier verifier;
  private final StorePurchaseRepository storePurchaseRepository;
  private final StoreConsumableRefundHandler consumableRefundHandler;
  private final RefundRecheckRevoker revoker;
  private final Clock clock;

  @Autowired
  public AppleRefundRecheck(
    StoreSubscriptionSettings settings, AppleSubscriptionStatusClient apiClient, AppleSignedDataVerifier verifier,
    StorePurchaseRepository storePurchaseRepository, StoreConsumableRefundHandler consumableRefundHandler,
    RefundRecheckRevoker revoker
  ) {
    this(settings, apiClient, verifier, storePurchaseRepository, consumableRefundHandler, revoker, Clock.systemDefaultZone());
  }

  AppleRefundRecheck(
    StoreSubscriptionSettings settings, AppleSubscriptionStatusClient apiClient, AppleSignedDataVerifier verifier,
    StorePurchaseRepository storePurchaseRepository, StoreConsumableRefundHandler consumableRefundHandler,
    RefundRecheckRevoker revoker, Clock clock
  ) {
    this.settings = settings;
    this.apiClient = apiClient;
    this.verifier = verifier;
    this.storePurchaseRepository = storePurchaseRepository;
    this.consumableRefundHandler = consumableRefundHandler;
    this.revoker = revoker;
    this.clock = clock;
  }

  /// 1회 실행: 결과 건수·실패 사유를 run 에 채움 (저장은 부르는 쪽)
  public void run(StoreRefundCheckRun run) {
    if (!settings.isAppleEnabled()) {
      run.recordFailure(StoreRefundCheckFailureReason.STORE_DISABLED);
      return;
    }
    AppleServerApiCredentials credentials = settings.appleServerApiCredentials();
    if (credentials == null) {
      run.recordFailure(StoreRefundCheckFailureReason.CREDENTIALS_NOT_CONFIGURED);
      return;
    }
    LookupScope scope = new LookupScope(credentials, settings.appleVerifyContext());
    checkConsumables(run, scope);
    checkSubscriptions(run, scope);
  }

  // 최근 180일 회수 전 크레딧 구매: 운영 > (테스트 결제 허용 시) Sandbox 순서로 조회
  private void checkConsumables(StoreRefundCheckRun run, LookupScope scope) {
    List<String> transactionIds = consumableRefundHandler.findGrantedTransactionIds(
      SubscriptionSource.APPLE_IAP, LocalDateTime.now(clock).minus(CONSUMABLE_LOOKBACK));
    List<StoreEnvironment> environments = scope.context().isSandboxAllowed()
      ? List.of(StoreEnvironment.PRODUCTION, StoreEnvironment.SANDBOX) : List.of(StoreEnvironment.PRODUCTION);
    run.addChecked(transactionIds.size());
    for (String transactionId : transactionIds) {
      checkOne(run, transactionId, environments, scope,
        () -> revoker.revokeConsumable(SubscriptionSource.APPLE_IAP, transactionId, RECHECK_EVENT_TYPE));
    }
  }

  // Pro 를 주는 구독: 마지막 거래를 그 구독 환경에서 조회
  private void checkSubscriptions(StoreRefundCheckRun run, LookupScope scope) {
    List<StorePurchase> purchases = storePurchaseRepository
      .findByStoreAndStateInAndRevokedAtIsNull(SubscriptionSource.APPLE_IAP, ENTITLED_STATES).stream()
      .filter(purchase -> purchase.getLatestTransactionId() != null)
      .toList();
    run.addChecked(purchases.size());
    for (StorePurchase purchase : purchases) {
      checkOne(run, purchase.getLatestTransactionId(), List.of(purchase.getEnvironment()), scope,
        () -> revoker.revokeSubscription(SubscriptionSource.APPLE_IAP, purchase.getPurchaseKey(), RECHECK_EVENT_TYPE));
    }
  }

  // 거래 1건: 조회 > 회수 표시면 회수 (조회·회수 실패는 사유만 남기고 다음 거래)
  private void checkOne(
    StoreRefundCheckRun run, String transactionId, List<StoreEnvironment> environments, LookupScope scope, RevokeCall revokeCall
  ) {
    try {
      if (!isRevokedInApple(transactionId, environments, scope)) {
        return;
      }
      run.addRefunded(1);
      if (revokeCall.revoke()) {
        run.addRevoked(1);
      }
    } catch (StoreTemporarilyUnavailableException | StoreVerifyRejectedException e) {
      log.warn("[refund recheck] apple lookup failed : transaction={}, cause={}", StoreLogValues.mask(transactionId), e.getMessage());
      run.recordFailure(StoreRefundCheckFailureReason.TRANSACTION_LOOKUP_FAILED);
    } catch (RuntimeException e) {
      log.warn("[refund recheck] apple revoke failed : transaction={}, cause={}",
        StoreLogValues.mask(transactionId), e.getClass().getSimpleName());
      run.recordFailure(StoreRefundCheckFailureReason.UNEXPECTED_ERROR);
    }
  }

  // 환경 순서대로 조회해 처음 찾은 거래의 revocationDate 유무 (어디에도 없으면 false)
  private boolean isRevokedInApple(String transactionId, List<StoreEnvironment> environments, LookupScope scope) {
    for (StoreEnvironment environment : environments) {
      Optional<String> signedTransaction = apiClient.fetchSignedTransaction(
        transactionId, environment, scope.context().bundleId(), scope.credentials());
      if (signedTransaction.isPresent()) {
        JWSTransactionDecodedPayload transaction = verifier.verifyTransactionIn(signedTransaction.get(), environment, scope.context());
        return transaction.getRevocationDate() != null;
      }
    }
    return false;
  }

  private record LookupScope(AppleServerApiCredentials credentials, AppleVerifyContext context) {

  }

  @FunctionalInterface
  private interface RevokeCall {

    boolean revoke();
  }
}
