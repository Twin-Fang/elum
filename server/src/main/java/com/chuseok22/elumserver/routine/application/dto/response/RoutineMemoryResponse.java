package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.routine.core.RoutineMemoryLine;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import java.util.List;

@Schema(description = "이룸이별 AI 메모 (#1082)")
public record RoutineMemoryResponse(

  @Schema(description = "이 계정이 AI 메모를 쓸 수 있는가 (Pro). false 면 나머지는 비어 있다")
  boolean available,

  @Schema(description = "켜짐 여부. 메모를 아직 만들지 않았으면 true (기본 켜짐)")
  boolean enabled,

  @Schema(description = "메모 줄 (최대 10줄, 보호자가 쓴 줄 먼저)")
  List<LineResponse> lines,

  @Schema(description = "마지막으로 AI 가 메모를 고친 시각. 아직 없으면 null")
  LocalDateTime lastBuiltAt
) {

  public static RoutineMemoryResponse unavailable() {
    return new RoutineMemoryResponse(false, false, List.of(), null);
  }

  @Schema(description = "메모 한 줄")
  public record LineResponse(
    @Schema(description = "문장", example = "'씻기' 대신 '손 닦기'라고 써요") String text,
    @Schema(description = "AI: 고친 카드에서 AI 가 정리 / GUARDIAN: 보호자가 쓰거나 고침") RoutineMemoryLine.Source source
  ) {

  }
}
