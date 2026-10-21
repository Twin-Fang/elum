package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.notice.application.service.NoticeAdminSearch;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.core.NoticeStatus;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 공지 목록 선언: 열, 검색 대상, 필터 4개(상태, 대상 플랫폼, 게시 기간), 정렬 허용 열, 조건 > 검색 조건·Pageable 변환
 * 정렬은 isSortable 열만 허용되고 그 밖은 기본 정렬(최근 수정순)로 돌아감
 */
public final class AdminNoticeList {

  /// 필터 키: 게시 상태(예약·게시 중·끝남·꺼짐, 서버 시계 기준), 대상 플랫폼
  public static final String FILTER_STATUS = "status";
  public static final String FILTER_PLATFORM = "platform";
  /// 필터 키: 게시 기간과 겹치는 날짜 범위 (yyyy-MM-dd, 한국 시각, 비우면 제한 없음)
  public static final String FILTER_FROM = "from";
  public static final String FILTER_TO = "to";

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
    List.of(
      new Filter(FILTER_STATUS, "상태", Arrays.stream(NoticeStatus.values())
        .map(status -> new Option(status.name(), status.getLabel())).toList()),
      new Filter(FILTER_PLATFORM, "대상", Arrays.stream(NoticePlatform.values())
        .map(platform -> new Option(platform.name(), platform.getLabel())).toList()),
      Filter.date(FILTER_FROM, "게시 기간 시작"),
      Filter.date(FILTER_TO, "게시 기간 끝")),
    SORT_UPDATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminNoticeList() {
  }

  /// 조건 > 공지 검색 조건 (기간 끝은 끝 날 다음 날 0시, 정의로 보정된 값만 들어옴)
  public static NoticeAdminSearch searchOf(AdminListQuery query) {
    String status = query.filters().get(FILTER_STATUS);
    String platform = query.filters().get(FILTER_PLATFORM);
    LocalDate from = AdminDateParameter.parseOrNull(query.filters().get(FILTER_FROM));
    LocalDate to = AdminDateParameter.parseOrNull(query.filters().get(FILTER_TO));
    return new NoticeAdminSearch(
      query.likePattern(),
      status == null ? null : NoticeStatus.valueOf(status),
      platform == null ? null : NoticePlatform.valueOf(platform),
      from == null ? null : from.atStartOfDay(),
      to == null ? null : to.plusDays(1).atStartOfDay());
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
