package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.license.application.service.StoreEntitlement;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.license.application.service.store.StorePurchaseBindingPolicy.BindingDecision;
import com.chuseok22.elumserver.license.core.StorePurchaseEventResult;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.StoreVerifyRejectReason;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchaseEvent;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseEventRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.Objects;
import java.util.Optional;
import java.util.function.Supplier;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 검증된 스토어 구독 상태 반영: 중복 알림 확인 > 구매 행 잠금 > 회원 연결 판정 > 오래된 정보 거르기 > 저장 > 회원 구독 다시 계산 > 거래 이력
 * 같은 상태를 두 번 받아도 바뀌는 것 없음 (구매 행·구독·이력 모두). 다른 회원 구매면 거부 결과만 남기고 아무것도 바꾸지 않음
 */
@Slf4j
@Service
public class StorePurchaseApplier {

  /// 앱 검증 요청의 거래 이력 종류
  public static final String VERIFY_EVENT_TYPE = "VERIFY";
  private static final int TRANSACTION_ID_MAX_LENGTH = 255;

  private final StorePurchaseRepository storePurchaseRepository;
  private final StorePurchaseEventRepository storePurchaseEventRepository;
  private final SubscriptionService subscriptionService;
  private final Clock clock;

  @Autowired
  public StorePurchaseApplier(
    StorePurchaseRepository storePurchaseRepository, StorePurchaseEventRepository storePurchaseEventRepository,
    SubscriptionService subscriptionService
  ) {
    this(storePurchaseRepository, storePurchaseEventRepository, subscriptionService, Clock.systemDefaultZone());
  }

  /// 시험용: 시각 고정
  StorePurchaseApplier(
    StorePurchaseRepository storePurchaseRepository, StorePurchaseEventRepository storePurchaseEventRepository,
    SubscriptionService subscriptionService, Clock clock
  ) {
    this.storePurchaseRepository = storePurchaseRepository;
    this.storePurchaseEventRepository = storePurchaseEventRepository;
    this.subscriptionService = subscriptionService;
    this.clock = clock;
  }

  /**
   * @param requesterMemberId 앱 검증 요청 회원, 스토어 알림이면 null
   * @param eventType         알림 종류 또는 VERIFY
   * @param externalEventId   알림 id (중복 차단), 앱 검증 요청이면 null
   */
  @Transactional
  public StoreApplyOutcome apply(
    StoreSubscriptionSnapshot snapshot, String requesterMemberId, StorePurchaseTrigger trigger,
    String eventType, String externalEventId
  ) {
    if (isDuplicateEvent(snapshot.store(), externalEventId)) {
      return StoreApplyOutcome.duplicate();
    }
    LocalDateTime now = LocalDateTime.now(clock);
    Optional<StorePurchase> existing = storePurchaseRepository.findForUpdate(snapshot.store(), snapshot.purchaseKey());
    Optional<StorePurchase> linked = findLinked(snapshot);
    String currentOwner = existing.map(StorePurchase::getMemberId)
      .orElseGet(() -> linked.map(StorePurchase::getMemberId).orElse(null));

    BindingDecision decision = StorePurchaseBindingPolicy.decide(
      currentOwner, snapshot.appAccountId(), requesterMemberId, subscriptionService::isActiveMember);
    if (decision.isRejected()) {
      log.warn("[subscription verify] rejected 400 : {} : store={}, purchase={}, requester={}, owner={}",
        StoreVerifyRejectReason.OWNED_BY_OTHER_MEMBER, snapshot.store(), StoreLogValues.mask(snapshot.purchaseKey()),
        StoreLogValues.mask(requesterMemberId), StoreLogValues.mask(currentOwner));
      recordEvent(snapshot, requesterMemberId, trigger, eventType, externalEventId,
        StorePurchaseEventResult.REJECTED, StoreVerifyRejectReason.OWNED_BY_OTHER_MEMBER.name(), null, now);
      return new StoreApplyOutcome(StorePurchaseEventResult.REJECTED, existing.orElse(null), false);
    }

    StorePurchase purchase = existing.orElseGet(() -> newPurchase(snapshot));
    String previousOwner = purchase.getMemberId();
    boolean isOwnerChanged = !Objects.equals(previousOwner, decision.ownerMemberId());
    purchase.setMemberId(decision.ownerMemberId());
    boolean isStale = isOlderThanStored(purchase, snapshot);
    boolean isStateChanged = !isStale && copyState(snapshot, purchase);
    boolean isLinkedSuperseded = linked.map(this::supersede).orElse(false);
    storePurchaseRepository.save(purchase);

    boolean isSubscriptionChanged = syncMember(decision.ownerMemberId(), now);
    // 다른(탈퇴한) 회원에게서 옮겨 왔거나 이전 토큰을 닫았으면 그 회원도 다시 계산
    if (isOwnerChanged && previousOwner != null) {
      syncMember(previousOwner, now);
    }
    linked.map(StorePurchase::getMemberId)
      .filter(linkedOwner -> isLinkedSuperseded && !linkedOwner.equals(decision.ownerMemberId()))
      .ifPresent(linkedOwner -> syncMember(linkedOwner, now));

    StorePurchaseEventResult eventResult = resultOf(decision, isOwnerChanged, isStale, isStateChanged || isLinkedSuperseded);
    boolean isChanged = isOwnerChanged || isStateChanged || isLinkedSuperseded || isSubscriptionChanged;
    if (trigger == StorePurchaseTrigger.STORE_NOTIFICATION || isChanged) {
      recordEvent(snapshot, decision.ownerMemberId(), trigger, eventType, externalEventId, eventResult, null, purchase, now);
    }
    return new StoreApplyOutcome(eventResult, purchase, isChanged);
  }

  /**
   * 환불 알림 반영 (Google voidedPurchaseNotification): 구매를 회수로 > 회원 구독 다시 계산 > 거래 이력
   * 모르는 구매면 이력만 남김
   */
  @Transactional
  public StoreApplyOutcome applyRevocation(
    SubscriptionSource store, String purchaseKey, String eventType, String externalEventId
  ) {
    if (isDuplicateEvent(store, externalEventId)) {
      return StoreApplyOutcome.duplicate();
    }
    LocalDateTime now = LocalDateTime.now(clock);
    Optional<StorePurchase> existing = storePurchaseRepository.findForUpdate(store, purchaseKey);
    if (existing.isEmpty()) {
      recordRevocationEvent(store, purchaseKey, null, eventType, externalEventId, StorePurchaseEventResult.UNBOUND, null, now);
      return new StoreApplyOutcome(StorePurchaseEventResult.UNBOUND, null, false);
    }
    StorePurchase purchase = existing.get();
    boolean isChanged = purchase.getState() != StorePurchaseState.REVOKED;
    purchase.setState(StorePurchaseState.REVOKED);
    if (purchase.getRevokedAt() == null) {
      purchase.setRevokedAt(now);
    }
    purchase.setStoreSignedAt(now);
    storePurchaseRepository.save(purchase);
    syncMember(purchase.getMemberId(), now);
    StorePurchaseEventResult eventResult = isChanged ? StorePurchaseEventResult.APPLIED : StorePurchaseEventResult.UNCHANGED;
    recordRevocationEvent(store, purchaseKey, purchase, eventType, externalEventId, eventResult, purchase.getMemberId(), now);
    return new StoreApplyOutcome(eventResult, purchase, isChanged);
  }

  /// Google 구매 확인(acknowledge) 완료 기록
  @Transactional
  public void markAcknowledged(SubscriptionSource store, String purchaseKey) {
    storePurchaseRepository.findForUpdate(store, purchaseKey).ifPresent(purchase -> {
      purchase.setAcknowledged(true);
      storePurchaseRepository.save(purchase);
    });
  }

  /**
   * 새 구매 행·알림 id 를 동시에 넣다 유일 제약에 걸리면 한 번 더 (두 번째는 먼저 들어간 행을 잠그고 반영)
   * 트랜잭션 밖(서비스)에서 부른다. 두 번째도 실패하면 예외 그대로 (알림은 5xx > 스토어 재전송)
   */
  public static <T> T retryOnceOnConflict(Supplier<T> applyCall) {
    try {
      return applyCall.get();
    } catch (DataIntegrityViolationException e) {
      log.info("[subscription apply] unique conflict, retry once");
      return applyCall.get();
    }
  }

  @Transactional(readOnly = true)
  public boolean isDuplicateEvent(SubscriptionSource store, String externalEventId) {
    return externalEventId != null && storePurchaseEventRepository.existsByStoreAndExternalEventId(store, externalEventId);
  }

  /// 회원의 Pro 를 주는 스토어 구매 중 가장 늦게 끝나는 것으로 구독 반영 (없으면 스토어발 Pro 종료)
  private boolean syncMember(String memberId, LocalDateTime now) {
    if (memberId == null) {
      return false;
    }
    StoreEntitlement best = storePurchaseRepository.findByMemberId(memberId).stream()
      .filter(purchase -> purchase.isEntitled(now))
      .max(Comparator.comparing(StorePurchase::entitledUntil))
      .map(purchase -> new StoreEntitlement(purchase.getStore(), purchase.getId(), purchase.getProductId(),
        purchase.entitledUntil()))
      .orElse(null);
    return subscriptionService.syncStoreEntitlement(memberId, best, now);
  }

  private Optional<StorePurchase> findLinked(StoreSubscriptionSnapshot snapshot) {
    String linkedKey = snapshot.linkedPurchaseKey();
    if (linkedKey == null || linkedKey.equals(snapshot.purchaseKey())) {
      return Optional.empty();
    }
    return storePurchaseRepository.findForUpdate(snapshot.store(), linkedKey);
  }

  // 업그레이드·재구독으로 대체된 이전 토큰은 만료로 (같은 구독이 두 번 세지지 않게)
  private boolean supersede(StorePurchase linked) {
    if (linked.getState() == StorePurchaseState.EXPIRED || linked.getState() == StorePurchaseState.REVOKED) {
      return false;
    }
    linked.setState(StorePurchaseState.EXPIRED);
    storePurchaseRepository.save(linked);
    return true;
  }

  private static StorePurchase newPurchase(StoreSubscriptionSnapshot snapshot) {
    StorePurchase purchase = new StorePurchase();
    purchase.setStore(snapshot.store());
    purchase.setPurchaseKey(snapshot.purchaseKey());
    purchase.setEnvironment(snapshot.environment());
    purchase.setState(snapshot.state());
    return purchase;
  }

  // 이미 저장한 상태보다 스토어 서명 시각이 이른 정보 (늦게 도착한 옛 알림, 환불 전 영수증 재전송)
  private static boolean isOlderThanStored(StorePurchase purchase, StoreSubscriptionSnapshot snapshot) {
    return purchase.getStoreSignedAt() != null && snapshot.storeSignedAt() != null
      && snapshot.storeSignedAt().isBefore(purchase.getStoreSignedAt());
  }

  /// 스냅샷 > 구매 행, 하나라도 바뀌었으면 true (회원 연결·확인 여부는 따로)
  private static boolean copyState(StoreSubscriptionSnapshot snapshot, StorePurchase purchase) {
    boolean isChanged = purchase.getId() == null
      || !Objects.equals(purchase.getProductId(), snapshot.productId())
      || purchase.getEnvironment() != snapshot.environment()
      || purchase.getState() != snapshot.state()
      || !Objects.equals(purchase.getExpiresAt(), snapshot.expiresAt())
      || !Objects.equals(purchase.getGracePeriodExpiresAt(), snapshot.gracePeriodExpiresAt())
      || !Objects.equals(purchase.getWillAutoRenew(), snapshot.willAutoRenew())
      || !Objects.equals(purchase.getRevokedAt(), snapshot.revokedAt())
      || !Objects.equals(purchase.getLatestTransactionId(), snapshot.latestTransactionId())
      || !Objects.equals(purchase.getLinkedPurchaseKey(), snapshot.linkedPurchaseKey());
    purchase.setProductId(snapshot.productId());
    purchase.setEnvironment(snapshot.environment());
    purchase.setState(snapshot.state());
    purchase.setExpiresAt(snapshot.expiresAt());
    purchase.setGracePeriodExpiresAt(snapshot.gracePeriodExpiresAt());
    purchase.setWillAutoRenew(snapshot.willAutoRenew());
    purchase.setRevokedAt(snapshot.revokedAt());
    purchase.setLatestTransactionId(snapshot.latestTransactionId());
    purchase.setLinkedPurchaseKey(snapshot.linkedPurchaseKey());
    if (snapshot.storeSignedAt() != null) {
      purchase.setStoreSignedAt(snapshot.storeSignedAt());
    }
    // 확인 완료는 되돌리지 않음 (Google 이 확인 전 상태를 늦게 돌려줘도). 새 구매는 스토어 값 그대로
    purchase.setAcknowledged((purchase.getId() != null && purchase.isAcknowledged()) || !snapshot.needsAcknowledge());
    return isChanged;
  }

  private static StorePurchaseEventResult resultOf(
    BindingDecision decision, boolean isOwnerChanged, boolean isStale, boolean isStateChanged
  ) {
    if (decision.ownerMemberId() == null) {
      return StorePurchaseEventResult.UNBOUND;
    }
    if (isOwnerChanged || isStateChanged) {
      return StorePurchaseEventResult.APPLIED;
    }
    return isStale ? StorePurchaseEventResult.STALE : StorePurchaseEventResult.UNCHANGED;
  }

  private void recordEvent(
    StoreSubscriptionSnapshot snapshot, String memberId, StorePurchaseTrigger trigger, String eventType,
    String externalEventId, StorePurchaseEventResult result, String reason, StorePurchase purchase, LocalDateTime now
  ) {
    StorePurchaseEvent event = new StorePurchaseEvent();
    event.setStore(snapshot.store());
    event.setPurchaseKey(snapshot.purchaseKey());
    event.setMemberId(memberId);
    event.setTrigger(trigger);
    event.setEventType(truncate(eventType, StorePurchaseEvent.EVENT_TYPE_MAX_LENGTH));
    event.setExternalEventId(truncate(externalEventId, TRANSACTION_ID_MAX_LENGTH));
    event.setTransactionId(truncate(snapshot.latestTransactionId(), TRANSACTION_ID_MAX_LENGTH));
    event.setResult(result);
    event.setReason(truncate(reason, StorePurchaseEvent.REASON_MAX_LENGTH));
    event.setStateAfter(purchase == null ? null : purchase.getState());
    event.setExpiresAtAfter(purchase == null ? null : purchase.entitledUntil());
    event.setOccurredAt(now);
    storePurchaseEventRepository.save(event);
  }

  private void recordRevocationEvent(
    SubscriptionSource store, String purchaseKey, StorePurchase purchase, String eventType, String externalEventId,
    StorePurchaseEventResult result, String memberId, LocalDateTime now
  ) {
    StorePurchaseEvent event = new StorePurchaseEvent();
    event.setStore(store);
    event.setPurchaseKey(purchaseKey);
    event.setMemberId(memberId);
    event.setTrigger(StorePurchaseTrigger.STORE_NOTIFICATION);
    event.setEventType(truncate(eventType, StorePurchaseEvent.EVENT_TYPE_MAX_LENGTH));
    event.setExternalEventId(truncate(externalEventId, TRANSACTION_ID_MAX_LENGTH));
    event.setResult(result);
    event.setStateAfter(purchase == null ? null : purchase.getState());
    event.setOccurredAt(now);
    storePurchaseEventRepository.save(event);
  }

  private static String truncate(String value, int maxLength) {
    return value == null || value.length() <= maxLength ? value : value.substring(0, maxLength);
  }

  /**
   * 반영 결과
   *
   * @param purchase    반영 후 구매 행 (거부·중복·모르는 구매면 null 일 수 있음)
   * @param isChanged   구매·회원 연결·구독 중 하나라도 바뀜
   */
  public record StoreApplyOutcome(StorePurchaseEventResult result, StorePurchase purchase, boolean isChanged) {

    static StoreApplyOutcome duplicate() {
      return new StoreApplyOutcome(StorePurchaseEventResult.UNCHANGED, null, false);
    }

    public boolean isRejected() {
      return result == StorePurchaseEventResult.REJECTED;
    }
  }
}
