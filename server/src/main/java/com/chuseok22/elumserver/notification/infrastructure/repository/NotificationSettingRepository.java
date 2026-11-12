package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface NotificationSettingRepository extends JpaRepository<NotificationSetting, String> {

  /// 알림 성과 화면 (#1275): 칸마다 끈 사람 수 (전체 끔과 무관, 행 없는 사람은 켜짐이라 빠짐)
  @Query("""
    select sum(case when s.isRoutineNudgeEnabled = false then 1 else 0 end) as routineNudgeOffCount,
      sum(case when s.isSuggestionEnabled = false then 1 else 0 end) as suggestionOffCount,
      sum(case when s.isPlanReminderEnabled = false then 1 else 0 end) as planReminderOffCount,
      sum(case when s.isRoutineCompletedEnabled = false then 1 else 0 end) as routineCompletedOffCount,
      sum(case when s.isAllEnabled = false then 1 else 0 end) as allOffCount
    from NotificationSetting s
    """)
  OptOutCounts countOptOuts();

  interface OptOutCounts {

    Long getRoutineNudgeOffCount();

    Long getSuggestionOffCount();

    Long getPlanReminderOffCount();

    Long getRoutineCompletedOffCount();

    Long getAllOffCount();
  }
}
