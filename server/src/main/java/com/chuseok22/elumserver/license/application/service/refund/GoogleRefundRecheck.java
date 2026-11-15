package com.chuseok22.elumserver.license.application.service.refund;

import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings;
import com.chuseok22.elumserver.license.application.service.store.StoreTemporarilyUnavailableException;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.StoreRefundCheckFailureReason;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.entity.StoreRefundCheckRun;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseRepository;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient.VoidedPurchase;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * Google Play 환불 재확인: 켜짐·키 확인 > 취소 구매 목록(voidedpurchases) 회수 > 주문 상태(orders.batchGet REFUNDED) 회수
 * 취소 구매 목록은 "권한 회수 없는 환불"을 돌려주지 않아 주문 상태를 함께 본다. 단계 실패는 사유만 남기고 다음 단계로
 */
@Slf4j
@Component
public class GoogleRefundRecheck {

  // 취소 구매 조회 기간 (Play 허용 최대 30일, 요청 지연 여유 10분)
  static final Duration VOIDED_LOOKBACK = Duration.ofDays(30).minusMinutes(10);
  // 주문 상태를 볼 크레딧 구매 기간 (Play 환불 요청 가능 기간 여유)
  static final Duration CONSUMABLE_ORDER_LOOKBACK = Duration.ofDays(180);
  /// 거래 이력 종류: 취소 구매 목록, 주문 환불 상태
  static final String VOIDED_EVENT_TYPE = "RECHECK_VOIDED_PURCHASE";
  static final String ORDER_REFUNDED_EVENT_TYPE = "RECHECK_ORDER_REFUNDED";
  private static final Set<StorePurchaseState> ENTITLED_STATES = Set.of(StorePurchaseState.ACTIVE, StorePurchaseState.IN_GRACE_PERIOD);

  private final StoreSubscriptionSettings settings;
  private final GooglePlayDeveloperClient playClient;
  private final StorePurchaseRepository storePurchaseRepository;
  private final StoreConsumableRefundHandler consumableRefundHandler;
  private final RefundRecheckRevoker revoker;
  private final Clock clock;

  @Autowired
  public GoogleRefundRecheck(
    StoreSubscriptionSettings settings, GooglePlayDeveloperClient playClient, StorePurchaseRepository storePurchaseRepository,
    StoreConsumableRefundHandler consumableRefundHandler, RefundRecheckRevoker revoker
  ) {
    this(settings, playClient, storePurchaseRepository, consumableRefundHandler, revoker, Clock.systemDefaultZone());
  }

  GoogleRefundRecheck(
    StoreSubscriptionSettings settings, GooglePlayDeveloperClient playClient, StorePurchaseRepository storePurchaseRepository,
    StoreConsumableRefundHandler consumableRefundHandler, RefundRecheckRevoker revoker, Clock clock
  ) {
    this.settings = settings;
    this.playClient = playClient;
    this.storePurchaseRepository = storePurchaseRepository;
    this.consumableRefundHandler = consumableRefundHandler;
    this.revoker = revoker;
    this.clock = clock;
  }

  /// 1회 실행: 결과 건수·실패 사유를 run 에 채움 (저장은 부르는 쪽)
  public void run(StoreRefundCheckRun run) {
    if (!settings.isGoogleEnabled()) {
      run.recordFailure(StoreRefundCheckFailureReason.STORE_DISABLED);
      return;
    }
    String serviceAccountJson = settings.googleServiceAccountJson();
    if (serviceAccountJson.isEmpty()) {
      run.recordFailure(StoreRefundCheckFailureReason.CREDENTIALS_NOT_CONFIGURED);
      return;
    }
    revokeVoidedPurchases(run, serviceAccountJson);
    revokeRefundedOrders(run, serviceAccountJson);
  }

  // 최근 30일 취소 구매: 구독 토큰이면 Pro 회수, 아니면 주문 id 로 크레딧 회수
  private void revokeVoidedPurchases(StoreRefundCheckRun run, String serviceAccountJson) {
    long startTimeMillis = clock.instant().minus(VOIDED_LOOKBACK).toEpochMilli();
    List<VoidedPurchase> voidedPurchases;
    try {
      voidedPurchases = playClient.listVoidedPurchases(settings.googlePackageName(), startTimeMillis, serviceAccountJson);
    } catch (StoreTemporarilyUnavailableException e) {
      log.warn("[refund recheck] google voided list failed : cause={}", e.getMessage());
      run.recordFailure(StoreRefundCheckFailureReason.VOIDED_LIST_FAILED);
      return;
    }
    run.addVoided(voidedPurchases.size());
    for (VoidedPurchase voided : voidedPurchases) {
      if (revokeVoided(run, voided)) {
        run.addRevoked(1);
      }
    }
  }

  private boolean revokeVoided(StoreRefundCheckRun run, VoidedPurchase voided) {
    try {
      if (voided.purchaseToken() != null
        && revoker.revokeSubscription(SubscriptionSource.GOOGLE_IAP, voided.purchaseToken(), VOIDED_EVENT_TYPE)) {
        return true;
      }
      return voided.orderId() != null
        && revoker.revokeConsumable(SubscriptionSource.GOOGLE_IAP, voided.orderId(), VOIDED_EVENT_TYPE);
    } catch (RuntimeException e) {
      log.warn("[refund recheck] google revoke failed : cause={}", e.getClass().getSimpleName());
      run.recordFailure(StoreRefundCheckFailureReason.UNEXPECTED_ERROR);
      return false;
    }
  }

  // 권한 회수 없는 환불: 아직 회수 전인 크레딧 구매 주문 + Pro 를 주는 구독의 마지막 주문 > REFUNDED 면 회수
  private void revokeRefundedOrders(StoreRefundCheckRun run, String serviceAccountJson) {
    LocalDateTime now = LocalDateTime.now(clock);
    Set<String> consumableOrderIds = new HashSet<>(
      consumableRefundHandler.findGrantedTransactionIds(SubscriptionSource.GOOGLE_IAP, now.minus(CONSUMABLE_ORDER_LOOKBACK)));
    Map<String, String> subscriptionKeyByOrderId = new HashMap<>();
    for (StorePurchase purchase : storePurchaseRepository
      .findByStoreAndStateInAndRevokedAtIsNull(SubscriptionSource.GOOGLE_IAP, ENTITLED_STATES)) {
      if (purchase.getLatestTransactionId() != null) {
        subscriptionKeyByOrderId.put(purchase.getLatestTransactionId(), purchase.getPurchaseKey());
      }
    }
    Set<String> orderIds = new HashSet<>(consumableOrderIds);
    orderIds.addAll(subscriptionKeyByOrderId.keySet());
    run.addChecked(orderIds.size());
    if (orderIds.isEmpty()) {
      return;
    }
    Set<String> refundedOrderIds;
    try {
      refundedOrderIds = playClient.findRefundedOrderIds(settings.googlePackageName(), orderIds, serviceAccountJson);
    } catch (StoreTemporarilyUnavailableException e) {
      log.warn("[refund recheck] google order lookup failed : cause={}", e.getMessage());
      run.recordFailure(StoreRefundCheckFailureReason.ORDER_LOOKUP_FAILED);
      return;
    }
    run.addRefunded(refundedOrderIds.size());
    for (String orderId : refundedOrderIds) {
      if (revokeRefundedOrder(run, orderId, subscriptionKeyByOrderId.get(orderId))) {
        run.addRevoked(1);
      }
    }
  }

  private boolean revokeRefundedOrder(StoreRefundCheckRun run, String orderId, String subscriptionPurchaseKey) {
    try {
      return subscriptionPurchaseKey != null
        ? revoker.revokeSubscription(SubscriptionSource.GOOGLE_IAP, subscriptionPurchaseKey, ORDER_REFUNDED_EVENT_TYPE)
        : revoker.revokeConsumable(SubscriptionSource.GOOGLE_IAP, orderId, ORDER_REFUNDED_EVENT_TYPE);
    } catch (RuntimeException e) {
      log.warn("[refund recheck] google revoke failed : cause={}", e.getClass().getSimpleName());
      run.recordFailure(StoreRefundCheckFailureReason.UNEXPECTED_ERROR);
      return false;
    }
  }
}
