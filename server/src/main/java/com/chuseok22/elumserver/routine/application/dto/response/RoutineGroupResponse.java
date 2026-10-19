package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineGroup;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "일과관리 묶음 응답 (#806)")
public record RoutineGroupResponse(

  @Schema(description = "묶음 ID")
  String id,

  @Schema(description = "묶음 이름 (1~12자)", example = "아침 묶음")
  String name,

  @Schema(description = "일과관리에서 묶음끼리의 순서. 작을수록 앞", example = "0")
  int displayOrder,

  @Schema(description = "묶음의 원본 일과 ID, 묶음 안 차례대로 (이룸이가 보는 순서). 항상 2개 이상",
    example = "[\"routine-1\", \"routine-2\"]")
  List<String> routineIds
) {

  /// 묶음 + 구성원 ID(차례대로) > 응답
  public static RoutineGroupResponse of(RoutineGroup group, List<String> routineIds) {
    return new RoutineGroupResponse(group.getId(), group.getName(),
      group.getDisplayOrder() == null ? 0 : group.getDisplayOrder(), List.copyOf(routineIds));
  }
}
