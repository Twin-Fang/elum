package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminDateParameter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefaults;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminListRow;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryCondition;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryService;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

/**
 * 설정 변경 이력 화면: 검색·키·변경자·기간 조건을 이력 검색 조건으로 바꾸고 페이지 조회
 * 범위 밖 페이지는 마지막 페이지로 보정 (건수 상한 없음, 페이지로만 끊음)
 */
@Service
@RequiredArgsConstructor
public class AdminSettingsHistoryService {

  public static final String FILTER_KEY = "key";
  public static final String FILTER_CHANGED_BY = "changedBy";
  public static final String FILTER_FROM = "from";
  public static final String FILTER_TO = "to";

  /** 열 키 = 엔티티 정렬 필드 (그대로 정렬에 쓰므로 허용 목록 밖은 정의가 걸러냄) */
  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column("createdAt", "시각", true),
      new Column("configKey", "설정", true),
      new Column("change", "이전 → 새 값", false),
      new Column("changedBy", "변경자", true),
      new Column("reason", "사유", false)),
    List.of("configKey", "oldValue", "newValue", "changedBy", "reason"),
    List.of(
      new Filter(FILTER_KEY, "설정 키", null),
      new Filter(FILTER_CHANGED_BY, "변경자", null),
      new Filter(FILTER_FROM, "시작일", null),
      new Filter(FILTER_TO, "종료일", null)),
    "createdAt,desc");

  private static final String EMPTY_VALUE_TEXT = "(없음)";
  private static final String NO_REASON_TEXT = "-";

  private final SystemConfigHistoryService historyService;
  private final AdminDateFormatter adminDateFormatter;

  /// 화면에 보낼 한 쪽 결과: 보정된 쿼리, 페이지, 표 행
  public record HistoryPageResult(AdminListQuery query, Page<SystemConfigHistory> page, List<AdminListRow> rows) {
  }

  public HistoryPageResult search(AdminListQuery query) {
    SystemConfigHistoryCondition condition = conditionOf(query);
    Page<SystemConfigHistory> page = fetch(condition, query);
    AdminListQuery corrected = query.withTotalPages(page.getTotalPages());
    // 범위 밖 페이지는 마지막 페이지를 다시 읽음
    if (corrected.page() != query.page()) {
      page = fetch(condition, corrected);
    }
    List<AdminListRow> rows = page.getContent().stream().map(this::toRow).toList();
    return new HistoryPageResult(corrected, page, rows);
  }

  private Page<SystemConfigHistory> fetch(SystemConfigHistoryCondition condition, AdminListQuery query) {
    PageRequest pageable = PageRequest.of(query.pageIndex(), AdminListDefaults.PAGE_SIZE,
      SystemConfigHistoryService.sortOf(query.sortKey(), query.isAscending()));
    return historyService.search(condition, pageable);
  }

  private SystemConfigHistoryCondition conditionOf(AdminListQuery query) {
    Map<String, String> filters = query.filters();
    LocalDate fromDate = parseDate(filters.get(FILTER_FROM));
    LocalDate toDate = parseDate(filters.get(FILTER_TO));
    return new SystemConfigHistoryCondition(
      query.likePattern(), filters.get(FILTER_KEY), filters.get(FILTER_CHANGED_BY),
      fromDate == null ? null : fromDate.atStartOfDay(),
      // 종료일은 그날 끝까지 포함
      toDate == null ? null : toDate.plusDays(1).atStartOfDay());
  }

  /// 읽을 수 없는 날짜는 조건 없음으로 (화면이 깨지지 않게)
  private static LocalDate parseDate(String text) {
    return AdminDateParameter.parseOrNull(text);
  }

  private AdminListRow toRow(SystemConfigHistory history) {
    return new AdminListRow(null, Map.of(
      "createdAt", adminDateFormatter.format(history.getCreatedAt()),
      "configKey", history.getConfigKey(),
      "change", valueText(history.getOldValue()) + " → " + valueText(history.getNewValue()),
      "changedBy", history.getChangedBy() == null ? NO_REASON_TEXT : history.getChangedBy(),
      "reason", history.getReason() == null ? NO_REASON_TEXT : history.getReason()));
  }

  private static String valueText(String value) {
    return value == null || value.isEmpty() ? EMPTY_VALUE_TEXT : value;
  }
}
