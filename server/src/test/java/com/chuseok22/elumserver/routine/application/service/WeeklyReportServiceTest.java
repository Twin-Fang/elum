package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse.RemainingStep;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 주간 리포트(#1074): Free 403 · 첫 주 미리 보기 · 미래 주 400 · 집계 규칙(완료율·별·연속·묶음·남은 카드)
@ExtendWith(MockitoExtension.class)
class WeeklyReportServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final String PROFILE_ID = "profile-1";

  @Mock
  private WeeklyReportReader weeklyReportReader;
  @Mock
  private WeeklyReportSummaryService weeklyReportSummaryService;
  @Mock
  private ProfileAccessGuard profileAccessGuard;
  @Mock
  private EntitlementService entitlementService;
  @Mock
  private SystemConfigService systemConfigService;
  @InjectMocks
  private WeeklyReportService weeklyReportService;

  @Test
  @DisplayName("요금제에 주간 리포트가 없고 미리 보기도 꺼져 있으면 403 WEEKLY_REPORT_NOT_ALLOWED 이고 일과를 읽지 않는다")
  void freePlan_isRejected() {
    givenProfile();
    doThrow(new CustomException(Entitlement.WEEKLY_REPORT.rejectionCode())).when(entitlementService).requireAllowed("member-1", Entitlement.WEEKLY_REPORT);

    assertThatThrownBy(() -> weeklyReportService.getWeeklyReport(GUARDIAN, null))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.WEEKLY_REPORT_NOT_ALLOWED);
    verify(weeklyReportReader, never()).aggregate(any(), any(), any());
    verify(weeklyReportReader, never()).findEarliestRecordedWeekStart(any());
  }

  @Test
  @DisplayName("이번 주보다 뒤의 주는 400 INVALID_INPUT_VALUE")
  void futureWeek_isRejected() {
    givenProfile();
    givenProEntitlement();

    assertThatThrownBy(() -> weeklyReportService.getWeeklyReport(GUARDIAN, LocalDate.now().plusWeeks(1)))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_INPUT_VALUE);
  }

  @Test
  @DisplayName("주 중간 날짜를 주면 그 주 월요일로 맞춰 집계하고, 정리 글을 붙여 돌려준다")
  void weekIsNormalizedToMonday_andSummaryAttached() {
    givenProfile();
    givenProEntitlement();
    ReportWeek lastWeek = ReportWeek.containing(LocalDate.now().minusWeeks(1));
    WeeklyReportResponse aggregated = WeeklyReportAggregator.aggregate(lastWeek, List.of(), LocalDate.now());
    when(weeklyReportReader.aggregate(eq(PROFILE_ID), eq(lastWeek), any())).thenReturn(aggregated);
    WeeklyReportResponse.Summary summary = new WeeklyReportResponse.Summary(
      List.of("정리"), WeeklyReportResponse.SummarySource.FALLBACK);
    when(weeklyReportSummaryService.summaryFor(eq(PROFILE_ID), any(), eq("member-1"), eq(lastWeek), eq(aggregated), any(), any()))
      .thenReturn(summary);

    WeeklyReportResponse report = weeklyReportService.getWeeklyReport(GUARDIAN, lastWeek.start().plusDays(3));

    assertThat(report.weekStart()).isEqualTo(lastWeek.start());
    assertThat(report.summary()).isEqualTo(summary);
  }

  @Test
  @DisplayName("미리 보기가 켜져 있으면 권한 없는 회원도 마친 일과가 있는 가장 이른 주 한 주는 본다")
  void freePlan_firstWeekPreviewOn_allowsEarliestWeekOnly() {
    givenProfile();
    when(systemConfigService.getBoolean(ConfigKey.FREE_WEEKLY_REPORT_FIRST_WEEK_PREVIEW)).thenReturn(true);
    ReportWeek firstWeek = ReportWeek.containing(LocalDate.now().minusWeeks(3));
    when(weeklyReportReader.findEarliestRecordedWeekStart(PROFILE_ID)).thenReturn(Optional.of(firstWeek.start()));
    when(weeklyReportReader.aggregate(eq(PROFILE_ID), eq(firstWeek), any()))
      .thenReturn(WeeklyReportAggregator.aggregate(firstWeek, List.of(), LocalDate.now()));

    assertThat(weeklyReportService.getWeeklyReport(GUARDIAN, firstWeek.start()).weekStart()).isEqualTo(firstWeek.start());

    // 그 다음 주는 잠김 (지금처럼 403)
    LocalDate secondWeekStart = firstWeek.start().plusWeeks(1);
    assertThatThrownBy(() -> weeklyReportService.getWeeklyReport(GUARDIAN, secondWeekStart))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.WEEKLY_REPORT_NOT_ALLOWED);
  }

  @Test
  @DisplayName("미리 보기가 켜져 있어도 마친 일과가 하나도 없으면 어떤 주도 열리지 않는다")
  void freePlan_firstWeekPreviewOn_noRecords_isRejected() {
    givenProfile();
    when(systemConfigService.getBoolean(ConfigKey.FREE_WEEKLY_REPORT_FIRST_WEEK_PREVIEW)).thenReturn(true);
    when(weeklyReportReader.findEarliestRecordedWeekStart(PROFILE_ID)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> weeklyReportService.getWeeklyReport(GUARDIAN, null))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.WEEKLY_REPORT_NOT_ALLOWED);
  }

  @Test
  @DisplayName("주 목록의 미리 보기 주는 설정이 켜지고 권한이 없을 때만 내려간다 (Pro 에게 잠금 표시가 뜨지 않게)")
  void recordedWeeks_previewOnlyForFreeWithSwitchOn() {
    givenProfile();
    LocalDate firstWeekStart = ReportWeek.containing(LocalDate.now().minusWeeks(5)).start();
    when(weeklyReportReader.listRecordedWeeks(PROFILE_ID)).thenReturn(List.of());
    when(systemConfigService.getBoolean(ConfigKey.FREE_WEEKLY_REPORT_FIRST_WEEK_PREVIEW)).thenReturn(true);
    when(weeklyReportReader.findEarliestRecordedWeekStart(PROFILE_ID)).thenReturn(Optional.of(firstWeekStart));

    assertThat(weeklyReportService.getRecordedWeeks(GUARDIAN).freePreviewWeekStart()).isEqualTo(firstWeekStart);

    when(entitlementService.isAllowed("member-1", Entitlement.WEEKLY_REPORT)).thenReturn(true);
    assertThat(weeklyReportService.getRecordedWeeks(GUARDIAN).freePreviewWeekStart()).isNull();
  }

  @Test
  @DisplayName("집계: 완료율 반올림, 별 = 마친 카드 수, 보상은 개수만, 같은 원본은 한 줄, 연속 날, 지난 날 남은 카드")
  void aggregate_countsFactsOnly() {
    ReportWeek week = ReportWeek.containing(LocalDate.of(2026, 11, 2));
    LocalDate monday = week.start();
    LocalDate today = monday.plusDays(4); // 금요일

    // 월·화: 양치 원본에서 보낸 일과 마침 (보상 있음)
    Routine brushMonday = routine("b1", "brush", monday, RoutineStatus.COMPLETED, true);
    brushMonday.setRewardText("젤리");
    Routine brushTuesday = routine("b2", "brush", monday.plusDays(1), RoutineStatus.COMPLETED, true);
    // 수: 양치 안 마침 (카드 2장 중 1장만), 가방 챙기기 안 마침
    Routine brushWednesday = routine("b3", "brush", monday.plusDays(2), RoutineStatus.CONFIRMED, false);
    brushWednesday.getSteps().get(0).setCompleted(true);
    Routine bagWednesday = routine("g1", null, monday.plusDays(2), RoutineStatus.CONFIRMED, false);
    // 금(오늘): 진행 중 — 남은 카드로 세지 않음
    Routine brushToday = routine("b4", "brush", today, RoutineStatus.CONFIRMED, false);

    WeeklyReportResponse report = WeeklyReportAggregator.aggregate(week,
      List.of(brushMonday, brushTuesday, brushWednesday, bagWednesday, brushToday), today);

    assertThat(report.isCurrentWeek()).isTrue();
    assertThat(report.sentRoutineCount()).isEqualTo(5);
    assertThat(report.completedRoutineCount()).isEqualTo(2);
    assertThat(report.completionPercent()).isEqualTo(40);
    assertThat(report.starsEarned()).isEqualTo(5); // 2 + 2 + 1
    assertThat(report.rewardReachedCount()).isEqualTo(1);
    assertThat(report.longestCompletedDayStreak()).isEqualTo(2);
    assertThat(report.days().get(2).sentCount()).isEqualTo(2);
    assertThat(report.days().get(2).completedCount()).isZero();

    // 같은 원본(brush) 4번 보냄 2번 마침 > 한 줄, 마친 횟수 많은 순으로 맨 위
    assertThat(report.routines()).hasSize(2);
    assertThat(report.routines().get(0).title()).isEqualTo("일과 brush");
    assertThat(report.routines().get(0).sentCount()).isEqualTo(4);
    assertThat(report.routines().get(0).completedCount()).isEqualTo(2);

    // 수요일 남은 카드: 양치 카드2 1번, 가방 카드1·카드2 각 1번 > 최대 3개, 오늘 일과 제외
    assertThat(report.remainingSteps()).hasSize(3)
      .extracting(RemainingStep::remainingCount).containsOnly(1);
    assertThat(report.remainingSteps()).extracting(RemainingStep::stepTitle)
      .containsExactly("카드 2", "카드 1", "카드 2");
  }

  @Test
  @DisplayName("보낸 일과가 없으면 완료율 0 · 연속 0 · 빈 목록 (0으로 나누지 않음)")
  void aggregate_emptyWeek() {
    ReportWeek week = ReportWeek.containing(LocalDate.of(2026, 11, 2));

    WeeklyReportResponse report = WeeklyReportAggregator.aggregate(week, List.of(), LocalDate.of(2026, 11, 20));

    assertThat(report.completionPercent()).isZero();
    assertThat(report.longestCompletedDayStreak()).isZero();
    assertThat(report.routines()).isEmpty();
    assertThat(report.remainingSteps()).isEmpty();
  }

  private void givenProEntitlement() {
    when(entitlementService.isAllowed("member-1", Entitlement.WEEKLY_REPORT)).thenReturn(true);
  }

  private void givenProfile() {
    Profile profile = new Profile();
    profile.setId(PROFILE_ID);
    when(profileAccessGuard.profileFor(GUARDIAN, ProfileAction.MANAGE)).thenReturn(profile);
  }

  /// 카드 2장짜리 일과. sourceId: 보낸 원본 (null 이면 자기 자신이 원본)
  private static Routine routine(String id, String sourceId, LocalDate date, RoutineStatus status, boolean isAllDone) {
    Routine routine = new Routine();
    routine.setId(id);
    routine.setSourceRoutineId(sourceId);
    routine.setTitle("일과 " + (sourceId == null ? id : sourceId));
    routine.setScheduledAt(LocalDateTime.of(date, java.time.LocalTime.of(8, 0)));
    routine.setStatus(status);
    List<RoutineStep> steps = new ArrayList<>();
    for (int order = 1; order <= 2; order++) {
      RoutineStep step = new RoutineStep();
      step.setId(id + "-s" + order);
      step.setStepOrder(order);
      step.setTitle("카드 " + order);
      step.setDescription("설명 " + order);
      step.setCompleted(isAllDone);
      steps.add(step);
    }
    routine.setSteps(steps);
    return routine;
  }
}
