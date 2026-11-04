package com.chuseok22.elumserver.license.application.service.store;

import com.apple.itunes.storekit.model.AutoRenewStatus;
import com.apple.itunes.storekit.model.JWSRenewalInfoDecodedPayload;
import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.apple.itunes.storekit.model.NotificationTypeV2;
import com.apple.itunes.storekit.model.Subtype;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;

/**
 * App Store 검증 통과 거래·갱신 정보(+ 알림 종류) > 공통 구독 상태
 * 상태 판정 순서: 환불·회수 > 만료 알림 > 결제 재시도(유예 있음/없음) > 만료일
 */
public final class AppleSubscriptionSnapshotMapper {

  private AppleSubscriptionSnapshotMapper() {
  }

  /**
   * @param renewal                갱신 정보, 없으면 null (자동 갱신·유예를 모름)
   * @param notificationType       알림이면 그 종류, 앱 검증 요청이면 null
   * @param notificationSignedDate 알림 서명 시각(ms), 없으면 거래·갱신 정보 서명 시각 중 늦은 쪽
   */
  public static StoreSubscriptionSnapshot toSnapshot(
    JWSTransactionDecodedPayload transaction, JWSRenewalInfoDecodedPayload renewal, StoreEnvironment environment,
    NotificationTypeV2 notificationType, Subtype subtype, Long notificationSignedDate, LocalDateTime now
  ) {
    LocalDateTime expiresAt = toLocalDateTime(transaction.getExpiresDate());
    LocalDateTime gracePeriodExpiresAt = renewal == null ? null : toLocalDateTime(renewal.getGracePeriodExpiresDate());
    LocalDateTime revokedAt = toLocalDateTime(transaction.getRevocationDate());
    StorePurchaseState state = stateOf(transaction, renewal, notificationType, subtype, expiresAt, gracePeriodExpiresAt, now);
    if (state == StorePurchaseState.REVOKED && revokedAt == null) {
      revokedAt = now;
    }
    return new StoreSubscriptionSnapshot(
      SubscriptionSource.APPLE_IAP,
      transaction.getOriginalTransactionId(),
      null,
      transaction.getProductId(),
      environment,
      transaction.getTransactionId(),
      transaction.getAppAccountToken() == null ? null : transaction.getAppAccountToken().toString(),
      expiresAt,
      gracePeriodExpiresAt,
      renewal == null || renewal.getAutoRenewStatus() == null ? null : renewal.getAutoRenewStatus() == AutoRenewStatus.ON,
      state,
      revokedAt,
      toLocalDateTime(signedDateOf(transaction, renewal, notificationSignedDate)),
      false
    );
  }

  static StorePurchaseState stateOf(
    JWSTransactionDecodedPayload transaction, JWSRenewalInfoDecodedPayload renewal,
    NotificationTypeV2 notificationType, Subtype subtype,
    LocalDateTime expiresAt, LocalDateTime gracePeriodExpiresAt, LocalDateTime now
  ) {
    // 환불·가족 공유 회수
    if (transaction.getRevocationDate() != null
      || notificationType == NotificationTypeV2.REFUND || notificationType == NotificationTypeV2.REVOKE) {
      return StorePurchaseState.REVOKED;
    }
    if (notificationType == NotificationTypeV2.EXPIRED) {
      return StorePurchaseState.EXPIRED;
    }
    // 유예 끝, 결제 재시도는 계속 (이용 불가)
    if (notificationType == NotificationTypeV2.GRACE_PERIOD_EXPIRED) {
      return StorePurchaseState.BILLING_RETRY;
    }
    boolean isInBillingRetry = (renewal != null && Boolean.TRUE.equals(renewal.getIsInBillingRetryPeriod()))
      || notificationType == NotificationTypeV2.DID_FAIL_TO_RENEW;
    if (isInBillingRetry) {
      boolean hasGrace = (gracePeriodExpiresAt != null && gracePeriodExpiresAt.isAfter(now))
        || (gracePeriodExpiresAt == null && subtype == Subtype.GRACE_PERIOD);
      return hasGrace ? StorePurchaseState.IN_GRACE_PERIOD : StorePurchaseState.BILLING_RETRY;
    }
    return expiresAt != null && expiresAt.isAfter(now) ? StorePurchaseState.ACTIVE : StorePurchaseState.EXPIRED;
  }

  private static Long signedDateOf(
    JWSTransactionDecodedPayload transaction, JWSRenewalInfoDecodedPayload renewal, Long notificationSignedDate
  ) {
    if (notificationSignedDate != null) {
      return notificationSignedDate;
    }
    Long transactionSignedDate = transaction.getSignedDate();
    Long renewalSignedDate = renewal == null ? null : renewal.getSignedDate();
    if (transactionSignedDate == null) {
      return renewalSignedDate;
    }
    return renewalSignedDate == null ? transactionSignedDate : Math.max(transactionSignedDate, renewalSignedDate);
  }

  /// epoch ms > 서버 시간대 LocalDateTime (LocalDateTime.now() 와 같은 기준)
  static LocalDateTime toLocalDateTime(Long epochMillis) {
    return epochMillis == null ? null : LocalDateTime.ofInstant(Instant.ofEpochMilli(epochMillis), ZoneId.systemDefault());
  }
}
