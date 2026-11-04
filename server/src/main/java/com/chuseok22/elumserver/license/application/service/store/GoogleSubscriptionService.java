package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.license.application.service.store.StorePurchaseApplier.StoreApplyOutcome;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.StoreVerifyRejectReason;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient;
import com.fasterxml.jackson.databind.JsonNode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Base64;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * Google Play 구독: 앱 검증 요청(purchaseToken + productId), 실시간 결제 알림(RTDN, Pub/Sub 푸시)
 * 검증: 켜짐 > 허용 상품 > Google 에 구독 조회 > 상품·테스트 결제 확인 > 반영 > 구매 확인(acknowledge)
 * RTDN 은 "다시 조회하라"는 신호로만 씀 (알림 내용으로 Pro 를 주지 않음). 조회 실패 시 503 > Pub/Sub 재전송
 */
@Slf4j
@Service
public class GoogleSubscriptionService {

  static final int PURCHASE_TOKEN_MAX_LENGTH = StorePurchase.PURCHASE_KEY_MAX_LENGTH;
  static final int PRODUCT_ID_MAX_LENGTH = 150;
  /// voidedPurchaseNotification.productType: 1 구독, 2 일회성 상품
  private static final int VOIDED_PRODUCT_TYPE_SUBSCRIPTION = 1;
  private static final String VOIDED_EVENT_TYPE = "VOIDED_PURCHASE";

  private final StoreSubscriptionSettings settings;
  private final GooglePlayDeveloperClient playClient;
  private final StorePurchaseApplier applier;
  private final Clock clock;

  @Autowired
  public GoogleSubscriptionService(
    StoreSubscriptionSettings settings, GooglePlayDeveloperClient playClient, StorePurchaseApplier applier
  ) {
    this(settings, playClient, applier, Clock.systemDefaultZone());
  }

  GoogleSubscriptionService(
    StoreSubscriptionSettings settings, GooglePlayDeveloperClient playClient, StorePurchaseApplier applier, Clock clock
  ) {
    this.settings = settings;
    this.playClient = playClient;
    this.applier = applier;
    this.clock = clock;
  }

  /**
   * 앱 검증 요청: 구독 조회 > 반영 > 구매 확인
   *
   * @throws CustomException 꺼짐 403, 거부 사유별 400, 서비스 계정 없음 503
   */
  public StoreVerification verifyFromClient(String memberId, String purchaseToken, String productId) {
    if (!settings.isGoogleEnabled()) {
      throw new CustomException(ErrorCode.SUBSCRIPTION_STORE_DISABLED);
    }
    String serviceAccountJson = settings.googleServiceAccountJson();
    if (serviceAccountJson.isEmpty()) {
      log.error("[subscription verify] google service account not configured");
      throw new CustomException(ErrorCode.SUBSCRIPTION_STORE_NOT_CONFIGURED);
    }
    try {
      String token = requireText(purchaseToken, PURCHASE_TOKEN_MAX_LENGTH);
      String product = requireText(productId, PRODUCT_ID_MAX_LENGTH);
      if (!settings.googleProductIds().contains(product)) {
        throw new StoreVerifyRejectedException(StoreVerifyRejectReason.PRODUCT_NOT_ALLOWED, null);
      }
      JsonNode purchase = playClient.fetchSubscription(settings.googlePackageName(), token, serviceAccountJson)
        .orElseThrow(() -> new StoreVerifyRejectedException(StoreVerifyRejectReason.PURCHASE_NOT_FOUND, null));
      if (!GoogleSubscriptionSnapshotMapper.containsProduct(purchase, product)) {
        throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "product mismatch");
      }
      LocalDateTime now = LocalDateTime.now(clock);
      StoreSubscriptionSnapshot snapshot = GoogleSubscriptionSnapshotMapper.toSnapshot(purchase, token, null, now);
      if (snapshot.environment() == StoreEnvironment.SANDBOX && !settings.isGoogleTestPurchaseAllowed()) {
        throw new StoreVerifyRejectedException(StoreVerifyRejectReason.ENVIRONMENT_NOT_ALLOWED, "test purchase");
      }
      StoreApplyOutcome outcome = StorePurchaseApplier.retryOnceOnConflict(() -> applier.apply(
        snapshot, memberId, StorePurchaseTrigger.CLIENT_VERIFY, StorePurchaseApplier.VERIFY_EVENT_TYPE, null));
      if (outcome.isRejected()) {
        throw new CustomException(ErrorCode.SUBSCRIPTION_OWNED_BY_OTHER_MEMBER);
      }
      acknowledgeIfNeeded(outcome.purchase(), product, serviceAccountJson, now);
      return outcome.purchase() != null && outcome.purchase().isEntitled(now)
        ? StoreVerification.ACTIVE : StoreVerification.INACTIVE;
    } catch (StoreVerifyRejectedException e) {
      log.warn("[subscription verify] rejected 400 : {} : store=GOOGLE_IAP, member={}",
        e.getReason(), StoreLogValues.mask(memberId));
      throw new CustomException(e.getReason().getErrorCode());
    } catch (StoreTemporarilyUnavailableException e) {
      log.warn("[subscription verify] pending : store=GOOGLE_IAP, member={}, cause={}",
        StoreLogValues.mask(memberId), e.getMessage());
      return StoreVerification.PENDING;
    }
  }

  /**
   * RTDN (Pub/Sub 푸시): 토큰 확인 > 메시지 해석 > 중복 확인 > 환불이면 회수, 구독 알림이면 다시 조회 후 반영
   *
   * @param pushToken 푸시 주소의 ?token= 값
   * @param body      Pub/Sub 푸시 본문 {"message":{"data":base64,"messageId":...},"subscription":...}
   */
  public StoreNotificationOutcome handleNotification(String pushToken, String body) {
    if (!settings.isGoogleEnabled()) {
      return StoreNotificationOutcome.RETRY_LATER;
    }
    if (!isPushTokenValid(pushToken)) {
      log.warn("[subscription notify] rejected 403 : token : store=GOOGLE_IAP");
      return StoreNotificationOutcome.FORBIDDEN;
    }
    RtdnMessage message = parse(body);
    if (message == null) {
      log.warn("[subscription notify] rejected 400 : malformed : store=GOOGLE_IAP");
      return StoreNotificationOutcome.REJECTED;
    }
    if (!settings.googlePackageName().equals(message.notification().path("packageName").asText(""))) {
      log.warn("[subscription notify] ignored : store=GOOGLE_IAP, package mismatch");
      return StoreNotificationOutcome.IGNORED;
    }
    if (applier.isDuplicateEvent(SubscriptionSource.GOOGLE_IAP, message.messageId())) {
      return StoreNotificationOutcome.IGNORED;
    }
    try {
      return dispatch(message);
    } catch (StoreTemporarilyUnavailableException e) {
      log.warn("[subscription notify] retry later : store=GOOGLE_IAP, cause={}", e.getMessage());
      return StoreNotificationOutcome.RETRY_LATER;
    }
  }

  // 알림 종류 3개: 환불(voided), 구독 상태 변경, 연결 시험
  private StoreNotificationOutcome dispatch(RtdnMessage message) {
    JsonNode notification = message.notification();
    JsonNode voided = notification.path("voidedPurchaseNotification");
    if (voided.isObject()) {
      if (voided.path("productType").asInt(0) != VOIDED_PRODUCT_TYPE_SUBSCRIPTION || !voided.path("purchaseToken").isTextual()) {
        return StoreNotificationOutcome.IGNORED;
      }
      StoreApplyOutcome outcome = StorePurchaseApplier.retryOnceOnConflict(() -> applier.applyRevocation(
        SubscriptionSource.GOOGLE_IAP, voided.path("purchaseToken").asText(), VOIDED_EVENT_TYPE, message.messageId()));
      log.info("[subscription notify] applied : store=GOOGLE_IAP, type={}, result={}", VOIDED_EVENT_TYPE, outcome.result());
      return StoreNotificationOutcome.PROCESSED;
    }
    JsonNode subscription = notification.path("subscriptionNotification");
    if (!subscription.isObject() || !subscription.path("purchaseToken").isTextual()) {
      log.info("[subscription notify] ignored : store=GOOGLE_IAP, not a subscription notification");
      return StoreNotificationOutcome.IGNORED;
    }
    return applySubscriptionNotification(
      subscription.path("purchaseToken").asText(), subscription.path("notificationType").asInt(0), message.messageId());
  }

  private StoreNotificationOutcome applySubscriptionNotification(String purchaseToken, int notificationType, String messageId) {
    String serviceAccountJson = settings.googleServiceAccountJson();
    if (serviceAccountJson.isEmpty()) {
      throw new StoreTemporarilyUnavailableException("google service account not configured");
    }
    String eventType = GoogleSubscriptionSnapshotMapper.notificationTypeName(notificationType);
    JsonNode purchase = playClient.fetchSubscription(settings.googlePackageName(), purchaseToken, serviceAccountJson).orElse(null);
    if (purchase == null) {
      log.warn("[subscription notify] ignored : store=GOOGLE_IAP, type={}, purchase not found : {}",
        eventType, StoreLogValues.mask(purchaseToken));
      return StoreNotificationOutcome.IGNORED;
    }
    LocalDateTime now = LocalDateTime.now(clock);
    StoreSubscriptionSnapshot snapshot = GoogleSubscriptionSnapshotMapper.toSnapshot(purchase, purchaseToken, notificationType, now);
    boolean isTestPurchaseBlocked = snapshot.environment() == StoreEnvironment.SANDBOX && !settings.isGoogleTestPurchaseAllowed();
    if (isTestPurchaseBlocked || !settings.googleProductIds().contains(snapshot.productId())) {
      log.info("[subscription notify] ignored : store=GOOGLE_IAP, type={}, test purchase or product not allowed", eventType);
      return StoreNotificationOutcome.IGNORED;
    }
    StoreApplyOutcome outcome = StorePurchaseApplier.retryOnceOnConflict(() -> applier.apply(
      snapshot, null, StorePurchaseTrigger.STORE_NOTIFICATION, eventType, messageId));
    acknowledgeIfNeeded(outcome.purchase(), snapshot.productId(), serviceAccountJson, now);
    log.info("[subscription notify] applied : store=GOOGLE_IAP, type={}, result={}, purchase={}",
      eventType, outcome.result(), StoreLogValues.mask(purchaseToken));
    return StoreNotificationOutcome.PROCESSED;
  }

  /**
   * 구매 확인: 회원에 묶였고 Pro 를 주는 상태인데 아직 확인 전일 때만 (다른 회원 구매·결제 대기는 확인하지 않음)
   * 실패해도 반영은 그대로, 다음 검증·알림 때 다시 시도 (3일 안에 확인 못 하면 Google 이 환불)
   */
  private void acknowledgeIfNeeded(StorePurchase purchase, String productId, String serviceAccountJson, LocalDateTime now) {
    if (purchase == null || purchase.isAcknowledged() || purchase.getMemberId() == null || !purchase.isEntitled(now)) {
      return;
    }
    try {
      playClient.acknowledge(settings.googlePackageName(), productId, purchase.getPurchaseKey(), serviceAccountJson);
      applier.markAcknowledged(SubscriptionSource.GOOGLE_IAP, purchase.getPurchaseKey());
    } catch (StoreTemporarilyUnavailableException e) {
      log.warn("[subscription verify] google acknowledge failed, retry next time : purchase={}",
        StoreLogValues.mask(purchase.getPurchaseKey()));
    }
  }

  // 설정 토큰과 상수 시간 비교 (설정이 비면 모두 거절)
  private boolean isPushTokenValid(String pushToken) {
    String expected = settings.googleRtdnPushToken();
    if (expected.isEmpty() || pushToken == null) {
      return false;
    }
    return MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8), pushToken.getBytes(StandardCharsets.UTF_8));
  }

  // Pub/Sub 푸시 본문 > (messageId, 알림 JSON), 읽을 수 없으면 null
  static RtdnMessage parse(String body) {
    if (body == null || body.isBlank()) {
      return null;
    }
    try {
      JsonNode message = DefaultJsonMapper.SHARED.readTree(body).path("message");
      String messageId = message.path("messageId").asText(null);
      String encodedNotification = message.path("data").asText(null);
      if (messageId == null || encodedNotification == null) {
        return null;
      }
      byte[] decoded = Base64.getDecoder().decode(encodedNotification);
      return new RtdnMessage(messageId, DefaultJsonMapper.SHARED.readTree(new String(decoded, StandardCharsets.UTF_8)));
    } catch (Exception e) {
      return null;
    }
  }

  private static String requireText(String value, int maxLength) {
    if (value == null || value.isBlank() || value.length() > maxLength) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "length");
    }
    return value.trim();
  }

  /// Pub/Sub 메시지 id + 해석한 DeveloperNotification JSON
  record RtdnMessage(String messageId, JsonNode notification) {

  }
}
