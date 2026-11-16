package com.chuseok22.elumserver.admin.application.analytics;

/**
 * 사용 분석·대시보드 칸 9개 > 에러 코드 E-ADMIN-ANALYTICS-{칸} (화면 노출·로그 공통)
 */
public enum AdminAnalyticsSectionName {
  FUNNEL,
  RETENTION,
  TRENDS,
  LAST_ACTIVITY,
  PLATFORM,
  SUGGESTION,
  HEADLINE,
  RECENT_SIGNUPS,
  RECENT_ACTIVITY,
  ;

  private static final String ERROR_CODE_PREFIX = "E-ADMIN-ANALYTICS-";

  public String errorCode() {
    return ERROR_CODE_PREFIX + name().replace('_', '-');
  }
}
