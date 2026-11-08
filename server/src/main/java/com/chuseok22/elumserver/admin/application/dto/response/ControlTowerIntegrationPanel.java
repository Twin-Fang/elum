package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDateTime;

/**
 * 시스템 설정 "관제소 연동" 칸: 켜짐 여부, 토큰 설정 여부(값은 싣지 않음), 마지막 수집 시각, 지금 내보내는 항목 미리보기
 * lastCollectedAt: 이 서버가 시작된 뒤 토큰 검사를 통과한 마지막 요청 (없으면 null)
 * preview: 미리보기 집계 실패 시 null (previewFailureMessage 에 사유)
 */
public record ControlTowerIntegrationPanel(
  boolean isEnabled,
  boolean isTokenConfigured,
  boolean hasHttpsAdminBaseUrl,
  LocalDateTime lastCollectedAt,
  ControlTowerAttentionResponse preview,
  String previewFailureMessage
) {
}
