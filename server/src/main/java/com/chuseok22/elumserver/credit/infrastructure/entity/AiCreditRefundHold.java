package com.chuseok22.elumserver.credit.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.credit.core.CreditRefundHoldResolution;
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
 * 구매 확인보다 먼저 온 환불 1건: 거래를 모를 때 보류 > 그 거래가 확인되면 바로 회수
 * (store, transaction_id) 유니크라 같은 환불 알림이 여러 번 와도 한 줄
 */
@Entity
@Getter
@Setter
@Table(
  name = "ai_credit_refund_hold",
  uniqueConstraints = @UniqueConstraint(name = "uk_ai_credit_refund_hold_transaction", columnNames = {"store", "transaction_id"})
)
public class AiCreditRefundHold extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /// APPLE_IAP | GOOGLE_IAP
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private SubscriptionSource store;

  /// Apple transactionId · Google orderId
  @Column(name = "transaction_id", nullable = false)
  private String transactionId;

  @Column(name = "received_at", nullable = false)
  private LocalDateTime receivedAt;

  /// null 대기, APPLIED 회수함, REVERSED 환불 취소됨
  @Enumerated(EnumType.STRING)
  @Column(length = 20)
  private CreditRefundHoldResolution resolution;

  @Column(name = "resolved_at")
  private LocalDateTime resolvedAt;

  public boolean isPending() {
    return resolution == null;
  }
}
