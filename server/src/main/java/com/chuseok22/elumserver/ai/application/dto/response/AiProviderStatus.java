package com.chuseok22.elumserver.ai.application.dto.response;

import com.chuseok22.elumserver.ai.core.AiFailureKind;
import com.chuseok22.elumserver.ai.core.AiProviderHealth;
import java.time.LocalDateTime;

/**
 * 제공자 한 줄(제공자 × 글/그림) 상태: 판정, 최근 60분 호출·성공·평균 지연, 마지막 성공·실패
 * 마지막 성공·실패는 최근 24시간 안에서만 (없으면 null)
 */
public record AiProviderStatus(
  String laneLabel,
  AiProviderHealth health,
  long windowCallCount,
  long windowSuccessCount,
  long windowAverageLatencyMilliseconds,
  LocalDateTime lastSuccessAt,
  LocalDateTime lastFailureAt,
  AiFailureKind lastFailureKind,
  String lastFailureSummary
) {
}
