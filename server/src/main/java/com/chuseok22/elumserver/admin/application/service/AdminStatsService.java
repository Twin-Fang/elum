package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminAiMonthSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminTrendChart;
import com.chuseok22.elumserver.admin.application.dto.response.AdminTrendSeries;
import com.chuseok22.elumserver.admin.application.stats.AdminAiUsageMetric;
import com.chuseok22.elumserver.admin.application.stats.AdminStatsCache;
import com.chuseok22.elumserver.admin.application.stats.AdminTrendRange;
import com.chuseok22.elumserver.ai.application.service.AiCallStatsService;
import com.chuseok22.elumserver.ai.core.AiCallPurpose;
import com.chuseok22.elumserver.ai.application.dto.response.AiCallTypeUsage;
import com.chuseok22.elumserver.ai.application.dto.response.AiUsageBucket;
import com.chuseok22.elumserver.common.application.stats.StatsBucketCount;
import com.chuseok22.elumserver.common.application.stats.StatsBucketUnit;
import com.chuseok22.elumserver.member.application.service.MemberStatsService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.LongSupplier;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 관리자 추이 그래프: 가입·탈퇴, 방문, AI 사용량(용도별) + AI 이번 달 요약
 * DB 는 기록 있는 칸만 돌려줌 > 여기서 빈 칸 0 채움 (방문은 기록 시작 전 칸 null). 결과는 60초 캐시
 */
@Service
public class AdminStatsService {

  /// 일별 기본 기간: 대시보드·AI 모니터링 30일, 회원 관리 90일
  public static final int DEFAULT_DAYS = 30;
  public static final int MEMBER_PAGE_DEFAULT_DAYS = 90;

  private static final String SERIES_JOINED = "joined";
  private static final String SERIES_WITHDRAWN = "withdrawn";
  private static final String SERIES_VISITS = "visits";

  private final MemberStatsService memberStatsService;
  private final AiCallStatsService aiCallStatsService;
  private final SystemConfigService systemConfigService;
  private final AdminStatsCache<AdminTrendChart> trendCache;

  @Autowired
  public AdminStatsService(
    MemberStatsService memberStatsService, AiCallStatsService aiCallStatsService, SystemConfigService systemConfigService
  ) {
    this(memberStatsService, aiCallStatsService, systemConfigService, System::currentTimeMillis);
  }

  /// 시험에서 캐시 시계를 바꿔 끼우려고 열어 둔 생성자
  AdminStatsService(
    MemberStatsService memberStatsService, AiCallStatsService aiCallStatsService,
    SystemConfigService systemConfigService, LongSupplier currentMilliseconds
  ) {
    this.memberStatsService = memberStatsService;
    this.aiCallStatsService = aiCallStatsService;
    this.systemConfigService = systemConfigService;
    this.trendCache = new AdminStatsCache<>(currentMilliseconds);
  }

  /** 가입·탈퇴 추이 */
  public AdminTrendChart loadSignupTrend(AdminTrendRange range) {
    return trendCache.getOrLoad("signup|" + range.cacheKey(), () -> {
      List<LocalDate> bucketStarts = range.unit().bucketStartsBetween(range.from(), range.to());
      LocalDate queryFrom = bucketStarts.get(0);
      return toChart(range.unit(), bucketStarts, List.of(
        new AdminTrendSeries(SERIES_JOINED, "신규 가입", fillCounts(bucketStarts,
          memberStatsService.countJoinedByBucket(range.unit(), queryFrom, range.to()))),
        new AdminTrendSeries(SERIES_WITHDRAWN, "탈퇴", fillCounts(bucketStarts,
          memberStatsService.countWithdrawnByBucket(range.unit(), queryFrom, range.to())))));
    });
  }

  /** 방문 추이 (기록 시작 전 칸은 null) */
  public AdminTrendChart loadVisitTrend(AdminTrendRange range) {
    return trendCache.getOrLoad("visit|" + range.cacheKey(), () -> {
      List<LocalDate> bucketStarts = range.unit().bucketStartsBetween(range.from(), range.to());
      List<Number> counts = fillCounts(bucketStarts,
        memberStatsService.countVisitsByBucket(range.unit(), bucketStarts.get(0), range.to()));
      blankBeforeTrackingStart(range.unit(), bucketStarts, counts, memberStatsService.findVisitTrackingStartDate());
      return toChart(range.unit(), bucketStarts, List.of(new AdminTrendSeries(SERIES_VISITS, "방문", counts)));
    });
  }

  /** AI 사용량 추이: 지표별 용도 줄 */
  public AdminTrendChart loadAiUsageTrend(AdminTrendRange range, AdminAiUsageMetric metric) {
    return trendCache.getOrLoad("ai|" + metric.parameterValue() + "|" + range.cacheKey(), () -> {
      List<LocalDate> bucketStarts = range.unit().bucketStartsBetween(range.from(), range.to());
      Map<AiCallPurpose, Map<String, UsageTotals>> totalsByPurpose = sumByPurposeAndBucket(
        aiCallStatsService.sumUsageByBucket(range.unit(), bucketStarts.get(0), range.to()));
      double usdToKrwRate = loadUsdToKrwRate();
      return toChart(range.unit(), bucketStarts, toPurposeSeries(bucketStarts, totalsByPurpose, metric, usdToKrwRate));
    });
  }

  /** AI 이번 달 요약 (1일 0시 ~ 지금) */
  public AdminAiMonthSummary loadAiMonthSummary(LocalDateTime now) {
    LocalDateTime monthStart = now.toLocalDate().withDayOfMonth(1).atStartOfDay();
    List<AiCallTypeUsage> usages = aiCallStatsService.sumUsageByCallType(monthStart, now.plusSeconds(1));
    long callCount = usages.stream().mapToLong(AiCallTypeUsage::totalCount).sum();
    long successCount = usages.stream().mapToLong(AiCallTypeUsage::successCount).sum();
    double costUsd = usages.stream().mapToDouble(AiCallTypeUsage::costUsd).sum();
    long routineCreateCount = usages.stream()
      .filter(usage -> usage.callType().getPurpose() == AiCallPurpose.ROUTINE_CREATE)
      .mapToLong(AiCallTypeUsage::successCount)
      .sum();
    double usdToKrwRate = loadUsdToKrwRate();
    return new AdminAiMonthSummary(
      callCount,
      callCount == 0 ? 0 : roundOneDecimal((callCount - successCount) * 100.0 / callCount),
      costUsd,
      Math.round(costUsd * usdToKrwRate),
      routineCreateCount == 0 ? null : Math.round(costUsd * usdToKrwRate / routineCreateCount),
      toProviderCosts(usages));
  }

  /** 시스템 설정 환율 (0 이하·숫자 아님이면 0 — 원화 표시만 비고 화면은 그대로) */
  public double loadUsdToKrwRate() {
    double rate = systemConfigService.getDouble(ConfigKey.USD_TO_KRW_RATE);
    return Double.isNaN(rate) || rate <= 0 ? 0 : rate;
  }

  // --- 칸 채우기 ---

  // 칸 첫날 순서대로 건수, 기록 없는 칸 0
  static List<Number> fillCounts(List<LocalDate> bucketStarts, List<StatsBucketCount> rows) {
    Map<String, Long> totalByBucket = new HashMap<>();
    rows.forEach(row -> totalByBucket.merge(row.getBucket(), row.getTotal(), Long::sum));
    List<Number> counts = new ArrayList<>(bucketStarts.size());
    bucketStarts.forEach(start -> counts.add(totalByBucket.getOrDefault(start.toString(), 0L)));
    return counts;
  }

  // 칸 전체가 기록 시작일 이전이면 null (기록이 아예 없으면 전부 null)
  static void blankBeforeTrackingStart(
    StatsBucketUnit unit, List<LocalDate> bucketStarts, List<Number> counts, LocalDate trackingStartDate
  ) {
    for (int index = 0; index < bucketStarts.size(); index++) {
      LocalDate nextBucketStart = unit.nextBucketStart(bucketStarts.get(index));
      if (trackingStartDate == null || !nextBucketStart.isAfter(trackingStartDate)) {
        counts.set(index, null);
      }
    }
  }

  private static AdminTrendChart toChart(StatsBucketUnit unit, List<LocalDate> bucketStarts, List<AdminTrendSeries> series) {
    return new AdminTrendChart(
      unit.sqlName(),
      bucketStarts.stream().map(unit::labelOf).toList(),
      bucketStarts.stream().map(LocalDate::toString).toList(),
      series);
  }

  // --- AI 용도별 ---

  /** 칸 하나의 호출 수·성공 수·비용 합 */
  private record UsageTotals(long totalCount, long successCount, double costUsd) {

    UsageTotals plus(UsageTotals other) {
      return new UsageTotals(totalCount + other.totalCount, successCount + other.successCount, costUsd + other.costUsd);
    }
  }

  // 유형 칸 > 용도·칸별 합
  private static Map<AiCallPurpose, Map<String, UsageTotals>> sumByPurposeAndBucket(List<AiUsageBucket> buckets) {
    Map<AiCallPurpose, Map<String, UsageTotals>> totalsByPurpose = new EnumMap<>(AiCallPurpose.class);
    for (AiUsageBucket bucket : buckets) {
      totalsByPurpose.computeIfAbsent(bucket.callType().getPurpose(), purpose -> new HashMap<>())
        .merge(bucket.bucket(), new UsageTotals(bucket.totalCount(), bucket.successCount(), bucket.costUsd()),
          UsageTotals::plus);
    }
    return totalsByPurpose;
  }

  private static List<AdminTrendSeries> toPurposeSeries(
    List<LocalDate> bucketStarts, Map<AiCallPurpose, Map<String, UsageTotals>> totalsByPurpose,
    AdminAiUsageMetric metric, double usdToKrwRate
  ) {
    List<AdminTrendSeries> series = new ArrayList<>();
    totalsByPurpose.forEach((purpose, totalsByBucket) -> {
      List<Number> values = new ArrayList<>(bucketStarts.size());
      for (LocalDate start : bucketStarts) {
        values.add(toMetricValue(totalsByBucket.get(start.toString()), metric, usdToKrwRate));
      }
      series.add(new AdminTrendSeries(purpose.name(), purpose.getLabel(), values));
    });
    return series;
  }

  // 칸 값: 호출 수(없으면 0) · 비용 원(없으면 0) · 실패율(호출 없으면 null — 0%와 구분)
  private static Number toMetricValue(UsageTotals totals, AdminAiUsageMetric metric, double usdToKrwRate) {
    return switch (metric) {
      case COST_KRW -> totals == null ? 0L : Math.round(totals.costUsd() * usdToKrwRate);
      case FAILURE_PERCENT -> totals == null || totals.totalCount() == 0
        ? null
        : roundOneDecimal((totals.totalCount() - totals.successCount()) * 100.0 / totals.totalCount());
      case CALL_COUNT -> totals == null ? 0L : totals.totalCount();
    };
  }

  // 제공자 줄별 비용, 큰 순 (0원 줄 제외)
  private static List<AdminAiMonthSummary.ProviderCost> toProviderCosts(List<AiCallTypeUsage> usages) {
    Map<String, Double> costByLane = new LinkedHashMap<>();
    usages.forEach(usage ->
      costByLane.merge(usage.callType().providerLaneLabel(), usage.costUsd(), Double::sum));
    return costByLane.entrySet().stream()
      .filter(entry -> entry.getValue() > 0)
      .map(entry -> new AdminAiMonthSummary.ProviderCost(entry.getKey(), entry.getValue()))
      .sorted(Comparator.comparingDouble(AdminAiMonthSummary.ProviderCost::costUsd).reversed())
      .toList();
  }

  private static double roundOneDecimal(double value) {
    return Math.round(value * 10) / 10.0;
  }
}
