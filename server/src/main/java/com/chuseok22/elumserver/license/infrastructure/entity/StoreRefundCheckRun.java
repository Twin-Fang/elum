package com.chuseok22.elumserver.license.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.license.core.StoreRefundCheckFailureReason;
import com.chuseok22.elumserver.license.core.StoreRefundCheckTrigger;
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
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 환불 재확인 1회 실행 기록 (스토어별 1줄): 실행 방식, 시작·끝, 단계별 건수, 실패 사유
 * 실패 사유 null = 끝까지 성공. 실패해도 그때까지의 건수는 남김
 */
@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "store_refund_check_run")
public class StoreRefundCheckRun extends BaseEntity {

  private static final int REQUESTED_BY_MAX_LENGTH = 100;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /// APPLE_IAP | GOOGLE_IAP
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private SubscriptionSource store;

  @Enumerated(EnumType.STRING)
  @Column(name = "trigger_type", nullable = false, length = 20)
  private StoreRefundCheckTrigger trigger;

  /// 관리자 실행이면 관리자 아이디, 자동이면 null
  @Column(name = "requested_by", length = REQUESTED_BY_MAX_LENGTH)
  private String requestedBy;

  @Column(name = "started_at", nullable = false)
  private LocalDateTime startedAt;

  @Column(name = "finished_at")
  private LocalDateTime finishedAt;

  /// Google 취소 구매 목록 건수 (Apple 은 0)
  @Column(name = "voided_count", nullable = false)
  private int voidedCount;

  /// 거래·주문 상태를 물어본 건수
  @Column(name = "checked_count", nullable = false)
  private int checkedCount;

  /// 스토어가 환불로 답한 건수
  @Column(name = "refunded_count", nullable = false)
  private int refundedCount;

  /// 이번 실행에서 실제로 회수한 구매 수 (크레딧 + 구독)
  @Column(name = "revoked_count", nullable = false)
  private int revokedCount;

  @Enumerated(EnumType.STRING)
  @Column(name = "failure_reason", length = 50)
  private StoreRefundCheckFailureReason failureReason;

  public static StoreRefundCheckRun start(
    SubscriptionSource store, StoreRefundCheckTrigger trigger, String requestedBy, LocalDateTime startedAt
  ) {
    StoreRefundCheckRun run = new StoreRefundCheckRun();
    run.store = store;
    run.trigger = trigger;
    run.requestedBy = requestedBy == null || requestedBy.length() <= REQUESTED_BY_MAX_LENGTH
      ? requestedBy : requestedBy.substring(0, REQUESTED_BY_MAX_LENGTH);
    run.startedAt = startedAt;
    return run;
  }

  public void addVoided(int count) {
    voidedCount += count;
  }

  public void addChecked(int count) {
    checkedCount += count;
  }

  public void addRefunded(int count) {
    refundedCount += count;
  }

  public void addRevoked(int count) {
    revokedCount += count;
  }

  /// 첫 실패 사유만 남김 (뒤 단계 실패가 원인을 덮지 않게)
  public void recordFailure(StoreRefundCheckFailureReason reason) {
    if (failureReason == null) {
      failureReason = reason;
    }
  }

  public void finish(LocalDateTime finishedAt) {
    this.finishedAt = finishedAt;
  }

  public boolean isSucceeded() {
    return failureReason == null;
  }
}
