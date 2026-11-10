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

  @Test
  @DisplayName("달 주기는 말일 23:59 까지 그 달이고 1일 0시 정각부터 다음 달이다 — 경계가 어긋나면 지급이 하루 일찍·늦게 바뀐다")
  void month_boundaryIsFirstDayMidnight() {
    CreditPeriod lastMinute = CreditPeriod.of(CreditPeriodUnit.MONTH, LocalDateTime.of(2026, 11, 30, 23, 59));
    CreditPeriod firstInstant = CreditPeriod.of(CreditPeriodUnit.MONTH, LocalDateTime.of(2026, 12, 1, 0, 0));

    assertThat(lastMinute.key()).isEqualTo("2026-M11");
    assertThat(lastMinute.start()).isEqualTo(LocalDateTime.of(2026, 11, 1, 0, 0));
    assertThat(lastMinute.end()).isEqualTo(LocalDateTime.of(2026, 12, 1, 0, 0));
    assertThat(firstInstant.key()).isEqualTo("2026-M12");
    assertThat(firstInstant.end()).isEqualTo(LocalDateTime.of(2027, 1, 1, 0, 0));
    assertThat(lastMinute.unit()).isEqualTo(CreditPeriodUnit.MONTH);
  }

  @Test
  @DisplayName("단위를 고르지 않는 of(시각)은 주 주기다 — 기본 설정(WEEK)이면 키·경계가 이전과 같아야 한다")
  void defaultOf_isWeekPeriodWithSameKeyAsBefore() {
    LocalDateTime wednesday = LocalDateTime.of(2026, 9, 23, 15, 0);

    assertThat(CreditPeriod.of(CreditPeriodUnit.WEEK, wednesday)).isEqualTo(CreditPeriod.of(wednesday));
    assertThat(CreditPeriod.of(wednesday).key()).isEqualTo("2026-W39");
    assertThat(CreditPeriod.of(wednesday).unit()).isEqualTo(CreditPeriodUnit.WEEK);
  }

  @Test
  @DisplayName("달 키는 period_key 길이 10 안이고 주 키와 겹치지 않는다 — 겹치면 전환 때 유니크 제약이 새 지급을 막는다")
  void monthKey_fitsColumnAndNeverEqualsWeekKey() {
    for (int month = 1; month <= 12; month++) {
      String monthKey = CreditPeriod.of(CreditPeriodUnit.MONTH, LocalDateTime.of(2026, month, 15, 0, 0)).key();
      String weekKey = CreditPeriod.of(CreditPeriodUnit.WEEK, LocalDateTime.of(2026, month, 15, 0, 0)).key();

      assertThat(monthKey).hasSizeLessThanOrEqualTo(10).isNotEqualTo(weekKey);
    }
  }

  @Test
  @DisplayName("키로 주기를 되살리고 앞뒤 주기를 같은 단위로 구한다 — 관리자 화면의 이전·다음 이동이 단위를 넘지 않는다")
  void fromKey_previousAndNext_keepUnit() {
    CreditPeriod november = CreditPeriod.fromKey("2026-M11").orElseThrow();
    CreditPeriod week = CreditPeriod.fromKey("2026-W39").orElseThrow();

    assertThat(november.previous().key()).isEqualTo("2026-M10");
    assertThat(november.next().key()).isEqualTo("2026-M12");
    assertThat(CreditPeriod.fromKey("2026-M01").orElseThrow().previous().key()).isEqualTo("2025-M12");
    assertThat(week.previous().key()).isEqualTo("2026-W38");
    assertThat(week.next().key()).isEqualTo("2026-W40");
    assertThat(CreditPeriod.fromKey("2026-M13")).isEmpty();
    assertThat(CreditPeriod.fromKey("garbage")).isEmpty();
    assertThat(CreditPeriod.fromKey(null)).isEmpty();
  }

  @Test
  @DisplayName("다른 단위의 키는 지난 주기로 보지 않는다 — 전환 직후 주간 지급분이 바로 만료되면 사용자가 받은 크레딧을 잃는다")
  void isOtherPeriodKeyOfSameUnit_ignoresOtherUnit() {
    CreditPeriod november = CreditPeriod.of(CreditPeriodUnit.MONTH, LocalDateTime.of(2026, 11, 10, 0, 0));

    assertThat(november.isOtherPeriodKeyOfSameUnit("2026-W45")).isFalse();
    assertThat(november.isOtherPeriodKeyOfSameUnit("2026-M11")).isFalse();
    assertThat(november.isOtherPeriodKeyOfSameUnit("2026-M10")).isTrue();
  }

  @Test
  @DisplayName("설정 값이 비었거나 모르는 값이면 WEEK 다 — 설정을 잘못 저장해도 지급 주기가 깨지지 않는다")
  void unitFromConfigValue_defaultsToWeek() {
    assertThat(CreditPeriodUnit.fromConfigValue(null)).isEqualTo(CreditPeriodUnit.WEEK);
    assertThat(CreditPeriodUnit.fromConfigValue("")).isEqualTo(CreditPeriodUnit.WEEK);
    assertThat(CreditPeriodUnit.fromConfigValue("YEAR")).isEqualTo(CreditPeriodUnit.WEEK);
    assertThat(CreditPeriodUnit.fromConfigValue(" month ")).isEqualTo(CreditPeriodUnit.MONTH);
  }

  @Test
  @DisplayName("설정 키 선택지는 주기 단위 이름과 같고 기본값은 WEEK 다 — 어긋나면 관리자가 고른 값을 코드가 WEEK 로 읽는다")
  void configKey_matchesUnitNamesAndDefaultsToWeek() {
    assertThat(com.chuseok22.elumserver.systemconfig.core.ConfigKey.CREDIT_PERIOD_UNIT.getAllowedValues())
      .containsExactly(CreditPeriodUnit.WEEK.name(), CreditPeriodUnit.MONTH.name());
    assertThat(com.chuseok22.elumserver.systemconfig.core.ConfigKey.CREDIT_PERIOD_UNIT.getDefaultValue())
      .isEqualTo(CreditPeriodUnit.WEEK.name());
  }
}
