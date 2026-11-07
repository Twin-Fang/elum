package com.chuseok22.elumserver.license.application.service.store;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.application.alert.IncidentAlert;
import com.chuseok22.elumserver.common.application.alert.IncidentAlertService;
import com.chuseok22.elumserver.common.application.alert.IncidentAlertType;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseRepository;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.RejectedExecutionException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * 탈퇴 회원 Google 구독 해지 경계: 대상 조건, 커밋 후에만 호출, 호출 실패가 밖으로 새지 않음, 꺼짐·설정 없음
 * 실행기는 바로 실행, Google 호출은 mock (실제 해지 없음)
 */
class GoogleSubscriptionWithdrawalCancelerTest {

  private static final String MEMBER_ID = "aaaaaaaa-0000-4000-8000-000000000001";
  private static final String PACKAGE_NAME = "kr.suhsaechan.elum";
  private static final String SERVICE_ACCOUNT_JSON = "{\"type\":\"service_account\"}";

  private final StoreSubscriptionSettings settings = mock(StoreSubscriptionSettings.class);
  private final GooglePlayDeveloperClient playClient = mock(GooglePlayDeveloperClient.class);
  private final StorePurchaseRepository storePurchaseRepository = mock(StorePurchaseRepository.class);
  private final IncidentAlertService incidentAlertService = mock(IncidentAlertService.class);
  private final GoogleSubscriptionWithdrawalCanceler canceler = new GoogleSubscriptionWithdrawalCanceler(
    settings, playClient, storePurchaseRepository, incidentAlertService, Runnable::run);

  @BeforeEach
  void setUp() {
    when(settings.isGoogleEnabled()).thenReturn(true);
    when(settings.googlePackageName()).thenReturn(PACKAGE_NAME);
    when(settings.googleServiceAccountJson()).thenReturn(SERVICE_ACCOUNT_JSON);
  }

  @AfterEach
  void clearSynchronization() {
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
      TransactionSynchronizationManager.clearSynchronization();
    }
  }

  @Test
  @DisplayName("갱신이 꺼졌다고 확인된 것 외의 Google 구독은 해지한다 — 갱신 여부 모름도 해지 (앱 탈퇴 안내와 같은 조건, #1191)")
  void cancelsOnlyRenewingGoogleSubscriptions() {
    StorePurchase renewingGoogle = purchase("g-renewing", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.ACTIVE, true);
    StorePurchase graceGoogle = purchase("g-grace", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.IN_GRACE_PERIOD, true);
    StorePurchase renewingApple = purchase("a-renewing", SubscriptionSource.APPLE_IAP, StorePurchaseState.ACTIVE, true);
    StorePurchase stoppedGoogle = purchase("g-stopped", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.ACTIVE, false);
    StorePurchase unknownRenewalGoogle = purchase("g-unknown", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.ACTIVE, null);
    StorePurchase expiredGoogle = purchase("g-expired", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.EXPIRED, true);
    StorePurchase revokedGoogle = purchase("g-revoked", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.ACTIVE, true);
    revokedGoogle.setRevokedAt(LocalDateTime.now().minusDays(1));
    when(storePurchaseRepository.findByMemberId(MEMBER_ID)).thenReturn(List.of(
      renewingGoogle, graceGoogle, renewingApple, stoppedGoogle, unknownRenewalGoogle, expiredGoogle, revokedGoogle));

    canceler.cancelRenewalsAfterCommit(MEMBER_ID);

    ArgumentCaptor<String> cancelledTokens = ArgumentCaptor.forClass(String.class);
    verify(playClient, times(3))
      .cancelSubscription(eq(PACKAGE_NAME), cancelledTokens.capture(), eq(SERVICE_ACCOUNT_JSON));
    assertThat(cancelledTokens.getAllValues()).containsExactly("token-g-renewing", "token-g-grace", "token-g-unknown");
  }

  @Test
  @DisplayName("Google 해지 호출이 실패해도 예외가 탈퇴 쪽으로 나가지 않고, 다음 구매도 해지하며, 장애 알림을 보낸다")
  void storeFailure_neverPropagates_andAlerts() {
    StorePurchase failing = purchase("g-failing", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.ACTIVE, true);
    StorePurchase next = purchase("g-next", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.ACTIVE, true);
    when(storePurchaseRepository.findByMemberId(MEMBER_ID)).thenReturn(List.of(failing, next));
    doThrow(new StoreTemporarilyUnavailableException("google subscriptionsv2.cancel status 503"))
      .when(playClient).cancelSubscription(anyString(), eq("token-g-failing"), anyString());
    TransactionSynchronizationManager.initSynchronization();

    assertThatCode(() -> {
      canceler.cancelRenewalsAfterCommit(MEMBER_ID);
      commit();
    }).doesNotThrowAnyException();

    verify(playClient).cancelSubscription(PACKAGE_NAME, "token-g-next", SERVICE_ACCOUNT_JSON);
    ArgumentCaptor<IncidentAlert> alert = ArgumentCaptor.forClass(IncidentAlert.class);
    verify(incidentAlertService).notify(alert.capture());
    assertThat(alert.getValue().type()).isEqualTo(IncidentAlertType.GOOGLE_SUBSCRIPTION_CANCEL_FAILED);
    assertThat(alert.getValue().causeKey()).isEqualTo("id-g-failing");
  }

  @Test
  @DisplayName("대상 조회가 터져도 예외가 밖으로 나가지 않는다 (탈퇴는 이미 커밋된 뒤)")
  void lookupFailure_neverPropagates() {
    when(storePurchaseRepository.findByMemberId(MEMBER_ID)).thenThrow(new IllegalStateException("db down"));

    assertThatCode(() -> canceler.cancelRenewalsAfterCommit(MEMBER_ID)).doesNotThrowAnyException();

    verify(playClient, never()).cancelSubscription(anyString(), anyString(), anyString());
    verify(incidentAlertService).notify(any(IncidentAlert.class));
  }

  @Test
  @DisplayName("탈퇴가 롤백되면 Google 을 부르지 않는다 — 계정이 남았는데 구독만 해지되는 일이 없다")
  void rolledBack_doesNotCancel() {
    when(storePurchaseRepository.findByMemberId(MEMBER_ID)).thenReturn(List.of(
      purchase("g-renewing", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.ACTIVE, true)));
    TransactionSynchronizationManager.initSynchronization();

    canceler.cancelRenewalsAfterCommit(MEMBER_ID);
    TransactionSynchronizationManager.getSynchronizations()
      .forEach(synchronization -> synchronization.afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK));

    verify(storePurchaseRepository, never()).findByMemberId(anyString());
    verify(playClient, never()).cancelSubscription(anyString(), anyString(), anyString());
  }

  @Test
  @DisplayName("Google 결제 설정이 꺼져 있으면 해지를 부르지 않고, 해지 못 한 구독을 장애 알림으로 알린다 (#1191)")
  void googleDisabled_alertsWithoutCalling() {
    when(settings.isGoogleEnabled()).thenReturn(false);
    when(storePurchaseRepository.findByMemberId(MEMBER_ID)).thenReturn(List.of(
      purchase("g-renewing", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.ACTIVE, true)));

    canceler.cancelRenewalsAfterCommit(MEMBER_ID);

    verify(playClient, never()).cancelSubscription(anyString(), anyString(), anyString());
    ArgumentCaptor<IncidentAlert> alert = ArgumentCaptor.forClass(IncidentAlert.class);
    verify(incidentAlertService).notify(alert.capture());
    assertThat(alert.getValue().causeKey()).isEqualTo("disabled");
  }

  @Test
  @DisplayName("해지 작업 예약이 거절돼도 예외가 탈퇴 쪽으로 나가지 않고 장애 알림을 보낸다 (#1191)")
  void executorRejected_neverPropagates_andAlerts() {
    GoogleSubscriptionWithdrawalCanceler rejecting = new GoogleSubscriptionWithdrawalCanceler(
      settings, playClient, storePurchaseRepository, incidentAlertService,
      task -> { throw new RejectedExecutionException("queue full"); });

    assertThatCode(() -> rejecting.cancelRenewalsAfterCommit(MEMBER_ID)).doesNotThrowAnyException();

    verify(playClient, never()).cancelSubscription(anyString(), anyString(), anyString());
    ArgumentCaptor<IncidentAlert> alert = ArgumentCaptor.forClass(IncidentAlert.class);
    verify(incidentAlertService).notify(alert.capture());
    assertThat(alert.getValue().causeKey()).isEqualTo("not-scheduled");
  }

  @Test
  @DisplayName("켜져 있는데 서비스 계정이 없으면 해지하지 못한 것을 장애 알림으로 알린다")
  void serviceAccountMissing_alertsWithoutCalling() {
    when(settings.googleServiceAccountJson()).thenReturn("");
    when(storePurchaseRepository.findByMemberId(MEMBER_ID)).thenReturn(List.of(
      purchase("g-renewing", SubscriptionSource.GOOGLE_IAP, StorePurchaseState.ACTIVE, true)));

    canceler.cancelRenewalsAfterCommit(MEMBER_ID);

    verify(playClient, never()).cancelSubscription(anyString(), anyString(), anyString());
    verify(incidentAlertService).notify(any(IncidentAlert.class));
  }

  private static void commit() {
    TransactionSynchronizationManager.getSynchronizations().forEach(TransactionSynchronization::afterCommit);
  }

  private static StorePurchase purchase(String name, SubscriptionSource store, StorePurchaseState state, Boolean willAutoRenew) {
    StorePurchase purchase = new StorePurchase();
    purchase.setId("id-" + name);
    purchase.setStore(store);
    purchase.setPurchaseKey("token-" + name);
    purchase.setMemberId(MEMBER_ID);
    purchase.setEnvironment(StoreEnvironment.PRODUCTION);
    purchase.setState(state);
    purchase.setWillAutoRenew(willAutoRenew);
    purchase.setExpiresAt(LocalDateTime.now().plusDays(10));
    return purchase;
  }
}
