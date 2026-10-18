package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 공지 목록 선언: 열, 검색 대상, 정렬 허용 열, 정렬 > Pageable 변환
 * 정렬은 isSortable 열만 허용되고 그 밖은 기본 정렬(최근 수정순)로 돌아감
 */
public final class AdminNoticeList {

  /// 정렬 키 (열 키와 같음)
  public static final String SORT_TITLE = "title";
  public static final String SORT_STARTS_AT = "startsAt";
  public static final String SORT_PRIORITY = "priority";
  public static final String SORT_UPDATED_AT = "updatedAt";

  public static final String COLUMN_STATUS = "status";
  public static final String COLUMN_AUDIENCE = "audience";
  public static final String COLUMN_ACTIONS = "actions";

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(COLUMN_STATUS, "상태", false),
      new Column(SORT_TITLE, "제목", true),
      new Column(SORT_STARTS_AT, "기간 (한국 시각)", true),
      new Column(SORT_PRIORITY, "언어 · 대상 · 순서", true),
      new Column(SORT_UPDATED_AT, "마지막 수정", true),
      new Column(COLUMN_ACTIONS, "", false)),
    List.of("title", "body"),
    List.of(),
    SORT_UPDATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminNoticeList() {
  }

  /// 조건 > 페이지 요청: 정렬 열 키 > 엔티티 속성, 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  public static Pageable pageableOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    Sort.Order mainOrder = switch (query.sortKey()) {
      case SORT_TITLE -> new Sort.Order(direction, "title");
      case SORT_STARTS_AT -> new Sort.Order(direction, "startsAt");
      case SORT_PRIORITY -> new Sort.Order(direction, "priority");
      default -> new Sort.Order(direction, "updatedAt").with(Sort.NullHandling.NULLS_LAST);
    };
    return PageRequest.of(query.pageIndex(), AdminListDefaults.PAGE_SIZE,
      Sort.by(mainOrder, new Sort.Order(Sort.Direction.ASC, "id")));
  }
}
