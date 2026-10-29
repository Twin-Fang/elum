package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary.TodayAiStats;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStatusCounts;
import com.chuseok22.elumserver.admin.application.dto.response.SettingRow;
import java.time.LocalDateTime;
import java.util.List;
import java.util.function.LongSupplier;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 대시보드 집계: 회원·요금제 분포·일과·오늘 AI 호출·지금 적용 중 설정 요약·지금 숫자·확인할 일
 * 60초 메모리 캐시 (SystemConfigService 와 같은 방식, 인스턴스별). 새로 집계하다 실패하면 이전 집계 유지
 */
@Slf4j
@Service
public class AdminDashboardService {

  /// 집계 캐시 유지 시간 (60초)
  static final long CACHE_TTL_MILLISECONDS = 60_000L;
  /// 대시보드 활성 회원 기준 일수
  private static final int ACTIVE_MEMBER_WITHIN_DAYS = 7;

  private final AdminMemberService adminMemberService;
  private final AdminRoutineService adminRoutineService;
  private final AdminMonitoringService adminMonitoringService;
  private final SystemConfigOverviewService systemConfigOverviewService;
  private final AdminAttentionService adminAttentionService;
  private final AdminStatsService adminStatsService;
  private final LongSupplier currentMilliseconds;

  private volatile AdminDashboardSummary cachedSummary;
  private volatile long cachedAtMilliseconds;

  @Autowired
  public AdminDashboardService(
    AdminMemberService adminMemberService,
    AdminRoutineService adminRoutineService,
    AdminMonitoringService adminMonitoringService,
    SystemConfigOverviewService systemConfigOverviewService,
    AdminAttentionService adminAttentionService,
    AdminStatsService adminStatsService
  ) {
    this(adminMemberService, adminRoutineService, adminMonitoringService, systemConfigOverviewService,
      adminAttentionService, adminStatsService, System::currentTimeMillis);
  }

  /// 시험에서 시계를 바꿔 끼우려고 열어 둔 생성자
  AdminDashboardService(
    AdminMemberService adminMemberService,
    AdminRoutineService adminRoutineService,
    AdminMonitoringService adminMonitoringService,
    SystemConfigOverviewService systemConfigOverviewService,
    AdminAttentionService adminAttentionService,
    AdminStatsService adminStatsService,
    LongSupplier currentMilliseconds
  ) {
    this.adminMemberService = adminMemberService;
    this.adminRoutineService = adminRoutineService;
    this.adminMonitoringService = adminMonitoringService;
    this.systemConfigOverviewService = systemConfigOverviewService;
    this.adminAttentionService = adminAttentionService;
    this.adminStatsService = adminStatsService;
    this.currentMilliseconds = currentMilliseconds;
  }

  public AdminDashboardSummary summary() {
    AdminDashboardSummary current = cachedSummary;
    if (current != null && isFresh()) {
      return current;
    }
    return reload(current);
  }

  private boolean isFresh() {
    return currentMilliseconds.getAsLong() - cachedAtMilliseconds < CACHE_TTL_MILLISECONDS;
  }

  // 동시 요청이 겹쳐도 집계는 한 번만 (먼저 들어온 쪽이 채우면 나머지는 그 값을 쓴다)
  private synchronized AdminDashboardSummary reload(AdminDashboardSummary stale) {
    if (cachedSummary != null && isFresh()) {
      return cachedSummary;
    }
    try {
      AdminDashboardSummary loaded = aggregate();
      cachedSummary = loaded;
      cachedAtMilliseconds = currentMilliseconds.getAsLong();
      return loaded;
    } catch (RuntimeException e) {
      // 이전 집계가 있으면 그것을 보여준다 (집계 실패로 대시보드가 500 이 되지 않게)
      if (stale == null) {
        throw e;
      }
      log.warn("[admin dashboard] aggregate failed, serving stale summary", e);
      return stale;
    }
  }

  private AdminDashboardSummary aggregate() {
    long memberCount = adminMemberService.count();
    long proMemberCount = adminMemberService.countEffectivePro();
    LocalDateTime now = LocalDateTime.now();
    List<SettingRow> settingRows = systemConfigOverviewService.buildRows();
    AdminRoutineStatusCounts routineStats = adminRoutineService.getStatusCounts();
    TodayAiStats todayAiStats = adminMonitoringService.getTodayStatsSummary();
    return new AdminDashboardSummary(
      memberCount,
      adminMemberService.countActiveWithinDays(ACTIVE_MEMBER_WITHIN_DAYS),
      adminMemberService.countSuspended(),
      proMemberCount,
      Math.max(memberCount - proMemberCount, 0),
      routineStats,
      todayAiStats,
      systemConfigOverviewService.buildOverview(settingRows, now),
      adminAttentionService.loadActivity(now),
      adminAttentionService.loadAttention(now, routineStats, todayAiStats),
      adminStatsService.loadUsdToKrwRate(),
      now
    );
  }
}
