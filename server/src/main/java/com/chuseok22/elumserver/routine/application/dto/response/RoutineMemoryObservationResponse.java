package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "방금 고쳐서 보낸 일과에서 찾은 수정 (앱이 '다음에도 이렇게 할까요?'를 띄움)")
public record RoutineMemoryObservationResponse(

  @Schema(description = "PENDING 아직 찾는 중 · READY 찾음 · NONE 고친 게 없거나 대상이 아님")
  Status status,

  @Schema(description = "찾은 수정. READY 일 때만 있음")
  List<Item> items
) {

  public enum Status {
    PENDING,
    READY,
    NONE
  }

  public static RoutineMemoryObservationResponse of(Status status) {
    return new RoutineMemoryObservationResponse(status, List.of());
  }

  public record Item(
    String ruleId, RoutineMemoryRuleType type, String summary,
    @Schema(nullable = true) String before, @Schema(nullable = true) String after,
    @Schema(description = "이 규칙이 관찰된 서로 다른 일과 수 (이번 일과 포함)") int evidenceCount,
    RoutineMemoryRuleStatus ruleStatus
  ) {

  }
}
