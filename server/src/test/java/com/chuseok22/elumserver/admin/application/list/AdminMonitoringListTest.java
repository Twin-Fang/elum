package com.chuseok22.elumserver.admin.application.list;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.core.AiCallType;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Sort;

class AdminMonitoringListTest {

  private static final LocalDate TODAY = LocalDate.of(2026, 10, 19);

  private AdminListQuery corrected(String from, String to) {
    Map<String, String> filters = new HashMap<>();
    filters.put("from", from);
    filters.put("to", to);
    return AdminMonitoringList.withCorrectedPeriod(
      AdminListQuery.of(null, filters, null, null, AdminMonitoringList.DEFINITION), TODAY);
  }

  @Test
  @DisplayName("기간을 안 주면 오늘 포함 최근 7일이다")
  void defaultPeriod_isLastSevenDaysIncludingToday() {
    AdminListQuery query = corrected(null, null);

    assertThat(AdminListDefaults.DEFAULT_PERIOD_DAYS).isEqualTo(7);
    assertThat(query.filters()).containsEntry("from", "2026-10-13").containsEntry("to", "2026-10-19");
    assertThat(AdminMonitoringList.periodStart(query)).isEqualTo(LocalDateTime.of(2026, 10, 13, 0, 0));
    assertThat(AdminMonitoringList.periodEndExclusive(query)).isEqualTo(LocalDateTime.of(2026, 10, 20, 0, 0));
  }

  @Test
  @DisplayName("오늘 이후 날짜는 오늘로, 2000-01-01 이전은 그날로 맞춘다")
  void outOfRangeDates_areClamped() {
    AdminListQuery future = corrected("2027-01-01", "2030-12-31");
    AdminListQuery ancient = corrected("1900-05-05", "2026-10-01");

    assertThat(future.filters()).containsEntry("from", "2026-10-19").containsEntry("to", "2026-10-19");
    assertThat(ancient.filters()).containsEntry("from", "2000-01-01").containsEntry("to", "2026-10-01");
  }

  @Test
  @DisplayName("시작일이 종료일보다 늦으면 서로 바꾼다")
  void reversedDates_areSwapped() {
    AdminListQuery query = corrected("2026-10-15", "2026-10-10");

    assertThat(query.filters()).containsEntry("from", "2026-10-10").containsEntry("to", "2026-10-15");
  }

  @Test
  @DisplayName("날짜 형식이 틀리면 그 쪽만 기본값으로 돌아간다")
  void invalidDate_fallsBackToDefault() {
    AdminListQuery query = corrected("어제", "2026-10-17");

    assertThat(query.filters()).containsEntry("from", "2026-10-13").containsEntry("to", "2026-10-17");
  }

  @Test
  @DisplayName("호출 유형·결과는 허용 값만 남기고, 회원은 그대로 받는다")
  void typedFilters_areNormalized() {
    Map<String, String> filters = new HashMap<>();
    filters.put("callType", "GEMINI_IMAGE");
    filters.put("success", "false");
    filters.put("memberId", " m-1 ");
    AdminListQuery ok = AdminMonitoringList.withCorrectedPeriod(
      AdminListQuery.of(null, filters, null, null, AdminMonitoringList.DEFINITION), TODAY);
    Map<String, String> bad = new HashMap<>();
    bad.put("callType", "NOPE");
    bad.put("success", "maybe");
    AdminListQuery dropped = AdminMonitoringList.withCorrectedPeriod(
      AdminListQuery.of(null, bad, null, null, AdminMonitoringList.DEFINITION), TODAY);

    assertThat(AdminMonitoringList.callTypeOf(ok)).isEqualTo(AiCallType.GEMINI_IMAGE);
    assertThat(AdminMonitoringList.successOf(ok)).isFalse();
    assertThat(AdminMonitoringList.memberIdOf(ok)).isEqualTo("m-1");
    assertThat(AdminMonitoringList.callTypeOf(dropped)).isNull();
    assertThat(AdminMonitoringList.successOf(dropped)).isNull();
    assertThat(AdminMonitoringList.memberIdOf(dropped)).isNull();
  }

  @Test
  @DisplayName("정렬은 시각·추정 비용만 허용하고 기본은 시각 내림차순, 한 쪽은 50건이다")
  void sortAndPageSize() {
    AdminListQuery query = AdminListQuery.of(null, null, "memberId,asc", "2", AdminMonitoringList.DEFINITION);

    assertThat(query.sort()).isEqualTo("createdAt,desc");
    assertThat(AdminMonitoringList.pageableOf(query).getPageSize()).isEqualTo(AdminListDefaults.LOG_PAGE_SIZE);
    assertThat(AdminMonitoringList.pageableOf(query).getPageNumber()).isEqualTo(1);
  }

  @Test
  @DisplayName("비용 큰 순: 비용 없는 호출(실패 등)이 맨 앞을 차지하지 않게 뒤로 보낸다")
  void costSort_putsMissingCostLast() {
    AdminListQuery query = AdminListQuery.of(null, null, "estimatedCostUsd,desc", null, AdminMonitoringList.DEFINITION);

    Sort.Order costOrder = AdminMonitoringList.sortOf(query).getOrderFor("estimatedCostUsd");
    assertThat(query.sort()).isEqualTo("estimatedCostUsd,desc");
    assertThat(costOrder).isNotNull();
    assertThat(costOrder.getDirection()).isEqualTo(Sort.Direction.DESC);
    assertThat(costOrder.getNullHandling()).isEqualTo(Sort.NullHandling.NULLS_LAST);
  }
}
