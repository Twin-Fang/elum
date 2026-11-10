package com.chuseok22.elumserver.license.application.service.store;

import com.apple.itunes.storekit.model.Data;
import com.apple.itunes.storekit.model.JWSRenewalInfoDecodedPayload;
import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.apple.itunes.storekit.model.NotificationTypeV2;
import com.apple.itunes.storekit.model.ResponseBodyV2DecodedPayload;
import com.apple.itunes.storekit.model.Type;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.store.StorePurchaseApplier.StoreApplyOutcome;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings.AppleServerApiCredentials;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.StoreVerifyRejectReason;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier.AppleVerifyContext;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier.Verified;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSubscriptionStatusClient;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSubscriptionStatusClient.SignedSubscriptionStatus;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Objects;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * App Store 구독: 앱 검증 요청(StoreKit 2 서명 거래), App Store Server Notifications V2
 * 검증: 켜짐 > 서명 체인·번들·환경 > 자동 갱신 구독 > 허용 상품 > (API 키 있으면) Apple 에 최신 상태 다시 조회 > 반영
 * Apple 이 응답하지 않으면 PENDING (Pro 를 주지 않고, 앱 재시도·알림으로 확정)
 */
@Slf4j
@Service
public class AppleSubscriptionService {

  // StoreKit 2 JWS 는 3~5KB. 이보다 크면 형식 오류
  public static final int SIGNED_DATA_MAX_LENGTH = 16_384;
  private static final String EVENT_TYPE_SUBTYPE_DELIMITER = ".";

  private final StoreSubscriptionSettings settings;
  private final AppleSignedDataVerifier verifier;
  private final AppleSubscriptionStatusClient statusClient;
  private final StorePurchaseApplier applier;
  private final StoreConsumableRefundHandler consumableRefundHandler;
  private final Clock clock;

  @Autowired
  public AppleSubscriptionService(
    StoreSubscriptionSettings settings, AppleSignedDataVerifier verifier,
    AppleSubscriptionStatusClient statusClient, StorePurchaseApplier applier,
    StoreConsumableRefundHandler consumableRefundHandler
  ) {
    this(settings, verifier, statusClient, applier, consumableRefundHandler, Clock.systemDefaultZone());
  }

  AppleSubscriptionService(
    StoreSubscriptionSettings settings, AppleSignedDataVerifier verifier,
    AppleSubscriptionStatusClient statusClient, StorePurchaseApplier applier,
    StoreConsumableRefundHandler consumableRefundHandler, Clock clock
  ) {
    this.settings = settings;
    this.verifier = verifier;
    this.statusClient = statusClient;
    this.applier = applier;
    this.consumableRefundHandler = consumableRefundHandler;
    this.clock = clock;
  }

  /**
   * 앱 검증 요청: 거래 JWS(+ 갱신 정보 JWS) 검증 > 반영
   *
   * @throws CustomException 꺼짐 403, 거부 사유별 400
   */
  public StoreVerification verifyFromClient(String memberId, String signedTransaction, String signedRenewalInfo) {
    if (!settings.isAppleEnabled()) {
      throw new CustomException(ErrorCode.SUBSCRIPTION_STORE_DISABLED);
    }
    try {
      AppleVerifyContext context = contextOf();
      Verified<JWSTransactionDecodedPayload> transaction = verifier.verifyTransaction(requireSignedData(signedTransaction), context);
      StoreEnvironment environment = transaction.environment();
      // 구독·허용 상품이 아니면 Apple 에 묻기 전에 거부
      requireAllowedSubscription(transaction.payload());
      JWSRenewalInfoDecodedPayload renewal = isBlank(signedRenewalInfo)
        ? null : verifier.verifyRenewalInfo(requireSignedData(signedRenewalInfo), environment, context);
      LatestAppleState latest = latestFromApple(new LatestAppleState(transaction.payload(), renewal), environment, context);
      requireAllowedSubscription(latest.transaction());
      requireSameSubscription(latest.transaction(), latest.renewal());

      LocalDateTime now = LocalDateTime.now(clock);
      StoreSubscriptionSnapshot snapshot = AppleSubscriptionSnapshotMapper.toSnapshot(
        latest.transaction(), latest.renewal(), environment, null, null, null, now);
      StoreApplyOutcome outcome = StorePurchaseApplier.retryOnceOnConflict(() -> applier.apply(
        snapshot, memberId, StorePurchaseTrigger.CLIENT_VERIFY, StorePurchaseApplier.VERIFY_EVENT_TYPE, null));
      if (outcome.isRejected()) {
        throw new CustomException(ErrorCode.SUBSCRIPTION_OWNED_BY_OTHER_MEMBER);
      }
      return outcome.purchase() != null && outcome.purchase().isEntitled(now)
        ? StoreVerification.ACTIVE : StoreVerification.INACTIVE;
    } catch (StoreVerifyRejectedException e) {
      log.warn("[subscription verify] rejected 400 : {} : store=APPLE_IAP, member={}",
        e.getReason(), StoreLogValues.mask(memberId));
      throw new CustomException(e.getReason().getErrorCode());
    } catch (StoreTemporarilyUnavailableException e) {
      log.warn("[subscription verify] pending : store=APPLE_IAP, member={}, cause={}",
        StoreLogValues.mask(memberId), e.getMessage());
      return StoreVerification.PENDING;
    }
  }

  /**
   * App Store Server Notifications V2: signedPayload 검증 > 중복 확인 > 거래·갱신 정보 검증 > 반영
   * 서명 불일치 400, 꺼짐·Apple 확인 실패 503 (Apple 이 다시 보냄), 받을 필요 없는 알림 200
   */
  public StoreNotificationOutcome handleNotification(String signedPayload) {
    if (!settings.isAppleEnabled()) {
      return StoreNotificationOutcome.RETRY_LATER;
    }
    try {
      AppleVerifyContext context = contextOf();
      Verified<ResponseBodyV2DecodedPayload> notification = verifier.verifyNotification(requireSignedData(signedPayload), context);
      return applyNotification(notification.payload(), notification.environment(), context);
    } catch (StoreVerifyRejectedException e) {
      // Sandbox 알림인데 테스트 결제 허용이 꺼짐: Apple 이 계속 다시 보내지 않게 200
      if (e.getReason() == StoreVerifyRejectReason.ENVIRONMENT_NOT_ALLOWED) {
        log.info("[subscription notify] ignored : sandbox notification while sandbox disabled");
        return StoreNotificationOutcome.IGNORED;
      }
      log.warn("[subscription notify] rejected 400 : signature : store=APPLE_IAP, reason={}", e.getReason());
      return StoreNotificationOutcome.REJECTED;
    } catch (StoreTemporarilyUnavailableException e) {
      log.warn("[subscription notify] retry later : store=APPLE_IAP, cause={}", e.getMessage());
      return StoreNotificationOutcome.RETRY_LATER;
    }
  }

  private StoreNotificationOutcome applyNotification(
    ResponseBodyV2DecodedPayload payload, StoreEnvironment environment, AppleVerifyContext context
  ) {
    NotificationTypeV2 type = payload.getNotificationType();
    String notificationId = payload.getNotificationUUID();
    Data data = payload.getData();
    // 연결 시험 알림·구독 거래가 없는 알림(요약·소비 요청 등)
    if (type == NotificationTypeV2.TEST || data == null || data.getSignedTransactionInfo() == null) {
      log.info("[subscription notify] ignored : store=APPLE_IAP, type={}", type);
      return StoreNotificationOutcome.IGNORED;
    }
    if (applier.isDuplicateEvent(SubscriptionSource.APPLE_IAP, notificationId)) {
      return StoreNotificationOutcome.IGNORED;
    }
    JWSTransactionDecodedPayload transaction = verifier.verifyTransactionIn(data.getSignedTransactionInfo(), environment, context);
    // 소모성 상품(크레딧 꾸러미)은 환불 알림만 받아 회수한다
    if (transaction.getType() == Type.CONSUMABLE) {
      return applyConsumableNotification(type, transaction);
    }
    JWSRenewalInfoDecodedPayload renewal = data.getSignedRenewalInfo() == null
      ? null : verifier.verifyRenewalInfo(data.getSignedRenewalInfo(), environment, context);
    if (!isAllowedSubscription(transaction)) {
      log.warn("[subscription notify] ignored : store=APPLE_IAP, type={}, product not allowed : {}",
        type, StoreLogValues.mask(transaction.getProductId()));
      return StoreNotificationOutcome.IGNORED;
    }
    requireSameSubscription(transaction, renewal);

    StoreSubscriptionSnapshot snapshot = AppleSubscriptionSnapshotMapper.toSnapshot(
      transaction, renewal, environment, type, payload.getSubtype(), payload.getSignedDate(), LocalDateTime.now(clock));
    String eventType = payload.getSubtype() == null
      ? String.valueOf(type) : type + EVENT_TYPE_SUBTYPE_DELIMITER + payload.getSubtype();
    StoreApplyOutcome outcome = StorePurchaseApplier.retryOnceOnConflict(() -> applier.apply(
      snapshot, null, StorePurchaseTrigger.STORE_NOTIFICATION, eventType, notificationId));
    log.info("[subscription notify] applied : store=APPLE_IAP, type={}, result={}, purchase={}",
      eventType, outcome.result(), StoreLogValues.mask(snapshot.purchaseKey()));
    return StoreNotificationOutcome.PROCESSED;
  }

  // 소모성 거래 알림: REFUND 만 회수 (그 밖의 알림은 받을 필요 없음)
  private StoreNotificationOutcome applyConsumableNotification(NotificationTypeV2 type, JWSTransactionDecodedPayload transaction) {
    if (type != NotificationTypeV2.REFUND || isBlank(transaction.getTransactionId())) {
      log.info("[subscription notify] ignored : store=APPLE_IAP, type={}, consumable", type);
      return StoreNotificationOutcome.IGNORED;
    }
    consumableRefundHandler.refund(SubscriptionSource.APPLE_IAP, transaction.getTransactionId());
    return StoreNotificationOutcome.PROCESSED;
  }

  // API 키가 있으면 Apple 에 최신 상태를 다시 물어 대체 (앱이 보낸 옛 영수증·환불 전 영수증 방지)
  private LatestAppleState latestFromApple(LatestAppleState fromClient, StoreEnvironment environment, AppleVerifyContext context) {
    AppleServerApiCredentials credentials = settings.appleServerApiCredentials();
    if (credentials == null) {
      return fromClient;
    }
    String originalTransactionId = fromClient.transaction().getOriginalTransactionId();
    SignedSubscriptionStatus latest = statusClient
      .fetchLatest(originalTransactionId, environment, context.bundleId(), credentials)
      .orElseThrow(() -> new StoreVerifyRejectedException(StoreVerifyRejectReason.PURCHASE_NOT_FOUND, "apple api"));
    JWSTransactionDecodedPayload transaction = verifier.verifyTransactionIn(latest.signedTransactionInfo(), environment, context);
    if (!Objects.equals(originalTransactionId, transaction.getOriginalTransactionId())) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "apple api transaction mismatch");
    }
    JWSRenewalInfoDecodedPayload renewal = latest.signedRenewalInfo() == null
      ? fromClient.renewal() : verifier.verifyRenewalInfo(latest.signedRenewalInfo(), environment, context);
    return new LatestAppleState(transaction, renewal);
  }

  private AppleVerifyContext contextOf() {
    return new AppleVerifyContext(settings.appleBundleId(), settings.appleAppAppleId(), settings.isAppleSandboxAllowed());
  }

  private void requireAllowedSubscription(JWSTransactionDecodedPayload transaction) {
    if (transaction.getType() != Type.AUTO_RENEWABLE_SUBSCRIPTION) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.NOT_SUBSCRIPTION, String.valueOf(transaction.getType()));
    }
    if (!settings.appleProductIds().contains(transaction.getProductId())) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.PRODUCT_NOT_ALLOWED, null);
    }
    if (isBlank(transaction.getOriginalTransactionId())) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "originalTransactionId");
    }
  }

  private boolean isAllowedSubscription(JWSTransactionDecodedPayload transaction) {
    return transaction.getType() == Type.AUTO_RENEWABLE_SUBSCRIPTION
      && !isBlank(transaction.getOriginalTransactionId())
      && settings.appleProductIds().contains(transaction.getProductId());
  }

  // 갱신 정보가 다른 구독 것이면 섞지 않음
  private static void requireSameSubscription(JWSTransactionDecodedPayload transaction, JWSRenewalInfoDecodedPayload renewal) {
    if (renewal != null && !Objects.equals(transaction.getOriginalTransactionId(), renewal.getOriginalTransactionId())) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "renewal info mismatch");
    }
  }

  private static String requireSignedData(String signedData) {
    if (isBlank(signedData) || signedData.length() > SIGNED_DATA_MAX_LENGTH) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "signed data length");
    }
    return signedData.trim();
  }

  private static boolean isBlank(String value) {
    return value == null || value.isBlank();
  }

  private record LatestAppleState(JWSTransactionDecodedPayload transaction, JWSRenewalInfoDecodedPayload renewal) {

  }
}
