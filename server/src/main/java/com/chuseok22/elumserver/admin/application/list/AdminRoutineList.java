package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 일과 목록 선언: 열, 상태 필터, 정렬 허용 열, 응답 > 표 행 변환
 * 정렬은 isSortable 열만 허용되고 그 밖은 기본 정렬(최근 변경순)로 돌아감
 */
public final class AdminRoutineList {

  /// 필터 키: 일과 상태
  public static final String FILTER_STATUS = "status";
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
    List.of(new Filter(FILTER_STATUS, "상태", List.of(
      new Option(RoutineStatus.PENDING_REVIEW.name(), statusLabel(RoutineStatus.PENDING_REVIEW)),
      new Option(RoutineStatus.CONFIRMED.name(), statusLabel(RoutineStatus.CONFIRMED)),
      new Option(RoutineStatus.COMPLETED.name(), statusLabel(RoutineStatus.COMPLETED))))),
    SORT_UPDATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminRoutineList() {
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
