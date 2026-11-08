package com.chuseok22.elumserver.admin.application.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * 관제소 확인할 일 1건 (attention v1 item): kind count > count, kind gauge > value·limit·unit
 * 개수·값만 실음 (의견 내용·회원 정보 금지). null 필드는 응답에서 생략
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ControlTowerAttentionItem(
  String key,
  String label,
  String kind,
  ControlTowerAttentionLevel level,
  @JsonProperty("admin_url") String adminUrl,
  Long count,
  Double value,
  Double limit,
  String unit
) {

  /// kind 값 2개: 처리 안 된 개수, 현재 값과 상한
  static final String KIND_COUNT = "count";
  static final String KIND_GAUGE = "gauge";

  public static ControlTowerAttentionItem count(
    String key, String label, long count, ControlTowerAttentionLevel level, String adminUrl
  ) {
    return new ControlTowerAttentionItem(key, label, KIND_COUNT, level, adminUrl, count, null, null, null);
  }

  /// limit null 이면 상한 없음 (응답에서 생략)
  public static ControlTowerAttentionItem gauge(
    String key, String label, double value, Double limit, String unit, ControlTowerAttentionLevel level,
    String adminUrl
  ) {
    return new ControlTowerAttentionItem(key, label, KIND_GAUGE, level, adminUrl, null, value, limit, unit);
  }
}
