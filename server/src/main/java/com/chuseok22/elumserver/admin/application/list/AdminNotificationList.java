package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.notification.core.NotificationType;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 알림 기록 목록 선언: 검색(회원 아이디·호칭), 필터 5개(회원, 종류, 읽음, 시작일, 종료일), 정렬, 종류 표시 이름
 * 기간은 마지막 발생 시각 기준 (AdminListPeriod)
 */
public final class AdminNotificationList {

  /// 필터 키
  public static final String FILTER_MEMBER_ID = "memberId";
  public static final String FILTER_TYPE = "type";
  public static final String FILTER_READ = "read";

  /// 읽음 필터 값: 읽음 true, 안 읽음 false
  public static final String READ_TRUE = "true";
  public static final String READ_FALSE = "false";

  /// 정렬 키 (열 키와 같음): 마지막 발생만 정렬 허용
  public static final String SORT_LAST_OCCURRED_AT = "lastOccurredAt";

  public static final String COLUMN_MEMBER = "member";
  public static final String COLUMN_TYPE = "type";
  public static final String COLUMN_COUNT = "count";
  public static final String COLUMN_TARGET = "target";
  public static final String COLUMN_READ = "read";

  /// 종류 선택지 (필터 칩·선택 상자 공통)
  public static final List<Option> TYPE_OPTIONS = Arrays.stream(NotificationType.values())
    .map(type -> new Option(type.name(), typeLabelOf(type))).toList();

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_LAST_OCCURRED_AT, "마지막 발생", true),
      new Column(COLUMN_MEMBER, "받는 보호자", false),
      new Column(COLUMN_TYPE, "종류", false),
      new Column(COLUMN_COUNT, "모인 횟수", false),
      new Column(COLUMN_TARGET, "대상", false),
      new Column(COLUMN_READ, "읽음", false)),
    List.of("username", "nickname"),
    List.of(
      new Filter(FILTER_MEMBER_ID, "회원", List.of()),
      new Filter(FILTER_TYPE, "종류", TYPE_OPTIONS),
      new Filter(FILTER_READ, "읽음", List.of(new Option(READ_TRUE, "읽음"), new Option(READ_FALSE, "안 읽음"))),
      new Filter(AdminListPeriod.FILTER_FROM, "시작일", List.of()),
      new Filter(AdminListPeriod.FILTER_TO, "종료일", List.of())),
    SORT_LAST_OCCURRED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminNotificationList() {
  }

  /// 알림 종류 > 표시 이름 (앱 알림 설정 화면과 같은 말)
  public static String typeLabelOf(NotificationType type) {
    return switch (type) {
      case ROUTINE_COMPLETED -> "일과 완료";
      case ROUTINE_SENT_BY_CO_GUARDIAN -> "공동 보호자가 보낸 일과";
      case CO_GUARDIAN_JOINED -> "공동 보호자 합류";
      case CREDIT_REFILLED -> "크레딧 충전";
      case FEEDBACK_RESOLVED -> "의견 답변";
      case TALK_POST_COMMENTED -> "이야기 댓글";
      case TALK_POST_IMPORTED -> "이야기 가져감";
    };
  }

  public static String memberIdOf(AdminListQuery query) {
    return query.filters().get(FILTER_MEMBER_ID);
  }

  /// 필터 값 > 종류 (정의로 이미 보정된 값만 들어옴, 없으면 null)
  public static NotificationType typeOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_TYPE);
    return value == null ? null : NotificationType.valueOf(value);
  }

  /// 읽음 필터: 읽음 true, 안 읽음 false, 전체 null
  public static Boolean isReadOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_READ);
    return value == null ? null : Boolean.valueOf(value);
  }

  /// 정렬 > 페이지 요청: 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  public static Pageable pageableOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    return PageRequest.of(query.pageIndex(), AdminListDefaults.LOG_PAGE_SIZE,
      Sort.by(new Sort.Order(direction, "lastOccurredAt"), new Sort.Order(Sort.Direction.ASC, "id")));
  }
}
