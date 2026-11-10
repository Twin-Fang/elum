package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import java.util.List;

@Schema(description = "AI 메모리 내보내기. 이룸이 이름·회원 식별값·근거 일과 제목은 넣지 않는다")
public record RoutineMemoryExportResponse(
  @Schema(example = "elum.routine-memory.v1") String schema,
  OffsetDateTime exportedAt,
  List<ExportedRule> rules
) {

  public static final String SCHEMA = "elum.routine-memory.v1";

  public record ExportedRule(
    RoutineMemoryRuleType type, RoutineMemoryRuleStatus status, RoutineMemoryRuleSource source, String summary,
    @Schema(nullable = true) String before, @Schema(nullable = true) String after
  ) {

  }
}
