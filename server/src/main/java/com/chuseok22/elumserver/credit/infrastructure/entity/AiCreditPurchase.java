package com.chuseok22.elumserver.credit.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 크레딧 구매 한 건: 스토어 거래 id 하나당 한 행(멱등 키), 만든 적립 묶음, 환불 여부
 * (store, transaction_id) 유니크가 같은 거래의 두 번 적립을 마지막으로 막는다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "ai_credit_purchase",
  uniqueConstraints = @UniqueConstraint(name = "uk_ai_credit_purchase_transaction", columnNames = {"store", "transaction_id"}),
  indexes = @Index(name = "idx_ai_credit_purchase_account", columnList = "account_id, created_at")
)
public class AiCreditPurchase extends BaseEntity {

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

  @Column(name = "account_id", nullable = false)
  private String accountId;

  @Column(name = "member_id")
  private String memberId;

  @Column(name = "product_id", nullable = false, length = 150)
  private String productId;

  @Column(nullable = false)
  private int credits;

  /// 이 구매로 만든 적립 묶음 id
  @Column(name = "grant_id")
  private String grantId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private CreditPurchaseStatus status;

  @Column(name = "refunded_at")
  private LocalDateTime refundedAt;
}
