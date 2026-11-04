package com.chuseok22.elumserver.license.application.service.store;

import static com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionTestStore.NOW;
import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.license.application.service.store.StorePurchaseApplier.StoreApplyOutcome;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseEventResult;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.SubscriptionHistoryAction;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.time.LocalDateTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 스토어 반영: 같은 거래 두 번(멱등), 다른 회원 구매 재사용 거부, 탈퇴 주인 구매 복원, 오래된 영수증, 알림만으로 연결, 환불
 */
class StorePurchaseApplierTest {

  private static final String MEMBER_A = "aaaaaaaa-0000-4000-8000-000000000001";
  private static final String MEMBER_B = "bbbbbbbb-0000-4000-8000-000000000002";
  private static final String ORIGINAL_TRANSACTION_ID = "1000000000000001";
  private static final String VERIFY = StorePurchaseApplier.VERIFY_EVENT_TYPE;

  private StoreSubscriptionTestStore store;

  @BeforeEach
  void setUp() {
    store = new StoreSubscriptionTestStore();
    store.addMember(MEMBER_A, MemberStatus.ACTIVE);
    store.addMember(MEMBER_B, MemberStatus.ACTIVE);
  }

  @Test
  @DisplayName("같은 거래를 두 번 보내도 Pro 기간·이력·거래 이력이 한 번만 바뀐다")
  void sameTransactionTwice_changesNothingSecondTime() {
    StoreSubscriptionSnapshot snapshot = activeSnapshot(null, NOW.plusDays(30), NOW.minusMinutes(1));

    StoreApplyOutcome first = verify(snapshot, MEMBER_A);
    StoreApplyOutcome second = verify(snapshot, MEMBER_A);

    assertThat(first.result()).isEqualTo(StorePurchaseEventResult.APPLIED);
    assertThat(second.result()).isEqualTo(StorePurchaseEventResult.UNCHANGED);
    assertThat(second.isChanged()).isFalse();
    Subscription subscription = store.subscriptionsByMemberId.get(MEMBER_A);
    assertThat(subscription.effectivePlan(NOW)).isEqualTo(PlanType.PRO);
    assertThat(subscription.getSource()).isEqualTo(SubscriptionSource.APPLE_IAP);
    assertThat(subscription.getExpiresAt()).isEqualTo(NOW.plusDays(30));
    assertThat(store.histories).hasSize(1);
    assertThat(store.events).hasSize(1);
  }

  @Test
  @DisplayName("다른 활성 회원에 묶인 구독을 다른 계정이 복원하면 거부하고 아무것도 넘기지 않는다")
  void purchaseBoundToOtherMember_isRejected() {
    verify(activeSnapshot(null, NOW.plusDays(30), NOW.minusMinutes(2)), MEMBER_A);

    StoreApplyOutcome outcome = verify(activeSnapshot(null, NOW.plusDays(30), NOW.minusMinutes(1)), MEMBER_B);

    assertThat(outcome.isRejected()).isTrue();
    assertThat(store.purchase(SubscriptionSource.APPLE_IAP, ORIGINAL_TRANSACTION_ID).getMemberId()).isEqualTo(MEMBER_A);
    assertThat(store.subscriptionsByMemberId).doesNotContainKey(MEMBER_B);
    assertThat(store.events).last().satisfies(event -> {
      assertThat(event.getResult()).isEqualTo(StorePurchaseEventResult.REJECTED);
      assertThat(event.getReason()).isEqualTo("OWNED_BY_OTHER_MEMBER");
    });
  }

  @Test
  @DisplayName("구매 때 다른 활성 회원 id 를 실은 거래는 처음 보내는 계정이라도 거부한다")
  void appAccountTokenOfOtherMember_isRejected() {
    StoreApplyOutcome outcome = verify(activeSnapshot(MEMBER_A, NOW.plusDays(30), NOW), MEMBER_B);

    assertThat(outcome.isRejected()).isTrue();
    assertThat(store.subscriptionsByMemberId).isEmpty();
  }

  @Test
  @DisplayName("탈퇴한 계정에 묶였던 구독은 새 계정에서 복원하면 새 계정으로 옮겨진다")
  void purchaseOfWithdrawnOwner_rebindsToRequester() {
    verify(activeSnapshot(null, NOW.plusDays(30), NOW.minusMinutes(2)), MEMBER_A);
    store.membersById.get(MEMBER_A).setStatus(MemberStatus.WITHDRAWN);

    StoreApplyOutcome outcome = verify(activeSnapshot(null, NOW.plusDays(30), NOW.minusMinutes(1)), MEMBER_B);

    assertThat(outcome.result()).isEqualTo(StorePurchaseEventResult.APPLIED);
    assertThat(store.purchase(SubscriptionSource.APPLE_IAP, ORIGINAL_TRANSACTION_ID).getMemberId()).isEqualTo(MEMBER_B);
    assertThat(store.subscriptionsByMemberId.get(MEMBER_B).effectivePlan(NOW)).isEqualTo(PlanType.PRO);
  }

  @Test
  @DisplayName("환불 뒤 늦게 온 환불 전 영수증은 상태를 덮지 않아 Pro 가 다시 켜지지 않는다")
  void staleReceiptAfterRefund_doesNotRegrant() {
    verify(activeSnapshot(null, NOW.plusDays(30), NOW.minusHours(2)), MEMBER_A);
    StoreSubscriptionSnapshot refunded = activeSnapshot(null, NOW.plusDays(30), NOW.minusHours(1)).withRevoked(NOW.minusHours(1));
    store.applier.apply(refunded, null, StorePurchaseTrigger.STORE_NOTIFICATION, "REFUND", "n-refund");

    StoreApplyOutcome replay = verify(activeSnapshot(null, NOW.plusDays(30), NOW.minusHours(2)), MEMBER_A);

    assertThat(replay.result()).isEqualTo(StorePurchaseEventResult.STALE);
    assertThat(store.purchase(SubscriptionSource.APPLE_IAP, ORIGINAL_TRANSACTION_ID).getState()).isEqualTo(StorePurchaseState.REVOKED);
    assertThat(store.subscriptionsByMemberId.get(MEMBER_A).effectivePlan(NOW)).isEqualTo(PlanType.FREE);
    assertThat(store.histories).extracting(history -> history.getAction())
      .containsExactly(SubscriptionHistoryAction.STORE_SYNC, SubscriptionHistoryAction.STORE_END);
  }

  @Test
  @DisplayName("앱이 서버에 알리기 전에 꺼져도, 구매 때 실은 회원 id 로 결제 알림만으로 Pro 가 켜진다")
  void notificationWithAppAccountToken_bindsWithoutClientCall() {
    store.applier.apply(activeSnapshot(MEMBER_A, NOW.plusDays(30), NOW),
      null, StorePurchaseTrigger.STORE_NOTIFICATION, "SUBSCRIBED.INITIAL_BUY", "n-1");

    assertThat(store.purchase(SubscriptionSource.APPLE_IAP, ORIGINAL_TRANSACTION_ID).getMemberId()).isEqualTo(MEMBER_A);
    assertThat(store.subscriptionsByMemberId.get(MEMBER_A).effectivePlan(NOW)).isEqualTo(PlanType.PRO);
  }

  @Test
  @DisplayName("같은 알림 id 를 두 번 받으면 두 번째는 아무것도 하지 않는다")
  void duplicateNotification_isIgnored() {
    StoreSubscriptionSnapshot snapshot = activeSnapshot(MEMBER_A, NOW.plusDays(30), NOW);
    store.applier.apply(snapshot, null, StorePurchaseTrigger.STORE_NOTIFICATION, "DID_RENEW", "n-1");

    store.applier.apply(snapshot, null, StorePurchaseTrigger.STORE_NOTIFICATION, "DID_RENEW", "n-1");

    assertThat(store.events).hasSize(1);
    assertThat(store.histories).hasSize(1);
  }

  @Test
  @DisplayName("회원을 모르는 알림은 미연결로 저장했다가 앱 검증 때 그 회원에 묶는다 — 결제가 사라지지 않는다")
  void unboundNotification_isBoundOnClientVerify() {
    StoreApplyOutcome unbound = store.applier.apply(activeSnapshot(null, NOW.plusDays(30), NOW.minusMinutes(1)),
      null, StorePurchaseTrigger.STORE_NOTIFICATION, "SUBSCRIBED.INITIAL_BUY", "n-1");

    StoreApplyOutcome bound = verify(activeSnapshot(null, NOW.plusDays(30), NOW.minusMinutes(1)), MEMBER_A);

    assertThat(unbound.result()).isEqualTo(StorePurchaseEventResult.UNBOUND);
    assertThat(bound.result()).isEqualTo(StorePurchaseEventResult.APPLIED);
    assertThat(store.subscriptionsByMemberId.get(MEMBER_A).effectivePlan(NOW)).isEqualTo(PlanType.PRO);
  }

  @Test
  @DisplayName("관리자가 무기한 Pro 를 준 회원은 스토어 구독이 끝나도 Free 로 떨어지지 않는다")
  void longerManualPro_isNotOverwritten() {
    Subscription manual = new Subscription();
    manual.setMember(store.membersById.get(MEMBER_A));
    manual.setPlan(PlanType.PRO);
    manual.setSource(SubscriptionSource.MANUAL);
    store.subscriptionsByMemberId.put(MEMBER_A, manual);

    verify(activeSnapshot(null, NOW.plusDays(30), NOW.minusMinutes(2)), MEMBER_A);
    store.applier.apply(activeSnapshot(null, NOW.plusDays(30), NOW.minusMinutes(1)).withRevoked(NOW),
      null, StorePurchaseTrigger.STORE_NOTIFICATION, "REFUND", "n-refund");

    assertThat(manual.getSource()).isEqualTo(SubscriptionSource.MANUAL);
    assertThat(manual.effectivePlan(NOW)).isEqualTo(PlanType.PRO);
    assertThat(store.histories).isEmpty();
  }

  private StoreApplyOutcome verify(StoreSubscriptionSnapshot snapshot, String memberId) {
    return store.applier.apply(snapshot, memberId, StorePurchaseTrigger.CLIENT_VERIFY, VERIFY, null);
  }

  private static StoreSubscriptionSnapshot activeSnapshot(String appAccountId, LocalDateTime expiresAt, LocalDateTime signedAt) {
    return new StoreSubscriptionSnapshot(SubscriptionSource.APPLE_IAP, ORIGINAL_TRANSACTION_ID, null, "elum_pro_monthly",
      StoreEnvironment.PRODUCTION, "2000000000000001", appAccountId, expiresAt, null, true,
      StorePurchaseState.ACTIVE, null, signedAt, false);
  }
}
