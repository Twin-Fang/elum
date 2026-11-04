package com.chuseok22.elumserver.license.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 스토어 구독 1건: 스토어가 확인해 준 지금 상태 + 묶인 회원
 * purchaseKey: App Store originalTransactionId, Google Play purchaseToken (스토어 안에서 유일)
 */
@Entity
@Getter
@Setter
@Table(
  name = "store_purchase",
  uniqueConstraints = @UniqueConstraint(name = "uk_store_purchase_store_key", columnNames = {"store", "purchase_key"})
)
public class StorePurchase extends BaseEntity {

  public static final int PURCHASE_KEY_MAX_LENGTH = 1024;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /// APPLE_IAP, GOOGLE_IAP
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 30)
  private SubscriptionSource store;

  @Column(name = "purchase_key", nullable = false, length = PURCHASE_KEY_MAX_LENGTH)
  private String purchaseKey;

  /// 아직 묶을 회원을 모르면 null (알림이 앱 검증보다 먼저 온 경우)
  private String memberId;

  private String productId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 30)
  private StoreEnvironment environment;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 30)
  private StorePurchaseState state;

  private LocalDateTime expiresAt;

  private LocalDateTime gracePeriodExpiresAt;

  /// 자동 갱신 켜짐 여부, 모르면 null
  private Boolean willAutoRenew;

  private LocalDateTime revokedAt;

  private String latestTransactionId;

  @Column(length = PURCHASE_KEY_MAX_LENGTH)
  private String linkedPurchaseKey;

  /// 이 상태를 스토어가 서명·조회한 시각 (오래된 정보가 새 상태를 덮지 않게)
  private LocalDateTime storeSignedAt;

  /// Google 구매 확인 완료 여부 (App Store 는 늘 true)
  @Column(name = "is_acknowledged", nullable = false)
  private boolean isAcknowledged = true;

  /// Pro 가 유지되는 마지막 시각: 유예 중이면 유예 끝과 만료일 중 늦은 쪽
  public LocalDateTime entitledUntil() {
    if (state == StorePurchaseState.IN_GRACE_PERIOD && gracePeriodExpiresAt != null
      && (expiresAt == null || gracePeriodExpiresAt.isAfter(expiresAt))) {
      return gracePeriodExpiresAt;
    }
    return expiresAt;
  }

  /// 지금 Pro 를 주는가: 이용 상태(ACTIVE·유예) + 회수 안 됨 + 유지 시각 전
  public boolean isEntitled(LocalDateTime now) {
    LocalDateTime until = entitledUntil();
    return state.isEntitledState() && revokedAt == null && until != null && until.isAfter(now);
  }
}
