package com.chuseok22.elumserver.credit.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class CreditPeriodTest {

  @Test
  @DisplayName("일요일 23:59 는 그 주 월요일 0시에 시작한 주기다")
  void sundayNight_belongsToWeekStartingMonday() {
    CreditPeriod period = CreditPeriod.of(LocalDateTime.of(2026, 9, 27, 23, 59));

    assertThat(period.key()).isEqualTo("2026-W39");
    assertThat(period.start()).isEqualTo(LocalDateTime.of(2026, 9, 21, 0, 0));
    assertThat(period.end()).isEqualTo(LocalDateTime.of(2026, 9, 28, 0, 0));
  }

  @Test
  @DisplayName("월요일 0시 정각부터 새 주기다")
  void mondayMidnight_startsNewWeek() {
    CreditPeriod period = CreditPeriod.of(LocalDateTime.of(2026, 9, 28, 0, 0));

    assertThat(period.key()).isEqualTo("2026-W40");
    assertThat(period.start()).isEqualTo(LocalDateTime.of(2026, 9, 28, 0, 0));
  }

  @Test
  @DisplayName("연말 주는 ISO 주 연도를 쓴다 — Postgres IYYY-\"W\"IW 와 같은 키여야 마이그레이션 지급을 찾는다")
  void yearEnd_usesIsoWeekYear() {
    CreditPeriod period = CreditPeriod.of(LocalDateTime.of(2027, 1, 1, 12, 0));

    assertThat(period.key()).isEqualTo("2026-W53");
    assertThat(period.start()).isEqualTo(LocalDateTime.of(2026, 12, 28, 0, 0));
  }

  @Test
  @DisplayName("주기는 시작을 포함하고 끝을 포함하지 않는다")
  void contains_isHalfOpen() {
    CreditPeriod period = CreditPeriod.of(LocalDateTime.of(2026, 9, 23, 12, 0));

    assertThat(period.contains(LocalDateTime.of(2026, 9, 21, 0, 0))).isTrue();
    assertThat(period.contains(LocalDateTime.of(2026, 9, 28, 0, 0))).isFalse();
  }
}
