package com.chuseok22.elumserver.license.infrastructure.repository;

import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SubscriptionHistoryRepository extends JpaRepository<SubscriptionHistory, String> {

  /// 최신순 이력 (limit 은 Pageable 로)
  List<SubscriptionHistory> findByMemberIdOrderByChangedAtDesc(String memberId, Pageable pageable);

  /**
   * 회원별 가장 최근 변경 한 건 (회원 수만큼 쿼리하지 않으려고 한 번에 가져온다)
   * 같은 시각이 둘이면 둘 다 나오므로 호출부가 회원당 하나로 줄인다
   */
  @Query("""
    select h from SubscriptionHistory h
    where h.memberId in :memberIds
      and h.changedAt = (
        select max(latest.changedAt) from SubscriptionHistory latest where latest.memberId = h.memberId
      )
    """)
  List<SubscriptionHistory> findLatestByMemberIds(@Param("memberIds") Collection<String> memberIds);

  void deleteByMemberId(String memberId);
}
