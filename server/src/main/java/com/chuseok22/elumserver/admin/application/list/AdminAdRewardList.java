package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 광고 보상 세션 목록 선언: 검색(회원 아이디·호칭), 필터 5개(회원, 상태, 거절 사유, 시작일, 종료일), 정렬, 표시 이름
 * 상태는 보이는 상태 기준 (콜백 없이 지난 대기는 만료). 기간은 세션을 만든 때 기준 (AdminListPeriod)
 */
public final class AdminAdRewardList {

  /// 필터 키
  public static final String FILTER_MEMBER_ID = "memberId";
  public static final String FILTER_STATUS = "status";
  public static final String FILTER_REASON = "reason";

  /// 정렬 키 (열 키와 같음): 만든 때만 정렬 허용
  public static final String SORT_CREATED_AT = "createdAt";

  public static final String COLUMN_MEMBER = "member";
  public static final String COLUMN_STATUS = "status";
  public static final String COLUMN_CALLBACK = "callback";
  public static final String COLUMN_CREDITS = "credits";
  public static final String COLUMN_REASON = "reason";
  public static final String COLUMN_ACTIONS = "actions";

  /// 콜백 없이 유효 시간이 지난 세션의 사유 표시
  public static final String NO_CALLBACK_LABEL = "콜백이 오지 않음";

  /// 상태·거절 사유 선택지 (선택 상자 공통)
  public static final List<Option> STATUS_OPTIONS = Arrays.stream(AdRewardStatus.values())
    .map(status -> new Option(status.name(), statusLabelOf(status))).toList();
  public static final List<Option> REASON_OPTIONS = Arrays.stream(AdRewardRejectReason.values())
    .map(reason -> new Option(reason.name(), reasonLabelOf(reason))).toList();

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_CREATED_AT, "만든 때", true),
      new Column(COLUMN_MEMBER, "회원", false),
      new Column(COLUMN_STATUS, "상태", false),
      new Column(COLUMN_CALLBACK, "콜백 받은 때", false),
      new Column(COLUMN_CREDITS, "지급", false),
      new Column(COLUMN_REASON, "사유", false),
      new Column(COLUMN_ACTIONS, "", false)),
    List.of("username", "nickname"),
    List.of(
      new Filter(FILTER_MEMBER_ID, "회원", List.of()),
      new Filter(FILTER_STATUS, "상태", STATUS_OPTIONS),
      new Filter(FILTER_REASON, "거절 사유", REASON_OPTIONS),
      new Filter(AdminListPeriod.FILTER_FROM, "시작일", List.of()),
      new Filter(AdminListPeriod.FILTER_TO, "종료일", List.of())),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminAdRewardList() {
  }

  /// 상태 > 표시 이름 (지급, 거절, 대기, 만료)
  public static String statusLabelOf(AdRewardStatus status) {
    return switch (status) {
      case GRANTED -> "지급";
      case REJECTED -> "거절";
      case PENDING -> "대기";
      case EXPIRED -> "만료";
    };
  }

  /// 상태 > 배지 색 (지급 초록, 거절 빨강, 대기 파랑, 만료 노랑)
  public static String statusBadgeClassOf(AdRewardStatus status) {
    return switch (status) {
      case GRANTED -> "badge-success";
      case REJECTED -> "badge-error";
      case PENDING -> "badge-info";
      case EXPIRED -> "badge-warning";
    };
  }

  /// 거절 사유 > 표시 이름
  public static String reasonLabelOf(AdRewardRejectReason reason) {
    return switch (reason) {
      case DISABLED -> "기능 꺼짐";
      case AD_UNIT -> "허용하지 않은 광고 단위";
      case NOT_PENDING -> "이미 끝난 세션";
      case EXPIRED -> "유효 시간 지나 콜백 도착";
      case FROZEN -> "계정 멈춤";
      case DAILY_LIMIT -> "오늘 횟수 다 씀";
    };
  }

  public static String memberIdOf(AdminListQuery query) {
    return query.filters().get(FILTER_MEMBER_ID);
  }

  /// 필터 값 > 상태 (정의로 이미 보정된 값만 들어옴, 없으면 null)
  public static AdRewardStatus statusOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_STATUS);
    return value == null ? null : AdRewardStatus.valueOf(value);
  }

  public static AdRewardRejectReason reasonOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_REASON);
    return value == null ? null : AdRewardRejectReason.valueOf(value);
  }

  /// 정렬 > 페이지 요청: 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  public static Pageable pageableOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    return PageRequest.of(query.pageIndex(), AdminListDefaults.LOG_PAGE_SIZE,
      Sort.by(new Sort.Order(direction, "createdAt"), new Sort.Order(Sort.Direction.ASC, "id")));
  }
}
