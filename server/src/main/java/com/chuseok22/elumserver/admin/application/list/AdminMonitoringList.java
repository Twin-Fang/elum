package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.ai.core.AiCallType;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * AI 모니터링 목록 선언: 필터 5개(호출 유형, 결과, 회원, 시작일, 종료일), 정렬 허용 열, 기간 보정
 * 기간은 기본 최근 N일(AdminListDefaults.DEFAULT_PERIOD_DAYS, 오늘 포함), 범위 밖·역전 날짜는 보정
 */
public final class AdminMonitoringList {

  /// 필터 키
  public static final String FILTER_CALL_TYPE = "callType";
  public static final String FILTER_SUCCESS = "success";
  public static final String FILTER_MEMBER_ID = "memberId";
  public static final String FILTER_FROM = "from";
  public static final String FILTER_TO = "to";

  /// 정렬 키 (열 키와 같음): 시각 열만 정렬 허용
  public static final String SORT_CREATED_AT = "createdAt";

  public static final String SUCCESS_TRUE = "true";
  public static final String SUCCESS_FALSE = "false";

  // 기간 하한 — 서비스 개시(2026년) 이전이면 충분하다
  static final LocalDate EARLIEST_DATE = LocalDate.of(2000, 1, 1);

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(new Column(SORT_CREATED_AT, "시각", true)),
    List.of(),
    List.of(
      new Filter(FILTER_CALL_TYPE, "호출 유형", Arrays.stream(AiCallType.values())
        .map(type -> new Option(type.name(), type.getLabel())).toList()),
      new Filter(FILTER_SUCCESS, "결과", List.of(
        new Option(SUCCESS_TRUE, "성공"), new Option(SUCCESS_FALSE, "실패"))),
      new Filter(FILTER_MEMBER_ID, "회원", List.of()),
      new Filter(FILTER_FROM, "시작일", List.of()),
      new Filter(FILTER_TO, "종료일", List.of())),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminMonitoringList() {
  }

  /// 기간 보정: 비었거나 형식이 틀리면 기본 기간, 오늘 이후는 오늘, 2000-01-01 이전은 그날, 시작 > 종료면 서로 바꿈
  public static AdminListQuery withCorrectedPeriod(AdminListQuery query, LocalDate today) {
    LocalDate defaultFrom = today.minusDays(AdminListDefaults.DEFAULT_PERIOD_DAYS - 1L);
    LocalDate from = clamp(parseDate(query.filters().get(FILTER_FROM), defaultFrom), today);
    LocalDate to = clamp(parseDate(query.filters().get(FILTER_TO), today), today);
    if (from.isAfter(to)) {
      LocalDate swapped = from;
      from = to;
      to = swapped;
    }
    return query.withFilter(FILTER_FROM, from.toString()).withFilter(FILTER_TO, to.toString());
  }

  /// 기간 시작(포함): 보정된 쿼리 기준
  public static LocalDateTime periodStart(AdminListQuery query) {
    return LocalDate.parse(query.filters().get(FILTER_FROM)).atStartOfDay();
  }

  /// 기간 끝(미포함): 종료일 다음 날 0시
  public static LocalDateTime periodEndExclusive(AdminListQuery query) {
    return LocalDate.parse(query.filters().get(FILTER_TO)).plusDays(1).atStartOfDay();
  }

  public static AiCallType callTypeOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_CALL_TYPE);
    return value == null ? null : AiCallType.valueOf(value);
  }

  /// 결과 필터: 성공 true, 실패 false, 전체 null
  public static Boolean successOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_SUCCESS);
    return value == null ? null : Boolean.valueOf(value);
  }

  public static String memberIdOf(AdminListQuery query) {
    return query.filters().get(FILTER_MEMBER_ID);
  }

  /// 정렬 > 페이지 요청: 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  public static Pageable pageableOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    return PageRequest.of(query.pageIndex(), AdminListDefaults.LOG_PAGE_SIZE,
      Sort.by(new Sort.Order(direction, "createdAt"), new Sort.Order(Sort.Direction.ASC, "id")));
  }

  private static LocalDate parseDate(String raw, LocalDate fallback) {
    if (raw == null) {
      return fallback;
    }
    try {
      return LocalDate.parse(raw);
    } catch (DateTimeParseException e) {
      return fallback;
    }
  }

  private static LocalDate clamp(LocalDate date, LocalDate today) {
    if (date.isAfter(today)) {
      return today;
    }
    return date.isBefore(EARLIEST_DATE) ? EARLIEST_DATE : date;
  }
}
