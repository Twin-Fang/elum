package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

/**
 * 온보딩 예시 일과 생성 요청 (#803). 분류 코드 검증은 서비스가 한다 (빈 목록·모르는 코드 > 400)
 */
@Schema(description = "온보딩 예시 일과 생성 요청")
public record RoutineExampleCreateRequest(

  @Schema(description = "고른 분류 코드 (MORNING_EVENING · SCHOOL_STUDY · HOUSE_SELF · OUTSIDE)",
    example = "[\"MORNING_EVENING\", \"SCHOOL_STUDY\"]", requiredMode = Schema.RequiredMode.REQUIRED)
  List<String> categories
) {

}
