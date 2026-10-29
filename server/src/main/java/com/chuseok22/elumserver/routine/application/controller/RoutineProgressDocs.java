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
 * 일과 진행 API 문서: 진행 동기화
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
      - **순서를 검사하지 않습니다.** 오프라인에서 쌓인 변경을 한 번에 반영하기 위한 것입니다.
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
}
