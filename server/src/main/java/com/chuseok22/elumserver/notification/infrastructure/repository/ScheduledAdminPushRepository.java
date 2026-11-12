package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.core.ScheduledAdminPushStatus;
import com.chuseok22.elumserver.notification.infrastructure.entity.ScheduledAdminPush;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface ScheduledAdminPushRepository extends JpaRepository<ScheduledAdminPush, String> {

  /// 관리자 목록: 보낼 시각 최신순
  List<ScheduledAdminPush> findAllByOrderByScheduledAtDesc(Pageable pageable);

  /// 보낼 시각이 지난 기다림 id (오래된 순)
  @Query("""
    select p.id from ScheduledAdminPush p
    where p.status = :status and p.scheduledAt <= :now
    order by p.scheduledAt asc
    """)
  List<String> findIdsDue(@Param("status") ScheduledAdminPushStatus status, @Param("now") LocalDateTime now);

  /// 상태 바꾸기: from 상태일 때만 to 로. 바뀐 행 수 1 이면 성공 (선점·취소가 겹쳐도 한쪽만)
  @Transactional
  @Modifying
  @Query("""
    update ScheduledAdminPush p set p.status = :to, p.updatedAt = :now
    where p.id = :id and p.status = :from
    """)
  int transition(@Param("id") String id, @Param("from") ScheduledAdminPushStatus from,
    @Param("to") ScheduledAdminPushStatus to, @Param("now") LocalDateTime now);
}
