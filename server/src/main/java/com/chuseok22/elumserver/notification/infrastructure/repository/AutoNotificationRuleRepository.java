package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.AutoNotificationRule;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface AutoNotificationRuleRepository extends JpaRepository<AutoNotificationRule, AutoNotificationType> {

  @Query("select r from AutoNotificationRule r where r.isEnabled = true")
  List<AutoNotificationRule> findAllEnabled();

  /// 오늘 실행 선점: 오늘 아직 안 돌았을 때만 표시. 바뀐 행 수 1 이면 선점 성공 (인스턴스가 둘이어도 한 번)
  @Transactional
  @Modifying
  @Query("""
    update AutoNotificationRule r set r.lastRunDate = :today
    where r.type = :type and (r.lastRunDate is null or r.lastRunDate < :today)
    """)
  int claimTodayRun(@Param("type") AutoNotificationType type, @Param("today") LocalDate today);
}
