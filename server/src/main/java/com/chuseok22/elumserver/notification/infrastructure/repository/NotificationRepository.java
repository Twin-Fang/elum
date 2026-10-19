package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationRepository extends JpaRepository<Notification, String> {

  Optional<Notification> findByRecipientMemberIdAndGroupKey(String recipientMemberId, String groupKey);

  /// 최신순 목록. 같은 시각이면 id 내림차순 (커서 쿼리는 목록 API 에서 대체 가능)
  List<Notification> findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(String recipientMemberId, Pageable pageable);

  long countByRecipientMemberIdAndReadAtIsNull(String recipientMemberId);

  /// 탈퇴·완전 삭제: 회원의 알림 전부
  int deleteAllByRecipientMemberId(String recipientMemberId);

  /// 이룸이 프로필을 지울 때 그 프로필의 알림 전부
  int deleteAllByProfileId(String profileId);

  /// 보관 기간이 지난 알림 정리
  int deleteAllByLastOccurredAtBefore(LocalDateTime threshold);
}
