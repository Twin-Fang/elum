package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.application.stats.StatsBucketCount;
import com.chuseok22.elumserver.common.application.stats.StatsBucketUnit;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 추이 칸 채우기: DB 는 기록 있는 칸만 줌 > 빈 칸 0, 방문 기록 시작 전 칸 null
 * 깨지면 그래프가 날짜를 건너뛰거나, 기록 전 기간이 "방문 0명"으로 거짓 표시된다
 */
class AdminStatsServiceFillTest {

  private static StatsBucketCount row(String bucket, long total) {
    return new StatsBucketCount() {
      @Override
      public String getBucket() {
        return bucket;
      }

      @Override
      public long getTotal() {
        return total;
      }
    };
  }

  @Test
  @DisplayName("기록 없는 날은 0으로 채우고 날짜 순서를 지킨다")
  void fillsMissingDaysWithZero() {
    List<LocalDate> days = StatsBucketUnit.DAY.bucketStartsBetween(LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 4));

    List<Number> counts = AdminStatsService.fillCounts(days, List.of(row("2026-10-03", 5), row("2026-10-01", 2)));

    assertThat(counts).containsExactly(2L, 0L, 5L, 0L);
  }

  @Test
  @DisplayName("방문 기록 시작일 이전 칸은 null, 시작일이 든 칸부터 값")
  void blanksBucketsBeforeTrackingStart() {
    List<LocalDate> days = StatsBucketUnit.DAY.bucketStartsBetween(LocalDate.of(2026, 10, 18), LocalDate.of(2026, 10, 21));
    List<Number> counts = AdminStatsService.fillCounts(days, List.of(row("2026-10-20", 7)));

    AdminStatsService.blankBeforeTrackingStart(StatsBucketUnit.DAY, days, counts, LocalDate.of(2026, 10, 20));

    assertThat(counts).containsExactly(null, null, 7L, 0L);
  }

  @Test
  @DisplayName("월별은 그달 1일 칸으로 묶고, 칸 수 상한(36달)을 넘으면 최근 칸만 남긴다")
  void monthBucketsAreCapped() {
    List<LocalDate> months = StatsBucketUnit.MONTH.bucketStartsBetween(LocalDate.of(2020, 1, 15), LocalDate.of(2026, 10, 20));

    assertThat(months).hasSize(36);
    assertThat(months.get(35)).isEqualTo(LocalDate.of(2026, 10, 1));
  }
}
