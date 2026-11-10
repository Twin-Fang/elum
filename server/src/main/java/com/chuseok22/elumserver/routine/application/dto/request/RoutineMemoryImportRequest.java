package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "AI 메모리 가져오기: 내보내기와 같은 모양")
public record RoutineMemoryImportRequest(
  @Schema(example = "elum.routine-memory.v1") String schema,
  List<ImportedRule> rules
) {

  /// type·status·source 는 글자로 받아 모르는 값 한 건만 버림 (파일 전체를 400 으로 막지 않음)
  public record ImportedRule(String type, String status, String source, String summary, String before, String after) {

  }
}
