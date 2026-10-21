package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import java.util.List;
import org.springframework.data.domain.Sort;

/**
 * 이야기 신고 목록 선언: 열, 처리 상태 필터(resolved=false 미처리, true 처리 완료), 정렬 > Sort 변환
 * 정렬은 isSortable 열만 허용되고 그 밖은 기본 정렬(접수 최신순)로 돌아감
 */
public final class AdminTalkReportList {

  /// 필터 키: 처리 여부 (값 false 미처리, true 처리 완료)
  public static final String FILTER_RESOLVED = "resolved";
  public static final String RESOLVED_FALSE = "false";
  public static final String RESOLVED_TRUE = "true";
  /// 정렬 키 (열 키와 같음)
  public static final String SORT_CREATED_AT = "createdAt";
  public static final String SORT_RESOLVED_AT = "resolvedAt";

  public static final String COLUMN_TARGET = "target";
  public static final String COLUMN_REASON = "reason";
  public static final String COLUMN_REPORTER = "reporter";
  public static final String COLUMN_POST = "post";
  public static final String COLUMN_ACTIONS = "actions";

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_CREATED_AT, "접수 때", true),
      new Column(COLUMN_TARGET, "대상", false),
      new Column(COLUMN_REASON, "사유", false),
      new Column(COLUMN_REPORTER, "신고자", false),
      new Column(COLUMN_POST, "글", false),
      new Column(SORT_RESOLVED_AT, "처리", true),
      new Column(COLUMN_ACTIONS, "", false)),
    List.of(),
    List.of(new Filter(FILTER_RESOLVED, "처리", List.of(
      new Option(RESOLVED_FALSE, "미처리"), new Option(RESOLVED_TRUE, "처리 완료")))),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminTalkReportList() {
  }

  /// 조건 > 정렬: 정렬 열 키 > 엔티티 속성, 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  public static Sort sortOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    Sort.Order mainOrder = switch (query.sortKey()) {
      // 아직 처리하지 않은(null) 신고는 방향과 상관없이 뒤로
      case SORT_RESOLVED_AT -> new Sort.Order(direction, "resolvedAt").with(Sort.NullHandling.NULLS_LAST);
      default -> new Sort.Order(direction, "createdAt");
    };
    return Sort.by(mainOrder, new Sort.Order(Sort.Direction.ASC, "id"));
  }

  /// 필터 값 > 처리 여부 (필터 없음은 null = 전체: 정의로 이미 보정된 값만 들어옴)
  public static Boolean resolvedFilterOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_RESOLVED);
    if (RESOLVED_TRUE.equals(value)) {
      return Boolean.TRUE;
    }
    return RESOLVED_FALSE.equals(value) ? Boolean.FALSE : null;
  }
}
