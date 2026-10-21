package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 회원 목록 선언: 열, 요금제·상태·가입일 기간 필터, 정렬 허용 열, 응답 > 표 행 변환
 * 정렬은 isSortable 열만 허용되고 그 밖은 기본 정렬(가입일 최신순)로 돌아감
 */
public final class AdminMemberList {

  /// 필터 키: plan 은 지금 유효한 요금제, status 는 계정 상태
  public static final String FILTER_PLAN = "plan";
  public static final String FILTER_STATUS = "status";
  /// 필터 키: 가입일 기간 (yyyy-MM-dd, 비우면 제한 없음 — 가입 추이 막대에서 넘어옴)
  public static final String FILTER_JOINED_FROM = "joinedFrom";
  public static final String FILTER_JOINED_TO = "joinedTo";
  /// 가입일 필터가 없을 때 쿼리에 넣는 끝값 (null 바인딩 대신)
  private static final LocalDateTime UNBOUNDED_JOINED_FROM = LocalDateTime.of(2000, 1, 1, 0, 0);
  private static final LocalDateTime UNBOUNDED_JOINED_TO = LocalDateTime.of(9999, 1, 1, 0, 0);
  /// 정렬 키 (열 키와 같음)
  public static final String SORT_USERNAME = "username";
  public static final String SORT_PLAN = "plan";
  public static final String SORT_LAST_ACTIVITY = "lastActivityAt";
  public static final String SORT_CREATED_AT = "createdAt";

  private static final String COLUMN_PLAN_LAST_CHANGED = "planLastChanged";
  private static final String NO_HISTORY_TEXT = "변경 이력 없음";
  private static final String BLANK_TEXT = "-";

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_USERNAME, "닉네임 / 아이디", true),
      new Column(SORT_PLAN, "요금제", true),
      new Column("status", "상태", false),
      new Column("supportGoals", "도움 방식", false),
      new Column("totalStars", "별", false),
      new Column("routineCount", "루틴", false),
      new Column("aiCallCount", "AI 호출", false),
      new Column("totalTokens", "토큰", false),
      new Column("estimatedCostUsd", "추정 비용", false),
      new Column(SORT_LAST_ACTIVITY, "최근 활동", true),
      new Column(SORT_CREATED_AT, "가입일", true),
      new Column(COLUMN_PLAN_LAST_CHANGED, "요금제 마지막 변경", false)),
    List.of("username", "nickname"),
    List.of(
      new Filter(FILTER_PLAN, "요금제", List.of(
        new Option(PlanType.FREE.name(), PlanType.FREE.getLabel()),
        new Option(PlanType.PRO.name(), PlanType.PRO.getLabel()))),
      new Filter(FILTER_STATUS, "상태", List.of(
        new Option(MemberStatus.ACTIVE.name(), MemberStatus.ACTIVE.getLabel()),
        new Option(MemberStatus.SUSPENDED.name(), MemberStatus.SUSPENDED.getLabel()),
        // 탈퇴 계정은 상태 필터가 없으면 빠진다. 보관 중인 탈퇴 계정은 이 필터로만 본다 (#372)
        new Option(MemberStatus.WITHDRAWN.name(), MemberStatus.WITHDRAWN.getLabel()))),
      new Filter(FILTER_JOINED_FROM, "가입일 시작", List.of()),
      new Filter(FILTER_JOINED_TO, "가입일 끝", List.of())),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminMemberList() {
  }

  /// 가입일 기간 시작(포함): 형식이 틀리거나 비면 제한 없음
  public static LocalDateTime joinedFromOf(AdminListQuery query) {
    LocalDate from = AdminDateParameter.parseOrNull(query.filters().get(FILTER_JOINED_FROM));
    return from == null ? UNBOUNDED_JOINED_FROM : from.atStartOfDay();
  }

  /// 가입일 기간 끝(미포함): 끝 날 다음 날 0시, 형식이 틀리거나 비면 제한 없음
  public static LocalDateTime joinedToExclusiveOf(AdminListQuery query) {
    LocalDate to = AdminDateParameter.parseOrNull(query.filters().get(FILTER_JOINED_TO));
    return to == null ? UNBOUNDED_JOINED_TO : to.plusDays(1).atStartOfDay();
  }

  /// 응답 > 표 한 행 (첫 칸이 회원 상세 링크)
  public static AdminListRow toRow(AdminMemberResponse member, AdminDateFormatter dateFormatter) {
    Map<String, String> cells = new LinkedHashMap<>();
    String displayName = member.nickname() != null ? member.nickname() : member.username();
    cells.put(SORT_USERNAME, displayName + " (" + member.username() + ")");
    cells.put(SORT_PLAN, planText(member, dateFormatter));
    cells.put("status", statusText(member, dateFormatter));
    cells.put("supportGoals", member.supportGoals().stream().map(SupportGoal::getLabel).collect(Collectors.joining(", ")));
    cells.put("totalStars", String.valueOf(member.totalStars()));
    cells.put("routineCount", String.valueOf(member.routineCount()));
    cells.put("aiCallCount", String.valueOf(member.aiCallCount()));
    cells.put("totalTokens", String.format("%,d", member.totalTokens()));
    cells.put("estimatedCostUsd", String.format("$%.4f", member.estimatedCostUsd()));
    cells.put(SORT_LAST_ACTIVITY, dateFormatter.format(member.lastActivityAt()));
    cells.put(SORT_CREATED_AT, dateFormatter.format(member.createdAt()));
    cells.put(COLUMN_PLAN_LAST_CHANGED, lastChangedText(member, dateFormatter));
    return new AdminListRow("/admin/members/" + member.id(), cells);
  }

  private static String planText(AdminMemberResponse member, AdminDateFormatter dateFormatter) {
    if (member.plan() == PlanType.PRO && member.planExpiresAt() != null) {
      return member.plan().getLabel() + " (~" + dateFormatter.format(member.planExpiresAt()) + ")";
    }
    return member.plan().getLabel();
  }

  private static String statusText(AdminMemberResponse member, AdminDateFormatter dateFormatter) {
    String label = member.status().getLabel();
    // 이 날이 지나면 스케줄러가 완전히 지운다
    return member.retentionExpiresAt() == null
      ? label
      : label + " (만료 " + dateFormatter.format(member.retentionExpiresAt()) + ")";
  }

  private static String lastChangedText(AdminMemberResponse member, AdminDateFormatter dateFormatter) {
    if (member.planLastChangedAt() == null) {
      return NO_HISTORY_TEXT;
    }
    String changedBy = member.planLastChangedBy() == null ? BLANK_TEXT : member.planLastChangedBy();
    return dateFormatter.format(member.planLastChangedAt()) + " · " + changedBy;
  }
}
