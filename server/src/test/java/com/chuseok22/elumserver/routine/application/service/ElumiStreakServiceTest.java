package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.routine.application.service.ElumiStreakService.ProfileStreak;
import com.chuseok22.elumserver.routine.core.ElumiStreak;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository.ProfileCompletionRow;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 끊길 이룸이를 잘못 고르면 이미 오늘 마친 이룸이 보호자나 하루만 한 보호자에게 "연속 기록" 알림이 간다 (#1409)
class ElumiStreakServiceTest {

  private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");
  private static final LocalDate TODAY = LocalDate.of(2026, 11, 14);

  private final RoutineRepository routineRepository = mock(RoutineRepository.class);
  private final ElumiStreakService service = new ElumiStreakService(routineRepository,
    Clock.fixed(TODAY.atTime(18, 0).atZone(SEOUL).toInstant(), SEOUL));

  @Test
  @DisplayName("어제 마친 이룸이 중 오늘 아직이고 2일 이상 이어진 이룸이만 고른다")
  void findProfilesAtRiskToday_filtersTodayAndMinimumDays() {
    LocalDateTime todayStart = TODAY.atStartOfDay();
    when(routineRepository.findProfileIdsCompletedBetween(RoutineStatus.COMPLETED, todayStart.minusDays(1), todayStart))
      .thenReturn(List.of("two-days", "one-day", "done-today"));
    when(routineRepository.findCompletedAtsByProfilesSince(anyCollection(), eq(RoutineStatus.COMPLETED), any()))
      .thenReturn(List.of(
        row("two-days", 1), row("two-days", 2),
        row("one-day", 1),
        row("done-today", 0), row("done-today", 1), row("done-today", 2)));

    List<ProfileStreak> atRisk = service.findProfilesAtRiskToday(TODAY, 2);

    assertThat(atRisk).containsExactly(new ProfileStreak("two-days", 2));
  }

  @Test
  @DisplayName("이룸이가 없으면(null) 기록 없음, 조회도 안 함")
  void streakOf_nullProfile_isNone() {
    assertThat(service.streakOf(null)).isEqualTo(ElumiStreak.NONE);
  }

  @Test
  @DisplayName("한 이룸이 기록: 마친 시각의 날짜로 센다 (어제 밤 11시 완료도 어제)")
  void streakOf_usesCompletionDate() {
    when(routineRepository.findCompletedAtsByProfileSince(eq("p1"), eq(RoutineStatus.COMPLETED), any()))
      .thenReturn(List.of(TODAY.minusDays(1).atTime(23, 0), TODAY.minusDays(2).atTime(7, 0)));

    assertThat(service.streakOf("p1")).isEqualTo(new ElumiStreak(2, true));
  }

  private static ProfileCompletionRow row(String profileId, int daysAgo) {
    LocalDateTime completedAt = TODAY.minusDays(daysAgo).atTime(10, 0);
    return new ProfileCompletionRow() {
      @Override
      public String getProfileId() {
        return profileId;
      }

      @Override
      public LocalDateTime getCompletedAt() {
        return completedAt;
      }
    };
  }
}
