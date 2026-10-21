package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.CsvColumn;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 회원 목록 선언: 열, 검색(회원 id 조각·아이디·보호자 닉네임·이룸이 호칭), 필터 7개(요금제, 상태, 로그인 제공자, 가입일·최근 활동 기간), 정렬 허용 열, 응답 > 표 행·CSV 변환
 * 정렬은 isSortable 열만 허용되고 그 밖은 기본 정렬(가입일 최신순)로 돌아감
 */
public final class AdminMemberList {

  /// 필터 키: plan 은 지금 유효한 요금제, status 는 계정 상태
  public static final String FILTER_PLAN = "plan";
  public static final String FILTER_STATUS = "status";
  /// 필터 키: 가입일 기간 (yyyy-MM-dd, 비우면 제한 없음 — 가입 추이 막대에서 넘어옴)
  public static final String FILTER_JOINED_FROM = "joinedFrom";
  public static final String FILTER_JOINED_TO = "joinedTo";
  /// 필터 키: 최근 활동 기간 (yyyy-MM-dd, 걸면 활동 기록 없는 회원은 빠짐)
  public static final String FILTER_LAST_ACTIVE_FROM = "activeFrom";
  public static final String FILTER_LAST_ACTIVE_TO = "activeTo";
  /// 필터 키: 로그인 제공자 (그 제공자 신원이 연결된 회원, 여러 제공자를 붙인 회원은 각각에 나옴)
  public static final String FILTER_PROVIDER = "provider";
  /// 기간 필터가 없을 때 쿼리에 넣는 끝값 (null 바인딩 대신)
  private static final LocalDateTime UNBOUNDED_PERIOD_FROM = LocalDateTime.of(2000, 1, 1, 0, 0);
  private static final LocalDateTime UNBOUNDED_PERIOD_TO = LocalDateTime.of(9999, 1, 1, 0, 0);
  /// 정렬 키 (열 키와 같음)
  public static final String SORT_USERNAME = "username";
  public static final String SORT_PLAN = "plan";
  public static final String SORT_LAST_ACTIVITY = "lastActivityAt";
  public static final String SORT_CREATED_AT = "createdAt";

  private static final String COLUMN_PLAN_LAST_CHANGED = "planLastChanged";
  private static final String COLUMN_LOGIN_PROVIDERS = "loginProviders";
  private static final String COLUMN_PROFILE_COUNT = "profileCount";
  private static final String COLUMN_GUARDIAN_COUNT = "guardianCount";
  /// 크레딧 열: 이번 주 지금 사용 가능량, 칸 링크는 회원 크레딧 상세
  private static final String COLUMN_CURRENT_WEEK_CREDIT = "currentWeekCredit";
  private static final String CREDIT_DETAIL_PATH = "/admin/credits/members/";
  private static final String PROVIDER_DELIMITER = ", ";
  private static final String NO_HISTORY_TEXT = "변경 이력 없음";
  private static final String BLANK_TEXT = "-";

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_USERNAME, "닉네임 / 아이디", true),
      new Column(SORT_PLAN, "요금제", true),
      new Column("status", "상태", false),
      new Column(COLUMN_LOGIN_PROVIDERS, "로그인", false),
      Column.numeric(COLUMN_PROFILE_COUNT, "이룸이", false),
      Column.numeric(COLUMN_GUARDIAN_COUNT, "보호자(본인 포함)", false),
      new Column("supportGoals", "도움 방식", false),
      Column.numeric("totalStars", "별", false),
      Column.numeric("routineCount", "루틴", false),
      Column.numeric("aiCallCount", "AI 호출", false),
      Column.numeric("totalTokens", "토큰", false),
      Column.numeric("estimatedCostUsd", "추정 비용", false),
      Column.numeric(COLUMN_CURRENT_WEEK_CREDIT, "크레딧(이번 주 남음)", false),
      new Column(SORT_LAST_ACTIVITY, "최근 활동", true),
      new Column(SORT_CREATED_AT, "가입일", true),
      new Column(COLUMN_PLAN_LAST_CHANGED, "요금제 마지막 변경", false)),
    List.of("id", "username", "nickname", "profileNickname"),
    List.of(
      new Filter(FILTER_PLAN, "요금제", List.of(
        new Option(PlanType.FREE.name(), PlanType.FREE.getLabel()),
        new Option(PlanType.PRO.name(), PlanType.PRO.getLabel()))),
      new Filter(FILTER_STATUS, "상태", List.of(
        new Option(MemberStatus.ACTIVE.name(), MemberStatus.ACTIVE.getLabel()),
        new Option(MemberStatus.SUSPENDED.name(), MemberStatus.SUSPENDED.getLabel()),
        // 탈퇴 계정은 상태 필터가 없으면 빠진다. 보관 중인 탈퇴 계정은 이 필터로만 본다 (#372)
        new Option(MemberStatus.WITHDRAWN.name(), MemberStatus.WITHDRAWN.getLabel()))),
      new Filter(FILTER_PROVIDER, "로그인", Arrays.stream(OAuthProvider.values())
        .map(provider -> new Option(provider.name(), providerLabel(provider))).toList()),
      Filter.date(FILTER_JOINED_FROM, "가입일 시작"),
      Filter.date(FILTER_JOINED_TO, "가입일 끝"),
      Filter.date(FILTER_LAST_ACTIVE_FROM, "최근 활동 시작"),
      Filter.date(FILTER_LAST_ACTIVE_TO, "최근 활동 끝")),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminMemberList() {
  }

  /// 가입일 기간 시작(포함): 형식이 틀리거나 비면 제한 없음
  public static LocalDateTime joinedFromOf(AdminListQuery query) {
    LocalDate from = AdminDateParameter.parseOrNull(query.filters().get(FILTER_JOINED_FROM));
    return from == null ? UNBOUNDED_PERIOD_FROM : from.atStartOfDay();
  }

  /// 가입일 기간 끝(미포함): 끝 날 다음 날 0시, 형식이 틀리거나 비면 제한 없음
  public static LocalDateTime joinedToExclusiveOf(AdminListQuery query) {
    LocalDate to = AdminDateParameter.parseOrNull(query.filters().get(FILTER_JOINED_TO));
    return to == null ? UNBOUNDED_PERIOD_TO : to.plusDays(1).atStartOfDay();
  }

  /// 최근 활동 기간 필터가 하나라도 걸렸는가 (안 걸리면 활동 기록 없는 회원도 보여야 해서 조건을 통째로 뺌)
  public static boolean hasLastActivePeriod(AdminListQuery query) {
    return query.filters().containsKey(FILTER_LAST_ACTIVE_FROM) || query.filters().containsKey(FILTER_LAST_ACTIVE_TO);
  }

  /// 최근 활동 기간 시작(포함): 비면 제한 없음
  public static LocalDateTime lastActiveFromOf(AdminListQuery query) {
    LocalDate from = AdminDateParameter.parseOrNull(query.filters().get(FILTER_LAST_ACTIVE_FROM));
    return from == null ? UNBOUNDED_PERIOD_FROM : from.atStartOfDay();
  }

  /// 최근 활동 기간 끝(미포함): 끝 날 다음 날 0시, 비면 제한 없음
  public static LocalDateTime lastActiveToExclusiveOf(AdminListQuery query) {
    LocalDate to = AdminDateParameter.parseOrNull(query.filters().get(FILTER_LAST_ACTIVE_TO));
    return to == null ? UNBOUNDED_PERIOD_TO : to.plusDays(1).atStartOfDay();
  }

  /// 로그인 제공자 필터 (없으면 null: 정의로 보정된 값만 들어옴)
  public static OAuthProvider providerOf(AdminListQuery query) {
    String value = query.filters().get(FILTER_PROVIDER);
    return value == null ? null : OAuthProvider.valueOf(value);
  }

  /// 로그인 제공자 > 표시 이름
  public static String providerLabel(OAuthProvider provider) {
    return switch (provider) {
      case KAKAO -> "카카오";
      case NAVER -> "네이버";
      case GOOGLE -> "구글";
      case APPLE -> "애플";
    };
  }

  /// 응답 > 표 한 행 (크레딧 모름: 크레딧 칸 "-")
  public static AdminListRow toRow(AdminMemberResponse member, AdminDateFormatter dateFormatter) {
    return toRow(member, null, dateFormatter);
  }

  /**
   * 응답 > 표 한 행 (첫 칸 회원 상세 링크, 크레딧 칸 회원 크레딧 상세 링크)
   *
   * @param currentWeekRemainingCredit 이번 주 남은 크레딧, 이번 주 기록 없음·조회 실패면 null ("-")
   */
  public static AdminListRow toRow(
    AdminMemberResponse member, Long currentWeekRemainingCredit, AdminDateFormatter dateFormatter
  ) {
    Map<String, String> cells = new LinkedHashMap<>();
    String displayName = member.nickname() != null ? member.nickname() : member.username();
    cells.put(SORT_USERNAME, displayName + " (" + member.username() + ")");
    cells.put(SORT_PLAN, planText(member, dateFormatter));
    cells.put("status", statusText(member, dateFormatter));
    cells.put(COLUMN_LOGIN_PROVIDERS, providersText(member));
    cells.put(COLUMN_PROFILE_COUNT, String.valueOf(member.profileCount()));
    cells.put(COLUMN_GUARDIAN_COUNT, String.valueOf(member.guardianCount()));
    cells.put("supportGoals", member.supportGoals().stream().map(SupportGoal::getLabel).collect(Collectors.joining(", ")));
    cells.put("totalStars", String.valueOf(member.totalStars()));
    cells.put("routineCount", String.valueOf(member.routineCount()));
    cells.put("aiCallCount", String.valueOf(member.aiCallCount()));
    cells.put("totalTokens", String.format("%,d", member.totalTokens()));
    cells.put("estimatedCostUsd", String.format("$%.4f", member.estimatedCostUsd()));
    cells.put(COLUMN_CURRENT_WEEK_CREDIT,
      currentWeekRemainingCredit == null ? BLANK_TEXT : String.format("%,d", currentWeekRemainingCredit));
    cells.put(SORT_LAST_ACTIVITY, dateFormatter.format(member.lastActivityAt()));
    cells.put(SORT_CREATED_AT, dateFormatter.format(member.createdAt()));
    cells.put(COLUMN_PLAN_LAST_CHANGED, lastChangedText(member, dateFormatter));
    return new AdminListRow("/admin/members/" + member.id(), cells,
      Map.of(COLUMN_CURRENT_WEEK_CREDIT, CREDIT_DETAIL_PATH + member.id()));
  }

  /**
   * CSV 열 14개 (개인정보 최소): 회원 ID, 상태, 요금제, Pro 만료, 로그인, 이룸이·보호자 수, 루틴·AI 사용량, 활동·가입·보관 만료
   * 아이디·이룸이 호칭·도움 방식은 넣지 않음 (회원 ID 로 상세를 찾을 수 있음, 도움 방식은 서비스 원칙 1번)
   */
  public static List<CsvColumn<AdminMemberResponse>> csvColumns(AdminDateFormatter dateFormatter) {
    return List.of(
      new CsvColumn<>("회원 ID", AdminMemberResponse::id),
      new CsvColumn<>("상태", member -> member.status().getLabel()),
      new CsvColumn<>("요금제", member -> member.plan().getLabel()),
      new CsvColumn<>("Pro 만료", member -> AdminCsvExporter.dateTimeCell(member.planExpiresAt(), dateFormatter)),
      new CsvColumn<>("로그인", AdminMemberList::providersText),
      new CsvColumn<>("이룸이 수", member -> String.valueOf(member.profileCount())),
      new CsvColumn<>("보호자 수(본인 포함)", member -> String.valueOf(member.guardianCount())),
      new CsvColumn<>("루틴 수", member -> String.valueOf(member.routineCount())),
      new CsvColumn<>("AI 호출", member -> String.valueOf(member.aiCallCount())),
      new CsvColumn<>("토큰", member -> String.valueOf(member.totalTokens())),
      new CsvColumn<>("추정 비용(USD)", member -> String.format("%.4f", member.estimatedCostUsd())),
      new CsvColumn<>("최근 활동", member -> AdminCsvExporter.dateTimeCell(member.lastActivityAt(), dateFormatter)),
      new CsvColumn<>("가입일", member -> AdminCsvExporter.dateTimeCell(member.createdAt(), dateFormatter)),
      new CsvColumn<>("보관 만료", member -> AdminCsvExporter.dateTimeCell(member.retentionExpiresAt(), dateFormatter)));
  }

  private static String providersText(AdminMemberResponse member) {
    if (member.loginProviders().isEmpty()) {
      return BLANK_TEXT;
    }
    return member.loginProviders().stream().map(AdminMemberList::providerLabel)
      .collect(Collectors.joining(PROVIDER_DELIMITER));
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
