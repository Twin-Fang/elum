package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineProgressSyncRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

/**
 * 일과 진행 API 문서: 진행 동기화, 단계 완료·취소
 * RoutineControllerDocs 가 묶어서 RoutineController 에 제공
 */
public interface RoutineProgressDocs {

  @Operation(
    summary = "일과 진행 상태 일괄 반영 (오프라인 퍼스트 동기화)",
    description = """
      아동 모드가 기기에 저장해 둔 "완료 단계 집합"을 통째로 받아 서버 상태를 그대로 맞춥니다.

      **처리 로직**
      1. 본인 소유 일과인지, CONFIRMED/COMPLETED 상태인지 확인합니다.
      2. 집합에 이 일과의 단계가 아닌 id가 있으면 404를 반환합니다.
      3. 집합에 있는 단계는 완료, 없는 단계는 미완료로 맞춥니다. 처음 완료되는 단계에만 완료 시각을 찍습니다.
      4. 별(totalStars)은 완료 수의 **차이만큼만** 움직입니다. 같은 요청을 여러 번 보내도 결과가 같습니다(멱등).
      5. 전부 완료면 COMPLETED, 아니면 CONFIRMED로 상태를 맞춥니다.

      **주의사항**
      - 단계별 완료 API와 달리 **순서를 검사하지 않습니다.** 오프라인에서 쌓인 변경을 한 번에 반영하기 위한 것입니다.
      - 화면 표시는 클라이언트 로컬 저장소가 진실이고, 이 API는 서버를 따라오게 만드는 용도입니다.
      """
  )
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "반영 성공. 반영 후 일과 전체 상태를 반환합니다.",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "403",
      description = "본인 소유가 아닌 일과에 접근",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "404",
      description = "존재하지 않는 일과이거나, 집합에 이 일과의 단계가 아닌 id가 섞인 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계예요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "보호자 승인 전(PENDING_REVIEW) 일과",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_INVALID_STATUS\",\"errorMessage\":\"지금 상태에서는 처리할 수 없어요.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> syncProgress(
    Authentication authentication, String routineId, RoutineProgressSyncRequest request
  );

  @Operation(
    summary = "일과 단계 완료",
    description = """
      CONFIRMED 상태 일과의 단계를 하나 완료 처리하고 즉시 별(star) 1개를 지급합니다.

      **처리 로직**
      1. 일과가 CONFIRMED 상태가 아니면 409를 반환합니다.
      2. stepId가 해당 일과 소속이 아니면 404를 반환합니다.
      3. 이미 완료된 단계면 409를 반환합니다.
      4. 현재 미완료 단계 중 stepOrder가 가장 작은 단계가 아니면(순서 위반) 409를 반환합니다.
      5. 완료 처리 후 보호자(Member)의 누적 별(totalStars)을 1 증가시킵니다.
      6. 이 완료로 모든 단계가 완료됐다면 일과 상태를 COMPLETED로 전환합니다.

      실수로 완료한 경우 `PATCH /api/routines/{routineId}/steps/{stepId}/cancel` API로 취소할 수 있습니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "완료 처리 성공",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "403",
      description = "본인 소유가 아닌 일과에 접근",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "404",
      description = "존재하지 않는 일과 또는 단계",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계예요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "CONFIRMED 상태가 아니거나, 이미 완료된 단계이거나, 순서를 위반한 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_ORDER_VIOLATION\",\"errorMessage\":\"이전 단계를 먼저 완료해 주세요.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> completeStep(
    Authentication authentication, String routineId, String stepId
  );

  @Operation(
    summary = "일과 단계 완료 취소",
    description = """
      완료된 단계 중 가장 최근에 완료한 단계(stepOrder가 가장 큰 완료 단계)의 완료를 취소하고, 지급됐던 별(star) 1개를 회수합니다.

      **처리 로직**
      1. 일과가 CONFIRMED 또는 COMPLETED 상태가 아니면 409를 반환합니다.
      2. stepId가 해당 일과 소속이 아니면 404를 반환합니다.
      3. 아직 완료되지 않은 단계면 409를 반환합니다.
      4. 완료된 단계 중 stepOrder가 가장 큰 단계가 아니면(취소 순서 위반) 409를 반환합니다.
      5. 취소 처리 후 보호자(Member)의 누적 별(totalStars)을 1 감소시킵니다.
      6. 취소 전 일과가 COMPLETED 상태였다면 CONFIRMED로 되돌리고 completedAt을 null로 초기화합니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "취소 처리 성공",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "403",
      description = "본인 소유가 아닌 일과에 접근",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "404",
      description = "존재하지 않는 일과 또는 단계",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계예요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "CONFIRMED/COMPLETED 상태가 아니거나, 미완료 단계이거나, 가장 최근 완료 단계가 아닌 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_CANCEL_ORDER_VIOLATION\",\"errorMessage\":\"가장 최근에 완료한 단계만 취소할 수 있어요.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> cancelStep(
    Authentication authentication, String routineId, String stepId
  );
}
