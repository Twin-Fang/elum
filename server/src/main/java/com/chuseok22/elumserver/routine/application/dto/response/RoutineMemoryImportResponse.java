package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "AI 메모리 가져오기 결과")
public record RoutineMemoryImportResponse(
  @Schema(description = "새로 넣은 규칙 수") int importedCount,
  @Schema(description = "같은 규칙이 이미 있어 건너뛴 수") int duplicateCount,
  @Schema(description = "필터·형식에 걸려 버린 수") int rejectedCount
) {

}
