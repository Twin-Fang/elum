package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.analytics.AdminAccountKindSuggestionRules;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsPeriod;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSection;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSectionLoader;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSectionName;
import com.chuseok22.elumserver.admin.application.analytics.AdminFirstDayActivationKind;
import com.chuseok22.elumserver.admin.application.dto.response.AdminAccountKindSuggestion;
import com.chuseok22.elumserver.admin.application.dto.response.AdminFirstDayActivationGroup;
import com.chuseok22.elumserver.admin.application.dto.response.AdminLabeledCount;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRetentionCohort;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRetentionCohort.Cell;
import com.chuseok22.elumserver.admin.application.dto.response.AdminTrendChart;
import com.chuseok22.elumserver.admin.application.dto.response.AdminTrendSeries;
import com.chuseok22.elumserver.admin.application.dto.response.AdminUsageAnalyticsView;
import com.chuseok22.elumserver.admin.application.dto.response.AdminUsageFunnel;
import com.chuseok22.elumserver.admin.application.dto.response.AdminUsageFunnel.Stage;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsQueries;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.FirstDayActivationCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.FunnelCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.LastActivityCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.PlatformMemberCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.RetentionCohortCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.WeeklyCount;
import com.chuseok22.elumserver.member.application.service.MemberStatsService;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.LongSupplier;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 사용 분석 화면 (#1436): 가입 단계 > 가입 주차 리텐션 > 첫날 한 일별 재방문(#1471) > 마지막 활동 분포 > 플랫폼 > 분류 제안, 주별 추이 JSON
 * 집계 SQL 은 AdminUsageAnalyticsQueries, 여기서는 비율·문구·빈 칸 채우기. 분류 제안 외 칸은 60초 캐시, 칸별 독립 실패
 */
@Service
public class AdminUsageAnalyticsService {

  /// 리텐션 칸: 가입 주로부터 몇 주 뒤 (1·2·4주)
  public static final List<Integer> RETENTION_WEEKS_LATER = List.of(1, 2, 4);
  /// 주별 추이 단위 이름·x축 날짜 형식 (주 첫날 월요일)
  private static final String WEEK_UNIT_NAME = "week";
  private static final DateTimeFormatter WEEK_LABEL_FORMATTER = DateTimeFormatter.ofPattern("M/d");
  private static final int DAYS_PER_WEEK = 7;
  /// 주별 추이 줄 4개: key(AdminUsageAnalyticsQueries 의 series_key) > 이름
  private static final String SERIES_WEEKLY_ACTIVE = "WEEKLY_ACTIVE";
  private static final Map<String, String> WEEKLY_SERIES_LABEL_BY_KEY = orderedSeriesLabels();
  /// 가입 단계 5개 이름 (FunnelCounts 순서)
  private static final List<String> FUNNEL_STAGE_LABELS = List.of("가입", "일과 만듦", "카드 체크", "기기 연결", "스토어 결제");
  /// 마지막 활동 분포 5칸 이름 (LastActivityCounts 순서)
  private static final List<String> LAST_ACTIVITY_LABELS = List.of("1일 안", "7일 안", "30일 안", "30일 넘음", "기록 없음");

  private final AdminUsageAnalyticsQueries usageAnalyticsQueries;
  private final MemberStatsService memberStatsService;
  private final AdminAnalyticsSectionLoader sectionLoader;

  @Autowired
  public AdminUsageAnalyticsService(AdminUsageAnalyticsQueries usageAnalyticsQueries, MemberStatsService memberStatsService) {
    this(usageAnalyticsQueries, memberStatsService, System::currentTimeMillis);
  }

  /// 시험에서 캐시 시계를 바꿔 끼우려고 열어 둔 생성자
  AdminUsageAnalyticsService(
    AdminUsageAnalyticsQueries usageAnalyticsQueries, MemberStatsService memberStatsService,
    LongSupplier currentMilliseconds
  ) {
    this.usageAnalyticsQueries = usageAnalyticsQueries;
    this.memberStatsService = memberStatsService;
    this.sectionLoader = new AdminAnalyticsSectionLoader(currentMilliseconds);
  }

  /** 화면 칸 6개 (각각 실패해도 나머지는 보임) */
  public AdminUsageAnalyticsView loadView(AdminAnalyticsPeriod period, LocalDateTime now) {
    String cacheKey = period.cacheKey();
    return new AdminUsageAnalyticsView(
      period,
      sectionLoader.loadCached(AdminAnalyticsSectionName.FUNNEL, cacheKey, () -> loadFunnel(period)),
      sectionLoader.loadCached(AdminAnalyticsSectionName.RETENTION, cacheKey, () -> loadRetentionCohorts(period)),
      sectionLoader.loadCached(AdminAnalyticsSectionName.FIRST_DAY_ACTIVATION, cacheKey,
        () -> loadFirstDayActivationGroups(period)),
      sectionLoader.loadCached(AdminAnalyticsSectionName.LAST_ACTIVITY, cacheKey,
        () -> loadLastActivityDistribution(period, now)),
      sectionLoader.loadCached(AdminAnalyticsSectionName.PLATFORM, cacheKey, () -> loadPlatformMemberCounts(period)),
      sectionLoader.load(AdminAnalyticsSectionName.SUGGESTION, () -> loadSuggestions(now)));
  }

  /** 주별 추이 4줄 (주간 활성은 방문 기록 시작 전 주 null). 실패하면 칸 실패로 돌려줌 */
  public AdminAnalyticsSection<AdminTrendChart> loadWeeklyTrend(AdminAnalyticsPeriod period) {
    return sectionLoader.loadCached(AdminAnalyticsSectionName.TRENDS, period.cacheKey(), () -> buildWeeklyTrend(period));
  }

  // --- 칸별 ---

  private AdminUsageFunnel loadFunnel(AdminAnalyticsPeriod period) {
    FunnelCounts counts = usageAnalyticsQueries.countFunnel(period.from(), period.toExclusive(),
      period.isIncludingAllAccounts());
    return toFunnel(List.of(counts.signedUpCount(), counts.routineMadeCount(), counts.cardCheckedCount(),
      counts.deviceLinkedCount(), counts.storePaidCount()));
  }

  /** 단계 인원 5개 > 가입 대비·이전 단계 대비 % (이전 0명이면 null) */
  public static AdminUsageFunnel toFunnel(List<Long> stageCounts) {
    long signedUpCount = stageCounts.get(0);
    List<Stage> stages = new ArrayList<>(stageCounts.size());
    for (int index = 0; index < stageCounts.size(); index++) {
      long count = stageCounts.get(index);
      Long previousCount = index == 0 ? null : stageCounts.get(index - 1);
      stages.add(new Stage(FUNNEL_STAGE_LABELS.get(index), count, percentOf(count, signedUpCount),
        previousCount == null || previousCount == 0 ? null : percentOf(count, previousCount)));
    }
    return new AdminUsageFunnel(stages);
  }

  private List<AdminRetentionCohort> loadRetentionCohorts(AdminAnalyticsPeriod period) {
    LocalDate trackingStartDate = memberStatsService.findVisitTrackingStartDate();
    return usageAnalyticsQueries.countRetentionCohorts(period.from(), period.toExclusive(),
        period.isIncludingAllAccounts()).stream()
      .map(counts -> toRetentionCohort(counts, period.today(), trackingStartDate))
      .toList();
  }

  private static AdminRetentionCohort toRetentionCohort(
    RetentionCohortCounts counts, LocalDate today, LocalDate trackingStartDate
  ) {
    List<Long> returnedCounts = List.of(
      counts.week1ReturnedCount(), counts.week2ReturnedCount(), counts.week4ReturnedCount());
    List<Cell> cells = new ArrayList<>(RETENTION_WEEKS_LATER.size());
    for (int index = 0; index < RETENTION_WEEKS_LATER.size(); index++) {
      cells.add(Cell.of(counts.cohortWeekStart(), RETENTION_WEEKS_LATER.get(index), returnedCounts.get(index),
        counts.cohortSize(), today, trackingStartDate));
    }
    return new AdminRetentionCohort(WEEK_LABEL_FORMATTER.format(counts.cohortWeekStart()) + " 주",
      counts.cohortSize(), cells);
  }

  private List<AdminFirstDayActivationGroup> loadFirstDayActivationGroups(AdminAnalyticsPeriod period) {
    LocalDate trackingStartDate = memberStatsService.findVisitTrackingStartDate();
    List<FirstDayActivationCounts> counts = usageAnalyticsQueries.countFirstDayActivations(period.from(),
      period.toExclusive(), period.isIncludingAllAccounts(), period.today(),
      trackingStartDate == null ? period.today() : trackingStartDate);
    return toFirstDayActivationGroups(counts);
  }

  /** 묶음별 숫자 > 4줄 고정 순서 (없는 묶음 0명, 모두 0명이면 빈 목록) */
  public static List<AdminFirstDayActivationGroup> toFirstDayActivationGroups(List<FirstDayActivationCounts> counts) {
    Map<String, FirstDayActivationCounts> countsByKind = new HashMap<>();
    counts.forEach(count -> countsByKind.put(count.activationKind(), count));
    if (counts.stream().allMatch(count -> count.memberCount() == 0)) {
      return List.of();
    }
    List<AdminFirstDayActivationGroup> groups = new ArrayList<>();
    for (AdminFirstDayActivationKind kind : AdminFirstDayActivationKind.values()) {
      FirstDayActivationCounts count = countsByKind.getOrDefault(kind.name(),
        new FirstDayActivationCounts(kind.name(), 0, 0, 0));
      groups.add(AdminFirstDayActivationGroup.of(kind.label(), count.memberCount(), count.maturedCount(),
        count.retainedCount()));
    }
    return groups;
  }

  private List<AdminLabeledCount> loadLastActivityDistribution(AdminAnalyticsPeriod period, LocalDateTime now) {
    LastActivityCounts counts = usageAnalyticsQueries.countLastActivity(now, period.isIncludingAllAccounts());
    return AdminLabeledCount.withPercents(LAST_ACTIVITY_LABELS, List.of(counts.withinOneDayCount(),
      counts.withinSevenDaysCount(), counts.withinThirtyDaysCount(), counts.olderCount(), counts.neverCount()));
  }

  private List<AdminLabeledCount> loadPlatformMemberCounts(AdminAnalyticsPeriod period) {
    PlatformMemberCounts counts = usageAnalyticsQueries.countPlatforms(period.isIncludingAllAccounts());
    return AdminLabeledCount.withPercents(List.of("iOS", "Android"),
      List.of(counts.iosMemberCount(), counts.androidMemberCount()));
  }

  private List<AdminAccountKindSuggestion> loadSuggestions(LocalDateTime now) {
    return usageAnalyticsQueries.findSuggestionCandidates(AdminAccountKindSuggestionRules.privateRelayEmailLikePattern())
      .stream()
      .map(candidate -> AdminAccountKindSuggestionRules.suggest(candidate, now))
      .flatMap(Optional::stream)
      .toList();
  }

  // --- 주별 추이 ---

  private AdminTrendChart buildWeeklyTrend(AdminAnalyticsPeriod period) {
    List<LocalDate> weekStarts = period.weekStarts();
    Map<String, Map<LocalDate, Long>> totalsBySeries = new HashMap<>();
    for (WeeklyCount count : usageAnalyticsQueries.countWeeklyUsage(period.from(), period.toExclusive(),
      period.isIncludingAllAccounts())) {
      totalsBySeries.computeIfAbsent(count.seriesKey(), key -> new HashMap<>()).merge(count.weekStart(), count.total(), Long::sum);
    }
    LocalDate trackingStartDate = memberStatsService.findVisitTrackingStartDate();
    List<AdminTrendSeries> series = new ArrayList<>();
    WEEKLY_SERIES_LABEL_BY_KEY.forEach((key, label) -> {
      Map<LocalDate, Long> totalByWeek = totalsBySeries.getOrDefault(key, Map.of());
      List<Number> values = new ArrayList<>(weekStarts.size());
      for (LocalDate weekStart : weekStarts) {
        boolean isBeforeTracking = SERIES_WEEKLY_ACTIVE.equals(key) && isWeekBeforeTracking(weekStart, trackingStartDate);
        values.add(isBeforeTracking ? null : totalByWeek.getOrDefault(weekStart, 0L));
      }
      series.add(new AdminTrendSeries(key, label, values));
    });
    return new AdminTrendChart(WEEK_UNIT_NAME,
      weekStarts.stream().map(WEEK_LABEL_FORMATTER::format).toList(),
      weekStarts.stream().map(LocalDate::toString).toList(),
      series);
  }

  // 주 전체가 방문 기록 시작일 전 (기록이 아예 없으면 모든 주)
  private static boolean isWeekBeforeTracking(LocalDate weekStart, LocalDate trackingStartDate) {
    return trackingStartDate == null || !weekStart.plusDays(DAYS_PER_WEEK).isAfter(trackingStartDate);
  }

  private static int percentOf(long count, long total) {
    return total == 0 ? 0 : (int) Math.round(count * 100.0 / total);
  }

  private static Map<String, String> orderedSeriesLabels() {
    Map<String, String> labels = new LinkedHashMap<>();
    labels.put("SIGNUPS", "신규 가입");
    labels.put(SERIES_WEEKLY_ACTIVE, "주간 활성");
    labels.put("ROUTINES_MADE", "일과 만듦");
    labels.put("CARD_CHECKS", "카드 체크");
    return labels;
  }
}
