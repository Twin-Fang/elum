package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "일과관리 칸 순서 저장 요청 (#844). 낱개 일과와 묶음을 한 줄로 세운 차례")
public record RoutineLibraryOrderRequest(

  @Schema(description = "보호자가 보는 모든 칸의 새 차례(낱개 원본 + 묶음). 이 차례가 0부터의 자리가 된다. "
    + "빠뜨린 칸은 목록 뒤에 기존 순서대로 붙는다. 없는 ID·남의 이룸이 칸·묶음 안 일과·중복은 400")
  List<Cell> cells
) {

  @Schema(description = "칸 하나")
  public record Cell(
    @Schema(description = "칸 종류. ROUTINE 낱개 원본, GROUP 묶음", example = "ROUTINE") CellType type,
    @Schema(description = "일과 ID 또는 묶음 ID", example = "routine-1") String id
  ) {

  }

  /// 칸 종류: ROUTINE 묶음 밖 낱개 원본, GROUP 묶음
  public enum CellType {
    ROUTINE,
    GROUP
  }
}
