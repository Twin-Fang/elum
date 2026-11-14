package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.core.NotificationDispatchSource;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationDispatch;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NotificationDispatchRepository extends JpaRepository<NotificationDispatch, String> {

  /// 회원의 발송 기록 전부 삭제 (탈퇴·완전 삭제, #1307)
  @Transactional
  @Modifying
  @Query("delete from NotificationDispatch d where d.memberId = :memberId")
  int deleteAllByMemberId(@Param("memberId") String memberId);

  /// 그 출처로 since 이후 받은 회원 id (하루 1개 상한)
  @Query("""
    select distinct d.memberId from NotificationDispatch d
    where d.source = :source and d.memberId in :memberIds and d.sentAt >= :since
    """)
  List<String> findMemberIdsWithSourceSince(@Param("source") NotificationDispatchSource source,
    @Param("memberIds") Collection<String> memberIds, @Param("since") LocalDateTime since);

  /// 그 자동 종류를 since 이후 받은 회원 id (최소 간격, 평생 한 번)
  @Query("""
    select distinct d.memberId from NotificationDispatch d
    where d.autoType = :autoType and d.memberId in :memberIds and d.sentAt >= :since
    """)
  List<String> findMemberIdsWithAutoTypeSince(@Param("autoType") AutoNotificationType autoType,
    @Param("memberIds") Collection<String> memberIds, @Param("since") LocalDateTime since);

  /// 성과 집계: (출처, 자동 종류)별 받은 사람 수, 기기 도착 사람 수, 연 사람 수
  @Query("""
    select d.source as source, d.autoType as autoType, count(d) as recipientCount,
      sum(case when d.sentDeviceCount > 0 then 1 else 0 end) as deliveredCount,
      sum(case when d.openedAt is not null then 1 else 0 end) as openedCount
    from NotificationDispatch d
    where d.sentAt >= :since
    group by d.source, d.autoType
    """)
  List<DispatchPerformanceRow> summarizeSince(@Param("since") LocalDateTime since);

  interface DispatchPerformanceRow {

    NotificationDispatchSource getSource();

    AutoNotificationType getAutoType();

    long getRecipientCount();

    Long getDeliveredCount();

    Long getOpenedCount();
  }

  /// 발송 한 줄 투영 (알림 효과 #1409): 받는 사람, 자동 종류, 보낸 시각, 연 시각(없으면 null)
  interface DispatchOutcomeRow {

    String getMemberId();

    AutoNotificationType getAutoType();

    LocalDateTime getSentAt();

    LocalDateTime getOpenedAt();
  }

  /// 그 출처로 since 이후 보낸 발송 기록 전부
  @Query("""
    select d.memberId as memberId, d.autoType as autoType, d.sentAt as sentAt, d.openedAt as openedAt
    from NotificationDispatch d
    where d.source = :source and d.sentAt >= :since
    """)
  List<DispatchOutcomeRow> findOutcomesBySourceSince(@Param("source") NotificationDispatchSource source,
    @Param("since") LocalDateTime since);
}
