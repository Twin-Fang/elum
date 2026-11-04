package com.chuseok22.elumserver.license.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.license.core.StorePurchaseEventResult;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 스토어 거래 이력 1줄: 검증 요청·알림 1건의 결과 (원문 JWS·토큰 전체는 남기지 않음)
 * externalEventId 로 같은 알림을 두 번 처리하지 않음 (DB 부분 유일 인덱스)
 */
@Entity
@Getter
@Setter
@Table(name = "store_purchase_event")
public class StorePurchaseEvent extends BaseEntity {

  public static final int EVENT_TYPE_MAX_LENGTH = 100;
  public static final int REASON_MAX_LENGTH = 100;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 30)
  private SubscriptionSource store;

  @Column(length = StorePurchase.PURCHASE_KEY_MAX_LENGTH)
  private String purchaseKey;

  private String memberId;

  @Enumerated(EnumType.STRING)
  @Column(name = "trigger_type", nullable = false, length = 30)
  private StorePurchaseTrigger trigger;

  /// 알림 종류 (예: DID_RENEW.BILLING_RECOVERY, SUBSCRIPTION_RENEWED) 또는 VERIFY
  @Column(nullable = false, length = EVENT_TYPE_MAX_LENGTH)
  private String eventType;

  /// App Store notificationUUID, Pub/Sub messageId. 앱 검증 요청은 null
  private String externalEventId;

  private String transactionId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 30)
  private StorePurchaseEventResult result;

  @Column(length = REASON_MAX_LENGTH)
  private String reason;

  @Enumerated(EnumType.STRING)
  @Column(length = 30)
  private StorePurchaseState stateAfter;

  private LocalDateTime expiresAtAfter;

  @Column(nullable = false)
  private LocalDateTime occurredAt;
}
