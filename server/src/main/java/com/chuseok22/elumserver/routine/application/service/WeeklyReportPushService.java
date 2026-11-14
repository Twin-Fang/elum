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
 * 주간 리포트 월요일 알림: 지난주 마친 일과가 있는 이룸이 > 받는 보호자(권한 있는 보호자 + 설정이 켜졌으면 Free) > 정리 글 만들기(권한 있는 보호자가 있을 때만) > 알림 기록 > 푸시
 * 같은 주 중복 발송은 알림 묶음 키로 차단 (재실행·서버 이중 실행 안전), 이룸이별 실패는 해당 이룸만 건너뜀
 * 푸시 본문은 횟수만 (잠금 화면에 이름·일과 제목 노출 방지)
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
    // 받는 사람: 이룸이를 함께 돌보는 보호자 중 권한 있는 사람, Free 포함 설정이면 나머지도 (요약 알림만)
    List<String> guardianMemberIds = profileGuardianService.guardianMemberIdsOf(profileId);
    List<String> entitledMemberIds = guardianMemberIds.stream()
      .filter(memberId -> entitlementService.isAllowed(memberId, Entitlement.WEEKLY_REPORT))
      .toList();
    List<String> recipientMemberIds = systemConfigService.getBoolean(ConfigKey.WEEKLY_REPORT_PUSH_FREE_ENABLED)
      ? guardianMemberIds : entitledMemberIds;
    if (recipientMemberIds.isEmpty()) {
      return false;
    }
    Optional<WeeklyReportReader.ReportWithNickname> reportWithNickname = weeklyReportReader.aggregateWithNickname(profileId, lastWeek, today);
    if (reportWithNickname.isEmpty() || reportWithNickname.get().report().completedRoutineCount() == 0) {
      return false;
    }
    // 정리 글 만들기: 리포트 화면을 열 수 있는 보호자가 있을 때만 (이미 있으면 그대로, AI 비용은 첫 권한 보호자 계정으로)
    if (!entitledMemberIds.isEmpty()) {
      weeklyReportSummaryService.summaryFor(profileId, reportWithNickname.get().nickname(), entitledMemberIds.get(0),
        lastWeek, reportWithNickname.get().report(), reportWithNickname.get().language(), today);
    }

    NotificationDraft draft = NotificationDraft.weeklyReportReady(profileId, lastWeek.start(), LocalDateTime.now(clock));
    List<RecordedNotification> recorded = notificationRecorder.record(draft, recipientMemberIds);
    String counts = reportWithNickname.get().report().sentRoutineCount() + PushMessageFactory.WEEKLY_REPORT_COUNTS_DELIMITER
      + reportWithNickname.get().report().completedRoutineCount();
    pushDispatcher.dispatch(recorded, NotificationType.WEEKLY_REPORT_READY, counts);
    return recorded.stream().anyMatch(RecordedNotification::shouldPush);
  }
}
