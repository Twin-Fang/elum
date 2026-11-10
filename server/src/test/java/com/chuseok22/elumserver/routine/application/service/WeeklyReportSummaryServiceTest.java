package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse.Summary;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse.SummarySource;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.routine.infrastructure.ai.WeeklyReportSummaryAi;
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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 주간 리포트 정리 글: 스위치·비용 상한·검증 실패가 어떻게 AI 호출과 저장을 막는가
@ExtendWith(MockitoExtension.class)
class WeeklyReportSummaryServiceTest {

  private static final String PROFILE_ID = "profile-1";
  private static final String MEMBER_ID = "member-1";
  // 2026-11-02 월요일이 든 주가 끝난 시점
  private static final LocalDate TODAY = LocalDate.of(2026, 11, 10);
  private static final ReportWeek ENDED_WEEK = ReportWeek.containing(LocalDate.of(2026, 11, 2));

  @Mock
  private WeeklyReportSummaryStore weeklyReportSummaryStore;
  @Mock
  private WeeklyReportSummaryAi weeklyReportSummaryAi;
  @Mock
  private AiDailyBudgetGuard aiDailyBudgetGuard;
  @Mock
  private SystemConfigService systemConfigService;
  @InjectMocks
  private WeeklyReportSummaryService weeklyReportSummaryService;

  private WeeklyReportResponse report;

  @BeforeEach
  void setUp() {
    // 월·화 양치 마침 5개 중 4개... 단순하게: 4개 보냄, 2개 마침
    List<Routine> routines = List.of(
      routine("r1", ENDED_WEEK.start(), RoutineStatus.COMPLETED), routine("r2", ENDED_WEEK.start().plusDays(1), RoutineStatus.COMPLETED),
      routine("r3", ENDED_WEEK.start().plusDays(2), RoutineStatus.CONFIRMED), routine("r4", ENDED_WEEK.start().plusDays(3), RoutineStatus.CONFIRMED));
    report = WeeklyReportAggregator.aggregate(ENDED_WEEK, routines, TODAY);
  }

  @Test
  @DisplayName("AI 스위치가 꺼져 있으면 AI 를 부르지 않고 집계 고정 문장을 준다 — 배포만으로 AI 비용이 나가지 않게")
  void aiSwitchOff_neverCallsAi() {
    when(weeklyReportSummaryStore.find(PROFILE_ID, ENDED_WEEK.start(), "ko")).thenReturn(Optional.empty());
    when(systemConfigService.getBoolean(ConfigKey.WEEKLY_REPORT_AI_ENABLED)).thenReturn(false);

    Summary summary = summaryFor(AppLocale.KO);

    verify(weeklyReportSummaryAi, never()).requestLines(any());
    verify(weeklyReportSummaryStore, never()).save(any(), any(), any(), anyList(), any());
    assertThat(summary.source()).isEqualTo(SummarySource.FALLBACK);
    assertThat(summary.lines().get(0)).isEqualTo("하늘이는 한 주 동안 일과 4개 중 2개를 마쳤어요.");
  }

  @Test
  @DisplayName("AI 가 권유 문장을 써 오면 버리고 고정 문장을 주며, 저장하지 않아 다음 조회에서 다시 시도한다")
  void adviceFromAi_isDiscardedAndNotSaved() {
    givenAiOn();
    when(weeklyReportSummaryAi.requestLines(any())).thenReturn(List.of("{userName}는 일과 4개 중 2개를 마쳤어요.", "카드를 나눠 보세요."));

    Summary summary = summaryFor(AppLocale.KO);

    assertThat(summary.source()).isEqualTo(SummarySource.FALLBACK);
    assertThat(summary.lines()).noneMatch(line -> line.contains("보세요"));
    verify(weeklyReportSummaryStore, never()).save(any(), any(), any(), anyList(), any());
  }

  @Test
  @DisplayName("AI 가 입력에 없는 숫자를 쓰면 버린다")
  void invalidNumberFromAi_isDiscarded() {
    givenAiOn();
    when(weeklyReportSummaryAi.requestLines(any())).thenReturn(List.of("{userName}는 일과 9개를 마쳤어요."));

    assertThat(summaryFor(AppLocale.KO).source()).isEqualTo(SummarySource.FALLBACK);
  }

  @Test
  @DisplayName("AI 호출이 실패해도 리포트는 고정 문장으로 나가고 저장은 하지 않는다")
  void aiFailure_fallsBackWithoutSaving() {
    givenAiOn();
    when(weeklyReportSummaryAi.requestLines(any())).thenThrow(new IllegalStateException("provider down"));

    Summary summary = summaryFor(AppLocale.KO);

    assertThat(summary.source()).isEqualTo(SummarySource.FALLBACK);
    verify(weeklyReportSummaryStore, never()).save(any(), any(), any(), anyList(), any());
  }

  @Test
  @DisplayName("통과한 AI 글은 자리표시를 이름으로 바꿔 돌려주고, {userName} 형태 그대로 저장한다")
  void validAiText_isSavedWithPlaceholderAndRestoredForResponse() {
    givenAiOn();
    List<String> aiLines = List.of("{userName}가 일과 4개 중 2개를 마쳤어요.");
    when(weeklyReportSummaryAi.requestLines(any())).thenReturn(aiLines);

    Summary summary = summaryFor(AppLocale.KO);

    assertThat(summary.source()).isEqualTo(SummarySource.AI);
    assertThat(summary.lines()).containsExactly("하늘이가 일과 4개 중 2개를 마쳤어요.");
    verify(weeklyReportSummaryStore).save(PROFILE_ID, ENDED_WEEK.start(), "ko", aiLines, SummarySource.AI);
  }

  @Test
  @DisplayName("이미 저장된 글이 있으면 AI 를 다시 부르지 않는다 — 한 주 한 번만 비용이 나가게")
  void storedSummary_isReused() {
    when(weeklyReportSummaryStore.find(PROFILE_ID, ENDED_WEEK.start(), "ko")).thenReturn(Optional.of(
      new WeeklyReportSummaryStore.StoredSummary(List.of("{userName}는 일과 4개 중 2개를 마쳤어요."), SummarySource.AI)));

    Summary summary = summaryFor(AppLocale.KO);

    assertThat(summary.lines()).containsExactly("하늘이는 일과 4개 중 2개를 마쳤어요.");
    verify(weeklyReportSummaryAi, never()).requestLines(any());
  }

  @Test
  @DisplayName("진행 중인 이번 주와 마친 일과가 없는 주는 정리 글이 없다 (null)")
  void currentWeekOrNoCompletion_hasNoSummary() {
    ReportWeek currentWeek = ReportWeek.containing(TODAY);
    WeeklyReportResponse currentReport = WeeklyReportAggregator.aggregate(currentWeek,
      List.of(routine("c1", currentWeek.start(), RoutineStatus.COMPLETED)), TODAY);
    WeeklyReportResponse emptyReport = WeeklyReportAggregator.aggregate(ENDED_WEEK,
      List.of(routine("e1", ENDED_WEEK.start(), RoutineStatus.CONFIRMED)), TODAY);

    assertThat(weeklyReportSummaryService.summaryFor(
      PROFILE_ID, "하늘이", MEMBER_ID, currentWeek, currentReport, AppLocale.KO, TODAY)).isNull();
    assertThat(weeklyReportSummaryService.summaryFor(
      PROFILE_ID, "하늘이", MEMBER_ID, ENDED_WEEK, emptyReport, AppLocale.KO, TODAY)).isNull();
    verify(weeklyReportSummaryAi, never()).requestLines(any());
  }

  @Test
  @DisplayName("하루 AI 비용 상한에 닿았으면 AI 를 부르지 않는다")
  void dailyBudgetReached_skipsAi() {
    when(weeklyReportSummaryStore.find(eq(PROFILE_ID), any(), any())).thenReturn(Optional.empty());
    when(systemConfigService.getBoolean(ConfigKey.WEEKLY_REPORT_AI_ENABLED)).thenReturn(true);
    when(aiDailyBudgetGuard.isReached()).thenReturn(true);

    assertThat(summaryFor(AppLocale.KO).source()).isEqualTo(SummarySource.FALLBACK);
    verify(weeklyReportSummaryAi, never()).requestLines(any());
  }

  @Test
  @DisplayName("ko 외 언어 요청은 영어 글(en)로 저장·조회한다 — 지시문과 고정 문장이 ko·en 뿐이라")
  void nonKoreanRequest_usesEnglishSummary() {
    when(weeklyReportSummaryStore.find(PROFILE_ID, ENDED_WEEK.start(), "en")).thenReturn(Optional.empty());
    when(systemConfigService.getBoolean(ConfigKey.WEEKLY_REPORT_AI_ENABLED)).thenReturn(false);

    Summary summary = summaryFor(AppLocale.JA);

    assertThat(summary.lines().get(0)).isEqualTo("하늘이 completed 2 of 4 routines during the week.");
  }

  private void givenAiOn() {
    when(weeklyReportSummaryStore.find(PROFILE_ID, ENDED_WEEK.start(), "ko")).thenReturn(Optional.empty());
    when(systemConfigService.getBoolean(ConfigKey.WEEKLY_REPORT_AI_ENABLED)).thenReturn(true);
    when(aiDailyBudgetGuard.isReached()).thenReturn(false);
  }

  private Summary summaryFor(AppLocale locale) {
    return weeklyReportSummaryService.summaryFor(PROFILE_ID, "하늘이", MEMBER_ID, ENDED_WEEK, report, locale, TODAY);
  }

  private static Routine routine(String id, LocalDate date, RoutineStatus status) {
    Routine routine = new Routine();
    routine.setId(id);
    routine.setTitle("일과 " + id);
    routine.setScheduledAt(LocalDateTime.of(date, java.time.LocalTime.of(8, 0)));
    routine.setStatus(status);
    List<RoutineStep> steps = new ArrayList<>();
    RoutineStep step = new RoutineStep();
    step.setId(id + "-s1");
    step.setStepOrder(1);
    step.setTitle("카드");
    step.setCompleted(status == RoutineStatus.COMPLETED);
    steps.add(step);
    routine.setSteps(steps);
    return routine;
  }
}
