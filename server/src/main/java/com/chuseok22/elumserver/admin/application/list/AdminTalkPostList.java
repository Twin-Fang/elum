package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.talk.application.service.TalkAdminService;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.Sort;

/**
 * 이야기 글 목록 선언: 열, 상태 필터, 정렬 허용 열, 정렬 > Sort 변환
 * 정렬은 isSortable 열만 허용되고 그 밖은 기본 정렬(최신순)로 돌아감
 */
public final class AdminTalkPostList {

  /// 필터 키: 글 상태
  public static final String FILTER_STATUS = "status";
  /// 정렬 키 (열 키와 같음)
  public static final String SORT_CREATED_AT = "createdAt";
  public static final String SORT_STATUS = "status";
  public static final String SORT_UNRESOLVED_REPORT_COUNT = TalkAdminService.SORT_UNRESOLVED_REPORT_COUNT;

  public static final String COLUMN_TITLE = "title";
  public static final String COLUMN_AUTHOR = "author";
  public static final String COLUMN_CATEGORY = "category";
  public static final String COLUMN_REACTIONS = "reactions";
  public static final String COLUMN_ACTIONS = "actions";

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_CREATED_AT, "올린 때", true),
      new Column(COLUMN_TITLE, "제목", false),
      new Column(COLUMN_AUTHOR, "글쓴이", false),
      new Column(COLUMN_CATEGORY, "분류", false),
      new Column(SORT_STATUS, "상태", true),
      new Column(SORT_UNRESOLVED_REPORT_COUNT, "미처리 신고", true),
      new Column(COLUMN_REACTIONS, "반응", false),
      new Column(COLUMN_ACTIONS, "", false)),
    List.of("title"),
    List.of(new Filter(FILTER_STATUS, "상태", Arrays.stream(TalkPostStatus.values())
      .map(status -> new Option(status.name(), status.getLabel())).toList())),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminTalkPostList() {
  }

  /// 조건 > 정렬: 정렬 열 키 > 엔티티 속성 (신고 수는 서비스가 쿼리로 정함), 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  public static Sort sortOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    Sort.Order mainOrder = switch (query.sortKey()) {
      case SORT_STATUS -> new Sort.Order(direction, "status");
      case SORT_UNRESOLVED_REPORT_COUNT -> new Sort.Order(direction, SORT_UNRESOLVED_REPORT_COUNT);
      default -> new Sort.Order(direction, "createdAt");
    };
    return Sort.by(mainOrder, new Sort.Order(Sort.Direction.ASC, "id"));
  }

  /// 필터 값 > 상태 (필터 없음/허용 밖은 null: 정의로 이미 보정된 값만 들어옴)
  public static TalkPostStatus statusFilterOf(AdminListQuery query) {
    String name = query.filters().get(FILTER_STATUS);
    return Arrays.stream(TalkPostStatus.values()).filter(status -> status.name().equals(name)).findFirst().orElse(null);
  }
}
