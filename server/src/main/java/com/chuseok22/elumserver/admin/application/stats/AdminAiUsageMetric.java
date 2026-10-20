package com.chuseok22.elumserver.admin.application.stats;

import java.util.Locale;

/**
 * AI 사용량 그래프 지표 3개: 호출 수, 비용(원), 실패율(%) — 한 그래프에 축 하나만 (단위가 다른 값은 전환으로)
 * 화면 값: count, cost, failure (모르는 값은 호출 수)
 */
public enum AdminAiUsageMetric {

  CALL_COUNT("count"),
  COST_KRW("cost"),
  FAILURE_PERCENT("failure"),
  ;

  private final String parameterValue;

  AdminAiUsageMetric(String parameterValue) {
    this.parameterValue = parameterValue;
  }

  public String parameterValue() {
    return parameterValue;
  }

  public static AdminAiUsageMetric fromParameter(String value) {
    if (value != null) {
      String normalized = value.trim().toLowerCase(Locale.ROOT);
      for (AdminAiUsageMetric metric : values()) {
        if (metric.parameterValue.equals(normalized)) {
          return metric;
        }
      }
    }
    return CALL_COUNT;
  }
}
