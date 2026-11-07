package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineScheduleSaveRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineScheduleListResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineScheduleResponse;
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
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

/// 요일별 반복 일과 API 문서 (#782, #1080)
@Tag(name = "요일별 반복 일과", description = "일과관리 원본에 요일·시각을 정해 그날 자동으로 오늘 일과를 만들고 이룸이 기기에 알림 (보호자만, 저장은 Pro)")
public interface RoutineScheduleDocs {

  @Operation(
    summary = "주간 계획 조회",
    description = """
      이 이룸이의 반복 일과 전부를 시각 순으로 줍니다. 지운 원본의 예약은 빠집니다.

      - `paused`: 저장한 보호자의 요금제가 이 기능을 쓰지 못하면 true. 예약은 지우지 않고 멈춥니다.
      - `canSchedule`: 요청한 보호자가 새로 정하거나 바꿀 수 있는가.
      - `elumiNotification`: NO_DEVICE(연결된 이룸이 기기 없음) · OFF(연결됐지만 알림 토큰 없음) · ON.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = RoutineScheduleListResponse.class)))
  })
  ResponseEntity<RoutineScheduleListResponse> getSchedules(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "요일·시각 저장",
    description = """
      일과관리 원본 하나에 반복 요일과 시각을 정합니다. 이미 있으면 덮어씁니다 (저장한 보호자가 예약 주인).

      - 그 요일에는 오늘 일과 조회 때(또는 정한 시각에) 원본 카드로 오늘 일과가 만들어집니다. 이미 보냈으면 만들지 않습니다.
      - `notifyEnabled` 가 true 면 정한 시각에 이룸이 기기에 알림이 갑니다. 이미 끝낸 일과는 보내지 않습니다.
      - 요금제 권한(ROUTINE_SCHEDULE)이 없으면 403, 요일 0개·시각 형식이 틀리면 400, 원본이 아니면 409.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "저장 성공",
      content = @Content(schema = @Schema(implementation = RoutineScheduleResponse.class))),
    @ApiResponse(responseCode = "403", description = "요금제 권한 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(value = "{\"errorCode\":\"ROUTINE_SCHEDULE_NOT_ALLOWED\",\"errorMessage\":\"요일별 반복 일과는 Pro에서 쓸 수 있어요.\"}"))),
    @ApiResponse(responseCode = "400", description = "요일·시각이 틀림",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(value = "{\"errorCode\":\"ROUTINE_SCHEDULE_INVALID\",\"errorMessage\":\"요일을 하나 이상 고르고 시각을 다시 정해 주세요.\"}")))
  })
  ResponseEntity<RoutineScheduleResponse> save(Authentication authentication, String routineId,
    RoutineScheduleSaveRequest request);

  @Operation(
    summary = "요일·시각 끄기",
    description = "반복을 끕니다. 요금제와 무관하게 언제나 됩니다. 이미 만든 오늘 일과는 그대로 둡니다. 예약이 없어도 204."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "끔")
  })
  ResponseEntity<Void> delete(Authentication authentication, String routineId);
}
