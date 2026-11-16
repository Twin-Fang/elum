package com.chuseok22.elumserver.admin.application.dto.response;

/**
 * 대시보드 사용 요약 한 줄 (#1436, 일반 계정만): 이번 주 쓴 사람, 7일 리텐션(최근 4주 가입 중 7일 지난 사람), 이번 주 카드 체크
 */
public record AdminUsageHeadline(
  long weeklyActiveCount,
  /// 대상이 0명이면 null ("-")
  Integer sevenDayRetentionPercent,
  long retentionCohortSize,
  long cardCheckCount
) {
}
