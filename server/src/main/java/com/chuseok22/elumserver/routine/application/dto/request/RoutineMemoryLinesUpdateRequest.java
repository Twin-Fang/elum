package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "AI 메모 줄 통째로 바꾸기 (#1082). 화면에 보이는 전체를 그대로 보낸다 — 고친 줄·지운 줄이 반영된 목록")
public record RoutineMemoryLinesUpdateRequest(

  @Schema(description = "메모 줄 (최대 10줄, 한 줄 60자). 빈 줄은 버린다. 진단·장애·정도 표현은 400 ROUTINE_MEMORY_LINE_NOT_ALLOWED",
    example = "[\"'씻기' 대신 '손 닦기'라고 써요\", \"옷 입기는 상의·하의·양말로 나눠요\"]")
  List<String> lines
) {

}
