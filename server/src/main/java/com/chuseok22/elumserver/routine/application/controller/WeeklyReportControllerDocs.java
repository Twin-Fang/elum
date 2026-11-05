package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.enums.ParameterIn;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.LocalDate;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

/**
 * 주간 리포트 API 문서 (#1074). Swagger 묶음은 RoutineControllerDocs 와 같음
 */
@Tag(name = RoutineControllerDocs.TAG_NAME, description = RoutineControllerDocs.TAG_DESCRIPTION)
public interface WeeklyReportControllerDocs {

  @Operation(
    summary = "주간 리포트 조회 (#1074, Pro)",
    description = """
      이룸이 한 명의 한 주(월요일 0시 ~ 다음 월요일 0시, 서버 시간대 Asia/Seoul) 요약입니다.
      그 주 `scheduledAt` 에 보낸 일과(CONFIRMED·COMPLETED, 일과관리 복사본 제외)의 완료 기록만 셉니다.

      - `weekStart` 는 그 주 아무 날이어도 됩니다. 월요일로 맞춥니다. 없으면 이번 주입니다.
      - 기록이 없는 주는 200 + `sentRoutineCount = 0` 입니다 (앱이 빈 상태를 띄웁니다).
      - 원문·보상 문구·평가 문구는 싣지 않습니다.
      - 보호자 기기 전용입니다. 이룸이 기기 토큰은 403 `DEVICE_LINK_FORBIDDEN_FOR_ELUMI`.

      **403**: 요금제 권한 `WEEKLY_REPORT` 꺼짐 (`WEEKLY_REPORT_NOT_ALLOWED`)
      **400**: 이번 주보다 뒤의 주 (`INVALID_INPUT_VALUE`)
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "조회 성공",
      content = @Content(schema = @Schema(implementation = WeeklyReportResponse.class))
    ),
    @ApiResponse(
      responseCode = "403",
      description = "요금제에 주간 리포트가 없음",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"WEEKLY_REPORT_NOT_ALLOWED\",\"errorMessage\":\"주간 리포트는 Pro 요금제에서 볼 수 있어요.\"}"
        )
      )
    )
  })
  ResponseEntity<WeeklyReportResponse> getWeeklyReport(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    @Parameter(description = "그 주 아무 날 (yyyy-MM-dd). 없으면 이번 주", example = "2026-11-02") LocalDate weekStart
  );
}
