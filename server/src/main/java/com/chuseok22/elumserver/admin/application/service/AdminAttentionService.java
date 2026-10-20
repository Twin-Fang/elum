package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardActivity;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardAttention;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary.TodayAiStats;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStatusCounts;
import com.chuseok22.elumserver.ai.application.service.AiCallStatsService;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.member.application.service.MemberStatsService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 대시보드 지금 상태 모음: 접속·방문·가입 숫자, 확인할 일(새 의견, 검토 대기, AI 이상, 멈춘 예약, 비용 상한)
 * 캐시는 부르는 쪽(AdminDashboardService 60초)
 */
@Service
@RequiredArgsConstructor
public class AdminAttentionService {

  private final MemberStatsService memberStatsService;
  private final FeedbackService feedbackService;
  private final AiCallStatsService aiCallStatsService;
  private final AdminCreditQueryService adminCreditQueryService;
  private final SystemConfigService systemConfigService;

  public AdminDashboardActivity loadActivity(LocalDateTime now) {
    LocalDate today = now.toLocalDate();
    return new AdminDashboardActivity(
      memberStatsService.countOnline(now),
      memberStatsService.countVisitsOn(today),
      memberStatsService.countVisitsOn(today.minusDays(1)),
      memberStatsService.countJoinedOn(today));
  }

  public AdminDashboardAttention loadAttention(
    LocalDateTime now, AdminRoutineStatusCounts routineStats, TodayAiStats todayAiStats
  ) {
    return new AdminDashboardAttention(
      feedbackService.countNew(),
      routineStats.pendingReview(),
      adminCreditQueryService.countStuckReservations(),
      aiCallStatsService.loadHealthSnapshot(now),
      systemConfigService.getDouble(ConfigKey.AI_DAILY_BUDGET_USD),
      todayAiStats.totalCostUsd());
  }
}
