package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 일과 목록 선언: 열, 필터 4개(상태, 보호자, 예정일 기간), 정렬 허용 열, 응답 > 표 행 변환
 * 정렬은 isSortable 열만 허용되고 그 밖은 기본 정렬(최근 변경순)로 돌아감
 */
public final class AdminRoutineList {

  /// 필터 키: 일과 상태
  public static final String FILTER_STATUS = "status";
  /// 필터 키: 보호자 (만든 보호자의 회원 ID 그대로, 아이디·닉네임 일부)
  public static final String FILTER_GUARDIAN = "guardian";
  /// 필터 키: 예정일 기간 (yyyy-MM-dd, 비우면 제한 없음)
  public static final String FILTER_SCHEDULED_FROM = "scheduledFrom";
  public static final String FILTER_SCHEDULED_TO = "scheduledTo";
  /// 예정일 필터가 없을 때 쿼리에 넣는 끝값 (null 바인딩 대신)
  private static final LocalDateTime UNBOUNDED_PERIOD_FROM = LocalDateTime.of(2000, 1, 1, 0, 0);
  private static final LocalDateTime UNBOUNDED_PERIOD_TO = LocalDateTime.of(9999, 1, 1, 0, 0);
  /// 정렬 키 (열 키와 같음)
  public static final String SORT_TITLE = "title";
  public static final String SORT_STATUS = "status";
  public static final String SORT_SCHEDULED_AT = "scheduledAt";
  public static final String SORT_COMPLETED_AT = "completedAt";
  public static final String SORT_UPDATED_AT = "updatedAt";

  public static final String COLUMN_MEMBER = "member";
  private static final String COLUMN_PROFILE = "profile";
  private static final String COLUMN_LANGUAGE = "language";
  private static final String BLANK_TEXT = "-";

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_TITLE, "제목", true),
      new Column(COLUMN_MEMBER, "보호자", false),
      new Column(COLUMN_PROFILE, "이룸이", false),
      new Column(SORT_STATUS, "상태", true),
      new Column(COLUMN_LANGUAGE, "언어", false),
      new Column(SORT_SCHEDULED_AT, "예정일시", true),
      new Column(SORT_COMPLETED_AT, "완료일시", true),
      new Column(SORT_UPDATED_AT, "마지막 변경", true)),
    List.of("title", "profile.nickname"),
    List.of(
      new Filter(FILTER_STATUS, "상태", List.of(
        new Option(RoutineStatus.PENDING_REVIEW.name(), statusLabel(RoutineStatus.PENDING_REVIEW)),
        new Option(RoutineStatus.CONFIRMED.name(), statusLabel(RoutineStatus.CONFIRMED)),
        new Option(RoutineStatus.COMPLETED.name(), statusLabel(RoutineStatus.COMPLETED)))),
      Filter.text(FILTER_GUARDIAN, "보호자"),
      Filter.date(FILTER_SCHEDULED_FROM, "예정일 시작"),
      Filter.date(FILTER_SCHEDULED_TO, "예정일 끝")),
    SORT_UPDATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminRoutineList() {
  }

  /// 예정일 기간 시작(포함): 비면 제한 없음
  public static LocalDateTime scheduledFromOf(AdminListQuery query) {
    LocalDate from = AdminDateParameter.parseOrNull(query.filters().get(FILTER_SCHEDULED_FROM));
    return from == null ? UNBOUNDED_PERIOD_FROM : from.atStartOfDay();
  }

  /// 예정일 기간 끝(미포함): 끝 날 다음 날 0시, 비면 제한 없음
  public static LocalDateTime scheduledToExclusiveOf(AdminListQuery query) {
    LocalDate to = AdminDateParameter.parseOrNull(query.filters().get(FILTER_SCHEDULED_TO));
    return to == null ? UNBOUNDED_PERIOD_TO : to.plusDays(1).atStartOfDay();
  }

  /// 보호자 필터 원문 (회원 ID 정확히 일치 비교용, 없으면 null)
  public static String guardianOf(AdminListQuery query) {
    return query.filters().get(FILTER_GUARDIAN);
  }

  /// 일과 상태 > 표시 이름
  public static String statusLabel(RoutineStatus status) {
    return switch (status) {
      case PENDING_REVIEW -> "검토 대기";
      case CONFIRMED -> "확정";
      case COMPLETED -> "완료";
    };
  }

  /// 응답 > 표 한 행 (제목은 일과 상세, 보호자는 회원 상세 링크, 계정을 못 찾으면 링크 없음)
  public static AdminListRow toRow(AdminRoutineResponse routine, AdminDateFormatter dateFormatter) {
    Map<String, String> cells = new LinkedHashMap<>();
    cells.put(SORT_TITLE, routine.title());
    cells.put(COLUMN_MEMBER, routine.memberUsername() != null ? routine.memberUsername() : BLANK_TEXT);
    cells.put(COLUMN_PROFILE, routine.memberNickname() != null ? routine.memberNickname() : BLANK_TEXT);
    cells.put(SORT_STATUS, statusLabel(routine.status()));
    cells.put(COLUMN_LANGUAGE, routine.language());
    cells.put(SORT_SCHEDULED_AT, dateFormatter.format(routine.scheduledAt()));
    cells.put(SORT_COMPLETED_AT, dateFormatter.format(routine.completedAt()));
    cells.put(SORT_UPDATED_AT, dateFormatter.format(routine.updatedAt()));
    Map<String, String> cellLinks = routine.memberUsername() != null
      ? Map.of(COLUMN_MEMBER, "/admin/members/" + routine.memberId())
      : Map.of();
    return new AdminListRow("/admin/routines/" + routine.id(), cells, cellLinks);
  }
}
