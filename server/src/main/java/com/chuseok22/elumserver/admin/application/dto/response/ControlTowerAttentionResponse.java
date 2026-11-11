package com.chuseok22.elumserver.admin.application.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * 관제소 확인할 일 스냅샷 (attention v1): 규격 이름·버전, 출처, 만든 시각(UTC ISO 8601), 항목 전체
 * 증분이 아니라 매번 전체 항목 (0건 항목도 포함)
 */
public record ControlTowerAttentionResponse(
  String schema,
  String version,
  ControlTowerAttentionSource source,
  @JsonProperty("generated_at") String generatedAt,
  List<ControlTowerAttentionItem> items
) {

  /// 관제소 규격 이름·버전 (필드만 더하면 부 버전만 올림)
  public static final String SCHEMA_NAME = "attention";
  public static final String SCHEMA_VERSION = "1.0";

  public static ControlTowerAttentionResponse of(
    ControlTowerAttentionSource source, String generatedAt, List<ControlTowerAttentionItem> items
  ) {
    return new ControlTowerAttentionResponse(SCHEMA_NAME, SCHEMA_VERSION, source, generatedAt, items);
  }
}
