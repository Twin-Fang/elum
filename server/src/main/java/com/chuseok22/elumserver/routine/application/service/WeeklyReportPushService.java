package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.ProfileGuardianService;
import com.chuseok22.elumserver.notification.application.service.NotificationRecorder;
import com.chuseok22.elumserver.notification.application.service.PushDispatcher;
import com.chuseok22.elumserver.notification.application.service.PushMessageFactory;
import com.chuseok22.elumserver.notification.application.service.RecordedNotification;
import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 주간 리포트 월요일 알림: 지난주 마친 일과가 있는 이룸이 > 권한 있는 보호자 > 정리 글 만들기(없으면) > 알림 기록 > 푸시
 * 같은 주는 알림 묶음 키가 한 번만 보내게 막음 (재실행·두 서버가 겹쳐도 안전). 이룸이 하나의 실패는 그 이룸이만 건너뜀
 * 푸시 본문은 횟수만 (이름·일과 제목은 잠금 화면에 나가지 않게 넣지 않음)
 */
@Slf4j
@Service
public class WeeklyReportPushService {

  /// 한 번 실행에 새로 알리는 최대 이룸이 수 (나머지는 같은 날 다음 실행이 이음)
  static final int MAX_NEWLY_NOTIFIED_PROFILES_PER_RUN = 300;

  private final SystemConfigService systemConfigService;
  private final WeeklyReportReader weeklyReportReader;
  private final WeeklyReportSummaryService weeklyReportSummaryService;
  private final ProfileGuardianService profileGuardianService;
  private final EntitlementService entitlementService;
  private final NotificationRecorder notificationRecorder;
  private final PushDispatcher pushDispatcher;
  private final Clock clock;

  @Autowired
  public WeeklyReportPushService(
    SystemConfigService systemConfigService, WeeklyReportReader weeklyReportReader,
    WeeklyReportSummaryService weeklyReportSummaryService, ProfileGuardianService profileGuardianService,
    EntitlementService entitlementService, NotificationRecorder notificationRecorder, PushDispatcher pushDispatcher
  ) {
    this(systemConfigService, weeklyReportReader, weeklyReportSummaryService, profileGuardianService,
      entitlementService, notificationRecorder, pushDispatcher, Clock.system(NotificationTime.ZONE_ID));
  }

  WeeklyReportPushService(
    SystemConfigService systemConfigService, WeeklyReportReader weeklyReportReader,
    WeeklyReportSummaryService weeklyReportSummaryService, ProfileGuardianService profileGuardianService,
    EntitlementService entitlementService, NotificationRecorder notificationRecorder, PushDispatcher pushDispatcher,
    Clock clock
  ) {
    this.systemConfigService = systemConfigService;
    this.weeklyReportReader = weeklyReportReader;
    this.weeklyReportSummaryService = weeklyReportSummaryService;
    this.profileGuardianService = profileGuardianService;
    this.entitlementService = entitlementService;
    this.notificationRecorder = notificationRecorder;
    this.pushDispatcher = pushDispatcher;
    this.clock = clock;
  }

  /// 한 번 실행: 스위치 꺼짐 > 아무것도 안 함 / 지난주 대상 이룸이를 순서대로 처리 (새로 알린 수가 상한이면 멈춤)
  public void runOnce() {
    if (!systemConfigService.getBoolean(ConfigKey.WEEKLY_REPORT_PUSH_ENABLED)) {
      return;
    }
    LocalDate today = LocalDate.now(clock);
    ReportWeek lastWeek = ReportWeek.containing(today.minusWeeks(1));
    List<String> profileIds = weeklyReportReader.findProfileIdsWithCompletedRoutines(lastWeek);
    int notifiedProfileCount = 0;
    int failedProfileCount = 0;
    for (String profileId : profileIds) {
      if (notifiedProfileCount >= MAX_NEWLY_NOTIFIED_PROFILES_PER_RUN) {
        log.info("[weekly report] push run capped, rest continues next run : cap={}", MAX_NEWLY_NOTIFIED_PROFILES_PER_RUN);
        break;
      }
      try {
        if (notifyProfile(profileId, lastWeek, today)) {
          notifiedProfileCount++;
        }
      } catch (RuntimeException e) {
        failedProfileCount++;
        log.warn("[weekly report] push failed for profile : profileId={}", profileId, e);
      }
    }
    log.info("[weekly report] push run done : candidates={}, notified={}, failed={}",
      profileIds.size(), notifiedProfileCount, failedProfileCount);
  }

  /// 이룸이 하나: 새로 알림을 보낼 사람이 있었으면 true
  private boolean notifyProfile(String profileId, ReportWeek lastWeek, LocalDate today) {
    // 받는 사람: 이룸이를 함께 돌보는 보호자 중 주간 리포트 권한이 있는 사람
    List<String> recipientMemberIds = profileGuardianService.guardianMemberIdsOf(profileId).stream()
      .filter(memberId -> entitlementService.isAllowed(memberId, Entitlement.WEEKLY_REPORT))
      .toList();
    if (recipientMemberIds.isEmpty()) {
      return false;
    }
    Optional<WeeklyReportReader.ReportWithNickname> data = weeklyReportReader.aggregateWithNickname(profileId, lastWeek, today);
    if (data.isEmpty() || data.get().report().completedRoutineCount() == 0) {
      return false;
    }
    // 정리 글 만들기 (이미 있으면 그대로, AI 비용은 첫 보호자 계정으로)
    weeklyReportSummaryService.summaryFor(profileId, data.get().nickname(), recipientMemberIds.get(0), lastWeek,
      data.get().report(), data.get().language(), today);

    NotificationDraft draft = NotificationDraft.weeklyReportReady(profileId, lastWeek.start(), LocalDateTime.now(clock));
    List<RecordedNotification> recorded = notificationRecorder.record(draft, recipientMemberIds);
    String counts = data.get().report().sentRoutineCount() + PushMessageFactory.WEEKLY_REPORT_COUNTS_DELIMITER
      + data.get().report().completedRoutineCount();
    pushDispatcher.dispatch(recorded, NotificationType.WEEKLY_REPORT_READY, counts);
    return recorded.stream().anyMatch(RecordedNotification::shouldPush);
  }
}
