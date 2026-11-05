package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.common.application.alert.IncidentAlert;
import com.chuseok22.elumserver.common.application.alert.IncidentAlertService;
import com.chuseok22.elumserver.common.application.alert.IncidentAlertType;
import com.chuseok22.elumserver.common.infrastructure.config.AsyncConfig;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseRepository;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient;
import java.util.List;
import java.util.Set;
import java.util.concurrent.Executor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * 탈퇴 회원의 Google Play 구독 자동 갱신 해지: 탈퇴 커밋 후 > 별도 스레드 > 대상 조회 > 설정 확인 > 건별 해지
 * 어떤 실패도 탈퇴로 넘기지 않음 (영어 로그 + 장애 알림, 운영자가 Play Console 에서 직접 해지). App Store 는 서버 해지 API 없음
 */
@Slf4j
@Component
public class GoogleSubscriptionWithdrawalCanceler {

  // 해지할 필요 없는 끝난 상태 2개: 만료, 환불·회수
  private static final Set<StorePurchaseState> FINISHED_STATES = Set.of(StorePurchaseState.EXPIRED, StorePurchaseState.REVOKED);
  // 장애 알림 원인 키: 설정 없음·예상 못 한 실패는 회원과 무관한 한 묶음
  private static final String ALERT_CAUSE_NOT_CONFIGURED = "not-configured";
  private static final String ALERT_CAUSE_UNEXPECTED = "unexpected";
  private static final String ALERT_MANUAL_ACTION = "Play Console 에서 직접 해지 (서버 로그 [subscription cancel] 확인)";

  private final StoreSubscriptionSettings settings;
  private final GooglePlayDeveloperClient playClient;
  private final StorePurchaseRepository storePurchaseRepository;
  private final IncidentAlertService incidentAlertService;
  private final Executor storeSubscriptionExecutor;

  public GoogleSubscriptionWithdrawalCanceler(
    StoreSubscriptionSettings settings,
    GooglePlayDeveloperClient playClient,
    StorePurchaseRepository storePurchaseRepository,
    IncidentAlertService incidentAlertService,
    @Qualifier(AsyncConfig.STORE_SUBSCRIPTION_EXECUTOR) Executor storeSubscriptionExecutor
  ) {
    this.settings = settings;
    this.playClient = playClient;
    this.storePurchaseRepository = storePurchaseRepository;
    this.incidentAlertService = incidentAlertService;
    this.storeSubscriptionExecutor = storeSubscriptionExecutor;
  }

  /**
   * 탈퇴 커밋 후 해지 예약 (롤백이면 아무것도 안 함, 트랜잭션 밖이면 바로 예약)
   * 구매 토큰은 store_purchase 에 남아 탈퇴 뒤에도 읽을 수 있음
   */
  public void cancelRenewalsAfterCommit(String memberId) {
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      submitSafely(memberId);
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCommit() {
        submitSafely(memberId);
      }
    });
  }

  /**
   * 회원의 갱신 중인 Google 구독 해지 (예외를 밖으로 내지 않음)
   */
  void cancelRenewals(String memberId) {
    try {
      cancelRenewalsOrThrow(memberId);
    } catch (RuntimeException e) {
      log.warn("[subscription cancel] google failed : member={}, cause={}",
        StoreLogValues.mask(memberId), e.getClass().getSimpleName());
      notifyFailure(ALERT_CAUSE_UNEXPECTED, "대상 조회·설정 읽기 실패 (" + e.getClass().getSimpleName() + ")");
    }
  }

  // 대상 조회 > 켜짐 확인 > 인증값 확인 > 건별 해지
  private void cancelRenewalsOrThrow(String memberId) {
    List<StorePurchase> targets = storePurchaseRepository.findByMemberId(memberId).stream()
      .filter(GoogleSubscriptionWithdrawalCanceler::isRenewingGoogleSubscription)
      .toList();
    if (targets.isEmpty()) {
      return;
    }
    // 꺼짐: 결제를 열지 않은 상태 > 건너뜀 (로그만)
    if (!settings.isGoogleEnabled()) {
      log.info("[subscription cancel] google skipped : disabled, member={}, count={}",
        StoreLogValues.mask(memberId), targets.size());
      return;
    }
    String packageName = settings.googlePackageName();
    String serviceAccountJson = settings.googleServiceAccountJson();
    if (packageName.isEmpty() || serviceAccountJson.isEmpty()) {
      log.error("[subscription cancel] google skipped : not configured, member={}, count={}",
        StoreLogValues.mask(memberId), targets.size());
      notifyFailure(ALERT_CAUSE_NOT_CONFIGURED, "패키지 이름·서비스 계정 설정 없음 (" + targets.size() + "건)");
      return;
    }
    targets.forEach(purchase -> cancelOne(purchase, packageName, serviceAccountJson));
  }

  /**
   * 해지 대상: Google 구독 + 회원에 묶임 + 자동 갱신 켜짐 + 회수 안 됨 + 끝난 상태 아님
   */
  static boolean isRenewingGoogleSubscription(StorePurchase purchase) {
    return purchase.getStore() == SubscriptionSource.GOOGLE_IAP
      && purchase.getMemberId() != null
      && Boolean.TRUE.equals(purchase.getWillAutoRenew())
      && purchase.getRevokedAt() == null
      && purchase.getState() != null
      && !FINISHED_STATES.contains(purchase.getState());
  }

  // 결과는 DB 에 쓰지 않음 > Google 실시간 알림(RTDN)이 자동 갱신 꺼짐을 반영
  private void cancelOne(StorePurchase purchase, String packageName, String serviceAccountJson) {
    try {
      playClient.cancelSubscription(packageName, purchase.getPurchaseKey(), serviceAccountJson);
      log.info("[subscription cancel] google cancelled : purchase={}", purchase.getId());
    } catch (RuntimeException e) {
      // 원인: 스토어 실패는 상태 코드 문구, 그 외는 예외 이름만 (토큰이 섞이지 않게)
      String cause = e instanceof StoreTemporarilyUnavailableException ? e.getMessage() : e.getClass().getSimpleName();
      log.warn("[subscription cancel] google failed : purchase={}, cause={}", purchase.getId(), cause);
      notifyFailure(purchase.getId(), "해지 호출 실패 (store_purchase " + purchase.getId() + ")");
    }
  }

  // 실행기 거부·예외까지 탈퇴 요청으로 넘기지 않음
  private void submitSafely(String memberId) {
    try {
      storeSubscriptionExecutor.execute(() -> cancelRenewals(memberId));
    } catch (RuntimeException e) {
      log.warn("[subscription cancel] google not scheduled : member={}, cause={}",
        StoreLogValues.mask(memberId), e.getClass().getSimpleName());
    }
  }

  // 항목 2개: 사유, 운영자 조치 (토큰·회원 id 원문은 넣지 않음)
  private void notifyFailure(String causeKey, String reason) {
    incidentAlertService.notify(new IncidentAlert(IncidentAlertType.GOOGLE_SUBSCRIPTION_CANCEL_FAILED, causeKey, List.of(
      new IncidentAlert.Detail("사유", reason),
      new IncidentAlert.Detail("조치", ALERT_MANUAL_ACTION)
    )));
  }
}
