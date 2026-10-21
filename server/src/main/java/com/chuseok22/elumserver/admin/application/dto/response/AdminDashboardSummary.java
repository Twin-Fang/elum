package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDateTime;

/**
 * 대시보드 집계 한 벌: 회원, 요금제 분포, 일과, 오늘 AI 호출, 지금 적용 중 설정 요약, 지금·오늘 숫자, 확인할 일
 * aggregatedAt: 집계한 시각 (60초 캐시라 화면 시각보다 늦을 수 있음)
 */
public record AdminDashboardSummary(
  long memberCount,
  long activeMemberCount,
  long suspendedMemberCount,
  long proMemberCount,
  long freeMemberCount,
  AdminRoutineStatusCounts routineStats,
  TodayAiStats todayAiStats,
  SettingsOverview configOverview,
  AdminDashboardActivity activity,
  AdminDashboardAttention attention,
  double usdToKrwRate,
  LocalDateTime aggregatedAt
) {

  /// 오늘 AI 추정 비용 원화 (환율 0 이면 0)
  public long todayAiCostKrw() {
    return Math.round(todayAiStats.totalCostUsd() * usdToKrwRate);
  }

  /// Pro 비율(%) — 막대 폭용. 회원이 없으면 0
  public int proPercent() {
    return memberCount <= 0 ? 0 : (int) Math.min(100, Math.round(proMemberCount * 100.0 / memberCount));
  }

  /// Free 비율(%) — Pro 비율의 나머지
  public int freePercent() {
    return memberCount <= 0 ? 0 : 100 - proPercent();
  }

  /** 오늘 AI 호출 요약 (조회 투영을 캐시에 오래 들고 있지 않도록 값만 복사) */
  public record TodayAiStats(long totalCount, long successCount, long totalTokens, double totalCostUsd) {
  }
}
