package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "일과 진행 상태 일괄 반영 요청 (오프라인 퍼스트 동기화)")
public record RoutineProgressSyncRequest(

  @Schema(
    description = "완료 상태여야 하는 단계 id 전체 집합. 여기 없는 단계는 미완료로 되돌린다. 비우면 전부 미완료.",
    example = "[\"step-1\", \"step-2\"]"
  )
  List<String> completedStepIds
) {

  // 본문이 비어 오면(null) 빈 집합으로 본다 — 클라이언트가 전부 해제한 상태를 보낸 것과 같다.
  public List<String> completedStepIdsOrEmpty() {
    return completedStepIds == null ? List.of() : completedStepIds;
  }
}
