package com.chuseok22.elumserver.admin.application.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * 관제소 스냅샷 출처: 앱 이름, 앱 버전, 환경(production / development), 관리자 화면 기준 주소(https 만, 없으면 생략)
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ControlTowerAttentionSource(
  String app,
  @JsonProperty("app_version") String appVersion,
  String environment,
  @JsonProperty("admin_base_url") String adminBaseUrl
) {
}
