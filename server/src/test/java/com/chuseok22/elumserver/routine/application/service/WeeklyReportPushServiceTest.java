package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.ProfileGuardianService;
import com.chuseok22.elumserver.notification.application.service.NotificationRecorder;
import com.chuseok22.elumserver.notification.application.service.PushDispatcher;
import com.chuseok22.elumserver.notification.application.service.RecordedNotification;
import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/// 주간 리포트 월요일 알림: 스위치·권한·같은 주 한 번·실패 격리·건수 상한
class WeeklyReportPushServiceTest {

  // 2026-11-09 월요일 08:00 (한국 시각) > 지난주 = 2026-11-02 주
  private static final Clock MONDAY_EIGHT = Clock.fixed(Instant.parse("2026-11-08T23:00:00Z"), java.time.ZoneId.of("Asia/Seoul"));
  private static final ReportWeek LAST_WEEK = ReportWeek.containing(LocalDate.of(2026, 11, 2));

  private SystemConfigService systemConfigService;
  private WeeklyReportReader weeklyReportReader;
  private WeeklyReportSummaryService weeklyReportSummaryService;
  private ProfileGuardianService profileGuardianService;
  private EntitlementService entitlementService;
  private NotificationRecorder notificationRecorder;
  private PushDispatcher pushDispatcher;
  private WeeklyReportPushService weeklyReportPushService;

  @BeforeEach
  void setUp() {
    systemConfigService = mock(SystemConfigService.class);
    weeklyReportReader = mock(WeeklyReportReader.class);
    weeklyReportSummaryService = mock(WeeklyReportSummaryService.class);
    profileGuardianService = mock(ProfileGuardianService.class);
    entitlementService = mock(EntitlementService.class);
    notificationRecorder = mock(NotificationRecorder.class);
    pushDispatcher = mock(PushDispatcher.class);
    weeklyReportPushService = new WeeklyReportPushService(systemConfigService, weeklyReportReader,
      weeklyReportSummaryService, profileGuardianService, entitlementService, notificationRecorder, pushDispatcher,
      MONDAY_EIGHT);
  }

  @Test
  @DisplayName("알림 스위치가 꺼져 있으면 대상 조회도 하지 않는다 — 배포만으로 알림이 나가지 않게")
  void pushSwitchOff_doesNothing() {
    when(systemConfigService.getBoolean(ConfigKey.WEEKLY_REPORT_PUSH_ENABLED)).thenReturn(false);

    weeklyReportPushService.runOnce();

    verify(weeklyReportReader, never()).findProfileIdsWithCompletedRoutines(any());
    verify(notificationRecorder, never()).record(any(), anyCollection());
  }

  @Test
  @DisplayName("주간 리포트 권한이 있는 보호자에게만 알림을 기록한다 — Free 보호자에게 못 여는 리포트 알림이 가지 않게")
  void onlyEntitledGuardiansAreNotified() {
    givenPushOnWithProfiles("p1");
    when(profileGuardianService.guardianMemberIdsOf("p1")).thenReturn(List.of("pro-guardian", "free-guardian"));
    when(entitlementService.isAllowed("pro-guardian", Entitlement.WEEKLY_REPORT)).thenReturn(true);
    when(entitlementService.isAllowed("free-guardian", Entitlement.WEEKLY_REPORT)).thenReturn(false);
    givenCompletedWeek("p1");
    when(notificationRecorder.record(any(), anyCollection())).thenReturn(List.of(new RecordedNotification("n1", "pro-guardian", 1, true)));

    weeklyReportPushService.runOnce();

    @SuppressWarnings("unchecked")
    ArgumentCaptor<Collection<String>> recipients = ArgumentCaptor.forClass(Collection.class);
    ArgumentCaptor<NotificationDraft> draft = ArgumentCaptor.forClass(NotificationDraft.class);
    verify(notificationRecorder).record(draft.capture(), recipients.capture());
    assertThat(recipients.getValue()).containsExactly("pro-guardian");
    assertThat(draft.getValue().type()).isEqualTo(NotificationType.WEEKLY_REPORT_READY);
    assertThat(draft.getValue().targetId()).isEqualTo("2026-11-02");
    // 푸시 본문 인자는 보낸·마친 횟수뿐 (이름·일과 제목 없음)
    verify(pushDispatcher).dispatch(any(), eq(NotificationType.WEEKLY_REPORT_READY), eq("4,2"));
  }

  @Test
  @DisplayName("권한 있는 보호자가 없으면 정리 글도 만들지 않는다 — 안 볼 글에 AI 비용이 나가지 않게")
  void noEntitledGuardian_skipsSummaryAndNotification() {
    givenPushOnWithProfiles("p1");
    when(profileGuardianService.guardianMemberIdsOf("p1")).thenReturn(List.of("free-guardian"));

    weeklyReportPushService.runOnce();

    verify(weeklyReportSummaryService, never()).summaryFor(any(), any(), any(), any(), any(), any(), any());
    verify(notificationRecorder, never()).record(any(), anyCollection());
  }

  @Test
  @DisplayName("같은 이룸이·같은 주는 알림 묶음 키가 같고 다음 주는 다르다 — 재실행해도 한 번만 가고 새 주는 다시 간다")
  void sameWeekSameGroupKey() {
    NotificationDraft first = NotificationDraft.weeklyReportReady("p1", LocalDate.of(2026, 11, 2), null);
    NotificationDraft again = NotificationDraft.weeklyReportReady("p1", LocalDate.of(2026, 11, 2), null);
    NotificationDraft nextWeek = NotificationDraft.weeklyReportReady("p1", LocalDate.of(2026, 11, 9), null);

    assertThat(again.groupKey()).isEqualTo(first.groupKey());
    assertThat(nextWeek.groupKey()).isNotEqualTo(first.groupKey());
  }

  @Test
  @DisplayName("이룸이 하나가 실패해도 다음 이룸이는 계속 처리한다")
  void oneProfileFailure_doesNotStopOthers() {
    givenPushOnWithProfiles("p1", "p2");
    when(profileGuardianService.guardianMemberIdsOf("p1")).thenThrow(new IllegalStateException("db down"));
    when(profileGuardianService.guardianMemberIdsOf("p2")).thenReturn(List.of("g2"));
    when(entitlementService.isAllowed("g2", Entitlement.WEEKLY_REPORT)).thenReturn(true);
    givenCompletedWeek("p2");
    when(notificationRecorder.record(any(), anyCollection())).thenReturn(List.of(new RecordedNotification("n2", "g2", 1, true)));

    weeklyReportPushService.runOnce();

    verify(notificationRecorder, times(1)).record(any(), anyCollection());
  }

  @Test
  @DisplayName("한 번 실행에 새로 알리는 이룸이는 상한까지만 — 이미 보낸 이룸이는 세지 않아 재실행이 뒤 이룸이로 이어진다")
  void newlyNotifiedProfiles_areCapped_alreadyNotifiedAreNotCounted() {
    int alreadyNotifiedCount = 5;
    int cap = WeeklyReportPushService.MAX_NEWLY_NOTIFIED_PROFILES_PER_RUN;
    List<String> profileIds = new ArrayList<>();
    for (int index = 0; index < alreadyNotifiedCount + cap + 5; index++) {
      profileIds.add("p" + index);
    }
    givenPushOnWithProfiles(profileIds.toArray(String[]::new));
    when(profileGuardianService.guardianMemberIdsOf(any())).thenReturn(List.of("g"));
    when(entitlementService.isAllowed("g", Entitlement.WEEKLY_REPORT)).thenReturn(true);
    when(weeklyReportReader.aggregateWithNickname(any(), eq(LAST_WEEK), any())).thenReturn(Optional.of(completedReport()));
    // 앞 5개 이룸이는 이미 보낸 주 (기록 결과가 푸시 대상 아님)
    List<String> alreadyNotifiedIds = profileIds.subList(0, alreadyNotifiedCount);
    when(notificationRecorder.record(any(), anyCollection())).thenAnswer(invocation -> {
      NotificationDraft draft = invocation.getArgument(0);
      boolean isNew = !alreadyNotifiedIds.contains(draft.profileId());
      return List.of(new RecordedNotification("n", "g", 1, isNew));
    });

    weeklyReportPushService.runOnce();

    verify(notificationRecorder, times(alreadyNotifiedCount + cap)).record(any(), anyCollection());
  }

  private void givenPushOnWithProfiles(String... profileIds) {
    when(systemConfigService.getBoolean(ConfigKey.WEEKLY_REPORT_PUSH_ENABLED)).thenReturn(true);
    when(weeklyReportReader.findProfileIdsWithCompletedRoutines(LAST_WEEK)).thenReturn(List.of(profileIds));
  }

  private void givenCompletedWeek(String profileId) {
    when(weeklyReportReader.aggregateWithNickname(eq(profileId), eq(LAST_WEEK), any()))
      .thenReturn(Optional.of(completedReport()));
  }

  private static WeeklyReportReader.ReportWithNickname completedReport() {
    WeeklyReportResponse report = new WeeklyReportResponse(LAST_WEEK.start(), LAST_WEEK.lastDay(), false, 4, 2, 50, 2, 0,
      2, List.of(), List.of(), List.of(), null);
    return new WeeklyReportReader.ReportWithNickname(report, "하늘이", AppLocale.KO);
  }
}
