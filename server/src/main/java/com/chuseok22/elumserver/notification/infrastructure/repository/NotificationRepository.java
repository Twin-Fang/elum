package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import jakarta.persistence.LockModeType;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NotificationRepository extends JpaRepository<Notification, String> {

  Optional<Notification> findByRecipientMemberIdAndGroupKey(String recipientMemberId, String groupKey);

  /// 묶음 갱신용 행 잠금 조회: 같은 묶음의 동시 갱신에서 횟수·일과 id 가 유실되지 않게 직렬화
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select n from Notification n where n.recipientMemberId = :recipientMemberId and n.groupKey = :groupKey")
  Optional<Notification> findForUpdateByRecipientMemberIdAndGroupKey(
    @Param("recipientMemberId") String recipientMemberId, @Param("groupKey") String groupKey);

  /// 최신순 목록. 같은 시각이면 id 내림차순 (커서 쿼리는 목록 API 에서 대체 가능)
  List<Notification> findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(String recipientMemberId, Pageable pageable);

  /// 커서 뒤 목록: (lastOccurredAt, id) 내림차순에서 주어진 위치보다 뒤
  @Query("select n from Notification n where n.recipientMemberId = :recipientMemberId "
    + "and (n.lastOccurredAt < :lastOccurredAt or (n.lastOccurredAt = :lastOccurredAt and n.id < :id)) "
    + "order by n.lastOccurredAt desc, n.id desc")
  List<Notification> findPageAfter(
    @Param("recipientMemberId") String recipientMemberId, @Param("lastOccurredAt") LocalDateTime lastOccurredAt,
    @Param("id") String id, Pageable pageable);

  /// 내 안 읽은 알림 전부 읽음 처리
  @Modifying(flushAutomatically = true, clearAutomatically = true)
  @Query("update Notification n set n.readAt = :readAt where n.recipientMemberId = :recipientMemberId and n.readAt is null")
  int markAllRead(@Param("recipientMemberId") String recipientMemberId, @Param("readAt") LocalDateTime readAt);

  long countByRecipientMemberIdAndReadAtIsNull(String recipientMemberId);

  /// 탈퇴·완전 삭제: 회원의 알림 전부
  int deleteAllByRecipientMemberId(String recipientMemberId);

  /// 이룸이 프로필을 지울 때 그 프로필의 알림 전부
  int deleteAllByProfileId(String profileId);

  /// 보관 기간이 지난 알림 정리 (일괄 삭제, 트랜잭션 안에서 호출)
  @Modifying(flushAutomatically = true, clearAutomatically = true)
  @Query("delete from Notification n where n.lastOccurredAt < :threshold")
  int deleteAllByLastOccurredAtBefore(@Param("threshold") LocalDateTime threshold);
}
