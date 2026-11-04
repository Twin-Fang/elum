package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.fasterxml.jackson.databind.JsonNode;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.Map;

/**
 * Google Play SubscriptionPurchaseV2 JSON > 공통 구독 상태
 * 상태는 subscriptionState 기준 (RTDN 은 "다시 조회하라"는 신호로만 씀, REVOKED 알림만 회수로 덧씌움)
 */
public final class GoogleSubscriptionSnapshotMapper {

  /// RTDN subscriptionNotification.notificationType 숫자 > 이름 (거래 이력 표시용)
  static final Map<Integer, String> NOTIFICATION_TYPE_NAMES = Map.ofEntries(
    Map.entry(1, "SUBSCRIPTION_RECOVERED"),
    Map.entry(2, "SUBSCRIPTION_RENEWED"),
    Map.entry(3, "SUBSCRIPTION_CANCELED"),
    Map.entry(4, "SUBSCRIPTION_PURCHASED"),
    Map.entry(5, "SUBSCRIPTION_ON_HOLD"),
    Map.entry(6, "SUBSCRIPTION_IN_GRACE_PERIOD"),
    Map.entry(7, "SUBSCRIPTION_RESTARTED"),
    Map.entry(8, "SUBSCRIPTION_PRICE_CHANGE_CONFIRMED"),
    Map.entry(9, "SUBSCRIPTION_DEFERRED"),
    Map.entry(10, "SUBSCRIPTION_PAUSED"),
    Map.entry(11, "SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED"),
    Map.entry(12, "SUBSCRIPTION_REVOKED"),
    Map.entry(13, "SUBSCRIPTION_EXPIRED"),
    Map.entry(19, "SUBSCRIPTION_PRICE_CHANGE_UPDATED"),
    Map.entry(20, "SUBSCRIPTION_PENDING_PURCHASE_CANCELED")
  );
  /// 환불·회수 알림 (조회 결과가 EXPIRED 여도 회수로 남김)
  static final int NOTIFICATION_TYPE_REVOKED = 12;
  private static final String ACKNOWLEDGEMENT_PENDING = "ACKNOWLEDGEMENT_STATE_PENDING";

  private GoogleSubscriptionSnapshotMapper() {
  }

  /// 알림 종류 숫자 > 이름, 모르는 값은 SUBSCRIPTION_UNKNOWN_{숫자}
  public static String notificationTypeName(int notificationType) {
    return NOTIFICATION_TYPE_NAMES.getOrDefault(notificationType, "SUBSCRIPTION_UNKNOWN_" + notificationType);
  }

  /**
   * @param notificationType RTDN 종류, 앱 검증 요청이면 null
   * @param now              조회 시각 (Google 상태는 조회 시점이 가장 최신이라 서명 시각으로 씀)
   */
  public static StoreSubscriptionSnapshot toSnapshot(
    JsonNode purchase, String purchaseToken, Integer notificationType, LocalDateTime now
  ) {
    JsonNode lineItems = purchase.path("lineItems");
    JsonNode firstLineItem = lineItems.path(0);
    LocalDateTime expiresAt = latestExpiryOf(lineItems);
    StorePurchaseState state = stateOf(purchase.path("subscriptionState").asText(""));
    boolean isRevoked = notificationType != null && notificationType == NOTIFICATION_TYPE_REVOKED;
    String latestOrderId = textOrNull(firstLineItem.path("latestSuccessfulOrderId"));
    return new StoreSubscriptionSnapshot(
      SubscriptionSource.GOOGLE_IAP,
      purchaseToken,
      textOrNull(purchase.path("linkedPurchaseToken")),
      textOrNull(firstLineItem.path("productId")),
      purchase.has("testPurchase") ? StoreEnvironment.SANDBOX : StoreEnvironment.PRODUCTION,
      latestOrderId != null ? latestOrderId : textOrNull(purchase.path("latestOrderId")),
      textOrNull(purchase.path("externalAccountIdentifiers").path("obfuscatedExternalAccountId")),
      expiresAt,
      state == StorePurchaseState.IN_GRACE_PERIOD ? expiresAt : null,
      willAutoRenewOf(lineItems),
      isRevoked ? StorePurchaseState.REVOKED : state,
      isRevoked ? now : null,
      now,
      ACKNOWLEDGEMENT_PENDING.equals(purchase.path("acknowledgementState").asText(""))
    );
  }

  /// subscriptionState > 공통 상태 (CANCELED 는 자동 갱신만 꺼진 것이라 만료일까지 이용)
  static StorePurchaseState stateOf(String subscriptionState) {
    return switch (subscriptionState) {
      case "SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_CANCELED" -> StorePurchaseState.ACTIVE;
      case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" -> StorePurchaseState.IN_GRACE_PERIOD;
      case "SUBSCRIPTION_STATE_ON_HOLD" -> StorePurchaseState.BILLING_RETRY;
      case "SUBSCRIPTION_STATE_PAUSED" -> StorePurchaseState.PAUSED;
      case "SUBSCRIPTION_STATE_PENDING" -> StorePurchaseState.PENDING;
      // EXPIRED, PENDING_PURCHASE_CANCELED, UNSPECIFIED, 모르는 값 > Pro 아님
      default -> StorePurchaseState.EXPIRED;
    };
  }

  /// 요청한 상품이 이 구매의 상품 목록에 있는가
  public static boolean containsProduct(JsonNode purchase, String productId) {
    for (JsonNode lineItem : purchase.path("lineItems")) {
      if (productId.equals(lineItem.path("productId").asText(null))) {
        return true;
      }
    }
    return false;
  }

  private static LocalDateTime latestExpiryOf(JsonNode lineItems) {
    LocalDateTime latest = null;
    for (JsonNode lineItem : lineItems) {
      LocalDateTime expiry = parseTime(textOrNull(lineItem.path("expiryTime")));
      if (expiry != null && (latest == null || expiry.isAfter(latest))) {
        latest = expiry;
      }
    }
    return latest;
  }

  // 상품 하나라도 자동 갱신 켜짐이면 true, 자동 갱신 정보가 없으면 null
  private static Boolean willAutoRenewOf(JsonNode lineItems) {
    Boolean willAutoRenew = null;
    for (JsonNode lineItem : lineItems) {
      JsonNode autoRenewEnabled = lineItem.path("autoRenewingPlan").path("autoRenewEnabled");
      if (autoRenewEnabled.isBoolean()) {
        willAutoRenew = Boolean.TRUE.equals(willAutoRenew) || autoRenewEnabled.asBoolean();
      }
    }
    return willAutoRenew;
  }

  // RFC 3339 (예: 2026-12-05T10:00:00.123Z) > 서버 시간대, 읽을 수 없으면 null (만료로 취급)
  private static LocalDateTime parseTime(String text) {
    if (text == null) {
      return null;
    }
    try {
      return LocalDateTime.ofInstant(Instant.parse(text), ZoneId.systemDefault());
    } catch (DateTimeParseException e) {
      return null;
    }
  }

  private static String textOrNull(JsonNode node) {
    return node.isTextual() && !node.asText().isBlank() ? node.asText() : null;
  }
}
