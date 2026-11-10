package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportWeeksResponse;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 주간 리포트 읽기: 일과관리 복사본 제외 · 주 목록 묶음과 26개 상한
@ExtendWith(MockitoExtension.class)
class WeeklyReportReaderTest {

  private static final String PROFILE_ID = "profile-1";

  @Mock
  private RoutineRepository routineRepository;
  @InjectMocks
  private WeeklyReportReader weeklyReportReader;

  @Test
  @DisplayName("일과관리 복사본은 집계에서 빠진다 — 세면 보낸 적 없는 일과가 완료율을 흔든다")
  void aggregate_excludesLibraryCopies() {
    ReportWeek lastWeek = ReportWeek.containing(LocalDate.now().minusWeeks(1));
    Routine libraryCopy = routineAt(lastWeek.start().atTime(8, 0));
    libraryCopy.setLibraryOnly(true);
    when(routineRepository.findAllByProfileIdAndStatusInAndScheduledAtBetweenOrderByScheduledAtAsc(
      eq(PROFILE_ID), anyList(), eq(lastWeek.startAt()), eq(lastWeek.lastMoment())))
      .thenReturn(List.of(libraryCopy));

    WeeklyReportResponse report = weeklyReportReader.aggregate(PROFILE_ID, lastWeek, LocalDate.now());

    assertThat(report.sentRoutineCount()).isZero();
    assertThat(report.weekEnd()).isEqualTo(lastWeek.start().plusDays(6));
  }

  @Test
  @DisplayName("마친 일과를 주별로 묶어 최신순으로 세고, 27번째 주부터는 목록에 넣지 않는다")
  void listRecordedWeeks_groupsByWeekAndCapsAtTwentySix() {
    LocalDate thisMonday = ReportWeek.containing(LocalDate.now()).start();
    List<LocalDateTime> completedAts = new ArrayList<>();
    // 이번 주 2건 + 그 뒤 매주 1건씩 29주 (최신순)
    completedAts.add(thisMonday.plusDays(2).atTime(LocalTime.NOON));
    completedAts.add(thisMonday.atTime(LocalTime.NOON));
    for (int weeksAgo = 1; weeksAgo <= 29; weeksAgo++) {
      completedAts.add(thisMonday.minusWeeks(weeksAgo).plusDays(1).atTime(LocalTime.NOON));
    }
    when(routineRepository.findScheduledAtsByProfileIdAndStatus(eq(PROFILE_ID), eq(RoutineStatus.COMPLETED), any()))
      .thenReturn(completedAts);

    List<WeeklyReportWeeksResponse.Week> weeks = weeklyReportReader.listRecordedWeeks(PROFILE_ID);

    assertThat(weeks).hasSize(WeeklyReportReader.MAX_LISTED_WEEKS);
    assertThat(weeks.get(0)).isEqualTo(new WeeklyReportWeeksResponse.Week(thisMonday, 2));
    assertThat(weeks.get(1).weekStart()).isEqualTo(thisMonday.minusWeeks(1));
    assertThat(weeks.get(WeeklyReportReader.MAX_LISTED_WEEKS - 1).weekStart())
      .isEqualTo(thisMonday.minusWeeks(WeeklyReportReader.MAX_LISTED_WEEKS - 1L));
  }

  @Test
  @DisplayName("가장 이른 완료 기록의 날짜가 든 주의 월요일이 미리 보기 주가 된다 (일요일 밤 기록도 그 주)")
  void findEarliestRecordedWeekStart_isMondayOfThatWeek() {
    LocalDate sunday = LocalDate.of(2026, 11, 1);
    when(routineRepository.findEarliestScheduledAtByProfileIdAndStatus(PROFILE_ID, RoutineStatus.COMPLETED))
      .thenReturn(sunday.atTime(23, 30));

    assertThat(weeklyReportReader.findEarliestRecordedWeekStart(PROFILE_ID)).contains(LocalDate.of(2026, 10, 26));
  }

  private static Routine routineAt(LocalDateTime scheduledAt) {
    Routine routine = new Routine();
    routine.setId("r-" + scheduledAt);
    routine.setTitle("일과");
    routine.setScheduledAt(scheduledAt);
    routine.setStatus(RoutineStatus.COMPLETED);
    routine.setSteps(new ArrayList<>());
    return routine;
  }
}
