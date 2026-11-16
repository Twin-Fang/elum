package com.chuseok22.elumserver.admin.infrastructure.repository;

import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.FunnelCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.HeadlineCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.LastActivityCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.PlatformMemberCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.RecentActivityRow;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.RecentSignupRow;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.RetentionCohortCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.SuggestionCandidate;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.WeeklyCount;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.member.core.MemberAccountKind;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * 사용 분석 집계 SQL 한곳 (#1436, Postgres native): 가입 단계, 가입 주차 리텐션, 주별 추이, 마지막 활동 분포, 플랫폼,
 * 대시보드 요약·최근 가입·최근 활동, 분류 제안 후보. 외부 BI(Metabase 등)로 옮길 때 이 SQL 을 그대로 가져감
 * 계정 종류 조건은 COUNTED_MEMBER 한 줄 (:isIncludingAllAccounts 가 true 면 전체). 일과 원문·제목은 읽지 않음
 */
@Repository
@RequiredArgsConstructor
public class AdminUsageAnalyticsQueries {

  /// 숫자에 세는 회원 (member 별칭 m): 일반 계정만, "모두 포함" 이면 전체
  private static final String COUNTED_MEMBER = "(:isIncludingAllAccounts or " + MemberAccountKind.COUNTED_MEMBER_SQL + ")";
  /// 카드 체크를 세는 일과 (routine 별칭 r): 그 이룸이 보호자 중 세는 회원이 있을 때
  private static final String COUNTED_CARD_ROUTINE = "exists (select 1 from profile_guardian g"
    + " join member m on m.id = g.member_id where g.profile_id = r.profile_id and " + COUNTED_MEMBER + ")";
  /// 스토어 결제로 보는 구독 출처 2개
  private static final List<String> STORE_SOURCES = List.of(
    SubscriptionSource.APPLE_IAP.name(), SubscriptionSource.GOOGLE_IAP.name());

  private static final String FUNNEL_SQL = """
    select
      count(*) as signed_up_count,
      count(*) filter (where exists (
        select 1 from routine r where r.created_by = m.id and r.is_example = false)) as routine_made_count,
      count(*) filter (where exists (
        select 1 from profile_guardian g
        join routine r on r.profile_id = g.profile_id
        join routine_step s on s.routine_id = r.id
        where g.member_id = m.id and s.completed_at is not null)) as card_checked_count,
      count(*) filter (where exists (
        select 1 from device_link d where d.member_id = m.id and d.redeemed_at is not null)) as device_linked_count,
      count(*) filter (where exists (
          select 1 from subscription sub where sub.member_id = m.id and sub.source in (:storeSources))
        or exists (select 1 from ai_credit_purchase p where p.member_id = m.id)) as store_paid_count
    from member m
    where m.created_at >= :from and m.created_at < :to and\s""" + COUNTED_MEMBER;

  private static final String RETENTION_SQL = "select cast(date_trunc('week', m.created_at) as date) as cohort_week_start,"
    + " count(*) as cohort_size, "
    + returnedInWeekCount(1, "week1_returned_count") + ", "
    + returnedInWeekCount(2, "week2_returned_count") + ", "
    + returnedInWeekCount(4, "week4_returned_count")
    + " from member m where m.created_at >= :from and m.created_at < :to and " + COUNTED_MEMBER
    + " group by 1 order by 1 desc";

  // 줄 key 4개: SIGNUPS 신규 가입, WEEKLY_ACTIVE 주간 활성, ROUTINES_MADE 일과 만듦(예시 제외), CARD_CHECKS 카드 체크
  private static final String WEEKLY_USAGE_SQL = """
    select 'SIGNUPS' as series_key, cast(date_trunc('week', m.created_at) as date) as week_start, count(*) as total
    from member m
    where m.created_at >= :from and m.created_at < :to and\s""" + COUNTED_MEMBER + """
     group by 2
    union all
    select 'WEEKLY_ACTIVE', cast(date_trunc('week', v.visit_date) as date), count(distinct v.member_id)
    from member_daily_visit v join member m on m.id = v.member_id
    where v.visit_date >= :fromDate and v.visit_date < :toDate and\s""" + COUNTED_MEMBER + """
     group by 2
    union all
    select 'ROUTINES_MADE', cast(date_trunc('week', r.created_at) as date), count(*)
    from routine r join member m on m.id = r.created_by
    where r.is_example = false and r.created_at >= :from and r.created_at < :to and\s""" + COUNTED_MEMBER + """
     group by 2
    union all
    select 'CARD_CHECKS', cast(date_trunc('week', s.completed_at) as date), count(*)
    from routine_step s join routine r on r.id = s.routine_id
    where s.completed_at >= :from and s.completed_at < :to and\s""" + COUNTED_CARD_ROUTINE + """
     group by 2
    """;

  private static final String LAST_ACTIVITY_SQL = """
    select
      count(*) filter (where m.last_activity_at >= :oneDayAgo) as within_one_day_count,
      count(*) filter (where m.last_activity_at >= :sevenDaysAgo and m.last_activity_at < :oneDayAgo) as within_seven_days_count,
      count(*) filter (where m.last_activity_at >= :thirtyDaysAgo and m.last_activity_at < :sevenDaysAgo) as within_thirty_days_count,
      count(*) filter (where m.last_activity_at < :thirtyDaysAgo) as older_count,
      count(*) filter (where m.last_activity_at is null) as never_count
    from member m
    where m.status <> 'WITHDRAWN' and\s""" + COUNTED_MEMBER;

  private static final String PLATFORM_SQL = """
    select
      count(distinct d.member_id) filter (where d.platform = 'IOS') as ios_member_count,
      count(distinct d.member_id) filter (where d.platform = 'ANDROID') as android_member_count
    from push_device d join member m on m.id = d.member_id
    where m.status <> 'WITHDRAWN' and\s""" + COUNTED_MEMBER;

  // 7일 리텐션: 가입 다음 날 ~ 7일째 사이 방문
  private static final String HEADLINE_SQL = "select"
    + " (select count(distinct v.member_id) from member_daily_visit v join member m on m.id = v.member_id"
    + "   where v.visit_date >= :weekStartDate and " + COUNTED_MEMBER + ") as weekly_active_count,"
    + " (select count(*) from member m where m.created_at >= :cohortFrom and m.created_at < :cohortTo and "
    + COUNTED_MEMBER + ") as retention_cohort_size,"
    + " (select count(*) from member m where m.created_at >= :cohortFrom and m.created_at < :cohortTo and "
    + COUNTED_MEMBER + " and exists (select 1 from member_daily_visit v where v.member_id = m.id"
    + "   and v.visit_date > cast(m.created_at as date) and v.visit_date <= cast(m.created_at as date) + 7))"
    + " as retained_count,"
    + " (select count(*) from routine_step s join routine r on r.id = s.routine_id"
    + "   where s.completed_at >= :weekStart and " + COUNTED_CARD_ROUTINE + ") as card_check_count";

  private static final String RECENT_SIGNUPS_SQL = """
    select m.id, m.nickname, m.created_at, m.last_activity_at, m.account_kind,
      (select string_agg(a.provider, ',' order by a.provider) from auth_identity a where a.member_id = m.id) as login_providers,
      (select count(*) from routine r where r.created_by = m.id and r.is_example = false) as routine_count,
      exists (select 1 from device_link d where d.member_id = m.id and d.redeemed_at is not null) as has_linked_device
    from member m
    order by m.created_at desc
    limit :limit
    """;

  // 활동 종류 5개 (AdminRecentActivityKind 이름과 같음). 카드 체크는 같은 일과·같은 시간대를 한 줄로
  private static final String RECENT_ACTIVITY_SQL = """
    select activity.activity_kind, activity.member_id, m.nickname, activity.occurred_at, activity.item_count
    from (
      select 'SIGNUP' as activity_kind, joined.id as member_id, joined.created_at as occurred_at, cast(1 as bigint) as item_count
      from member joined where joined.created_at >= :since
      union all
      select 'ROUTINE_CREATED', r.created_by, r.created_at, 1
      from routine r where r.is_example = false and r.created_at >= :since
      union all
      select 'CARD_CHECKED', r.created_by, max(s.completed_at), count(*)
      from routine_step s join routine r on r.id = s.routine_id
      where s.completed_at >= :since
      group by r.id, r.created_by, date_trunc('hour', s.completed_at)
      union all
      select 'DEVICE_LINKED', d.member_id, d.redeemed_at, 1
      from device_link d where d.redeemed_at >= :since
      union all
      select 'STORE_PURCHASE', p.member_id, p.created_at, 1
      from ai_credit_purchase p where p.member_id is not null and p.created_at >= :since
      union all
      select 'STORE_PURCHASE', sub.member_id, sub.started_at, 1
      from subscription sub where sub.source in (:storeSources) and sub.started_at >= :since
    ) activity
    join member m on m.id = activity.member_id
    where\s""" + COUNTED_MEMBER + """
     order by activity.occurred_at desc
    limit :limit
    """;

  // 후보만 먼저 좁힘: 일반·미확인·탈퇴 아님 + (메모 있음 또는 Apple 로그인). 규칙 판정은 AdminAccountKindSuggestionRules
  private static final String SUGGESTION_CANDIDATES_SQL = """
    select m.id, m.nickname, m.created_at, m.admin_memo,
      exists (select 1 from auth_identity a where a.member_id = m.id and a.provider = :appleProvider) as has_apple_login,
      exists (select 1 from auth_identity a where a.member_id = m.id
        and lower(a.email) like :privateRelayEmailPattern) as has_private_relay_email,
      (select count(*) from routine r where r.created_by = m.id and r.is_example = false) as user_routine_count,
      (select count(*) from member_daily_visit v where v.member_id = m.id) as visit_day_count
    from member m
    where\s""" + MemberAccountKind.COUNTED_MEMBER_SQL + """
       and m.account_kind_reviewed_at is null and m.status <> 'WITHDRAWN'
      and (m.admin_memo is not null
        or exists (select 1 from auth_identity a where a.member_id = m.id and a.provider = :appleProvider))
    order by m.created_at desc
    """;

  private final NamedParameterJdbcTemplate jdbcTemplate;

  /** 기간[from, to) 가입자 > 단계별 인원 */
  public FunnelCounts countFunnel(LocalDateTime from, LocalDateTime to, boolean isIncludingAllAccounts) {
    MapSqlParameterSource parameters = periodParameters(from, to, isIncludingAllAccounts)
      .addValue("storeSources", STORE_SOURCES);
    return jdbcTemplate.queryForObject(FUNNEL_SQL, parameters, (row, index) -> new FunnelCounts(
      row.getLong("signed_up_count"), row.getLong("routine_made_count"), row.getLong("card_checked_count"),
      row.getLong("device_linked_count"), row.getLong("store_paid_count")));
  }

  /** 기간[from, to) 가입 주별 인원과 1·2·4주 뒤 재방문 인원 (최근 주 먼저) */
  public List<RetentionCohortCounts> countRetentionCohorts(LocalDateTime from, LocalDateTime to, boolean isIncludingAllAccounts) {
    return jdbcTemplate.query(RETENTION_SQL, periodParameters(from, to, isIncludingAllAccounts),
      (row, index) -> new RetentionCohortCounts(
        row.getObject("cohort_week_start", LocalDate.class), row.getLong("cohort_size"),
        row.getLong("week1_returned_count"), row.getLong("week2_returned_count"), row.getLong("week4_returned_count")));
  }

  /** 기간[from, to) 주별 추이 4줄 (기록 있는 칸만) */
  public List<WeeklyCount> countWeeklyUsage(LocalDateTime from, LocalDateTime to, boolean isIncludingAllAccounts) {
    MapSqlParameterSource parameters = periodParameters(from, to, isIncludingAllAccounts)
      .addValue("fromDate", from.toLocalDate())
      .addValue("toDate", to.toLocalDate());
    return jdbcTemplate.query(WEEKLY_USAGE_SQL, parameters, (row, index) -> new WeeklyCount(
      row.getString("series_key"), row.getObject("week_start", LocalDate.class), row.getLong("total")));
  }

  /** now 기준 마지막 활동 분포 (탈퇴 제외) */
  public LastActivityCounts countLastActivity(LocalDateTime now, boolean isIncludingAllAccounts) {
    MapSqlParameterSource parameters = new MapSqlParameterSource("isIncludingAllAccounts", isIncludingAllAccounts)
      .addValue("oneDayAgo", now.minusDays(1))
      .addValue("sevenDaysAgo", now.minusDays(7))
      .addValue("thirtyDaysAgo", now.minusDays(30));
    return jdbcTemplate.queryForObject(LAST_ACTIVITY_SQL, parameters, (row, index) -> new LastActivityCounts(
      row.getLong("within_one_day_count"), row.getLong("within_seven_days_count"),
      row.getLong("within_thirty_days_count"), row.getLong("older_count"), row.getLong("never_count")));
  }

  /** 푸시 기기를 등록한 회원 수 (iOS, Android 각각, 둘 다 쓰면 양쪽에 셈) */
  public PlatformMemberCounts countPlatforms(boolean isIncludingAllAccounts) {
    return jdbcTemplate.queryForObject(PLATFORM_SQL, new MapSqlParameterSource("isIncludingAllAccounts", isIncludingAllAccounts),
      (row, index) -> new PlatformMemberCounts(row.getLong("ios_member_count"), row.getLong("android_member_count")));
  }

  /** 대시보드 요약 (일반 계정만): 이번 주 활성, 7일 리텐션 대상[cohortFrom, cohortTo)·재방문, 이번 주 카드 체크 */
  public HeadlineCounts countHeadline(LocalDate weekStart, LocalDateTime cohortFrom, LocalDateTime cohortTo) {
    MapSqlParameterSource parameters = new MapSqlParameterSource("isIncludingAllAccounts", false)
      .addValue("weekStartDate", weekStart)
      .addValue("weekStart", weekStart.atStartOfDay())
      .addValue("cohortFrom", cohortFrom)
      .addValue("cohortTo", cohortTo);
    return jdbcTemplate.queryForObject(HEADLINE_SQL, parameters, (row, index) -> new HeadlineCounts(
      row.getLong("weekly_active_count"), row.getLong("retention_cohort_size"), row.getLong("retained_count"),
      row.getLong("card_check_count")));
  }

  /** 최근 가입 limit 명 (계정 종류 무관, 화면이 배지로 구분) */
  public List<RecentSignupRow> findRecentSignups(int limit) {
    return jdbcTemplate.query(RECENT_SIGNUPS_SQL, new MapSqlParameterSource("limit", limit),
      (row, index) -> new RecentSignupRow(
        row.getString("id"), row.getString("nickname"), row.getObject("created_at", LocalDateTime.class),
        row.getString("login_providers"), row.getLong("routine_count"), row.getBoolean("has_linked_device"),
        row.getObject("last_activity_at", LocalDateTime.class), row.getString("account_kind")));
  }

  /** since 이후 최근 활동 limit 줄 (일반 계정만, 최신순) */
  public List<RecentActivityRow> findRecentActivities(LocalDateTime since, int limit) {
    MapSqlParameterSource parameters = new MapSqlParameterSource("isIncludingAllAccounts", false)
      .addValue("since", since)
      .addValue("limit", limit)
      .addValue("storeSources", STORE_SOURCES);
    return jdbcTemplate.query(RECENT_ACTIVITY_SQL, parameters, (row, index) -> new RecentActivityRow(
      row.getString("activity_kind"), row.getString("member_id"), row.getString("nickname"),
      row.getObject("occurred_at", LocalDateTime.class), row.getLong("item_count")));
  }

  /** 분류 제안 후보 (privateRelayEmailPattern: 소문자 like 패턴) */
  public List<SuggestionCandidate> findSuggestionCandidates(String privateRelayEmailPattern) {
    MapSqlParameterSource parameters = new MapSqlParameterSource("appleProvider", OAuthProvider.APPLE.name())
      .addValue("privateRelayEmailPattern", privateRelayEmailPattern);
    return jdbcTemplate.query(SUGGESTION_CANDIDATES_SQL, parameters, (row, index) -> new SuggestionCandidate(
      row.getString("id"), row.getString("nickname"), row.getObject("created_at", LocalDateTime.class),
      row.getString("admin_memo"), row.getBoolean("has_apple_login"), row.getBoolean("has_private_relay_email"),
      row.getLong("user_routine_count"), row.getLong("visit_day_count")));
  }

  private static MapSqlParameterSource periodParameters(LocalDateTime from, LocalDateTime to, boolean isIncludingAllAccounts) {
    return new MapSqlParameterSource("isIncludingAllAccounts", isIncludingAllAccounts)
      .addValue("from", from)
      .addValue("to", to);
  }

  // 가입 주 첫날 + 7×weeksLater 일부터 7일 안에 방문한 인원 (member 별칭 m)
  private static String returnedInWeekCount(int weeksLater, String columnAlias) {
    String cohortWeekStart = "cast(date_trunc('week', m.created_at) as date)";
    return "count(*) filter (where exists (select 1 from member_daily_visit v where v.member_id = m.id"
      + " and v.visit_date >= " + cohortWeekStart + " + " + (7 * weeksLater)
      + " and v.visit_date < " + cohortWeekStart + " + " + (7 * weeksLater + 7) + ")) as " + columnAlias;
  }
}
