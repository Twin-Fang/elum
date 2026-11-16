package com.chuseok22.elumserver.admin.application.analytics;

/**
 * 사용 분석 칸 하나의 결과: 값 또는 실패 에러 코드 (칸별 독립, 한 칸 실패가 화면 전체를 깨지 않음)
 */
public record AdminAnalyticsSection<T>(T value, String errorCode) {

  public static <T> AdminAnalyticsSection<T> loaded(T value) {
    return new AdminAnalyticsSection<>(value, null);
  }

  public static <T> AdminAnalyticsSection<T> failed(String errorCode) {
    return new AdminAnalyticsSection<>(null, errorCode);
  }

  public boolean isLoadFailed() {
    return errorCode != null;
  }
}
