package com.chuseok22.elumserver.ai.application.dto.response;

import java.util.List;

/** AI 상태 한 벌: 제공자별 상태 + 최근 24시간 실패 묶음 (건수 많은 순) */
public record AiHealthSnapshot(List<AiProviderStatus> providerStatuses, List<AiFailureCount> failureCounts) {

  /** 확인할 일로 올릴 제공자 수 */
  public long alertCount() {
    return providerStatuses.stream().filter(status -> status.health().isAlert()).count();
  }
}
