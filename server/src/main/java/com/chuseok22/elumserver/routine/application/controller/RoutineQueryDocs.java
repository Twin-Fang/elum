package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.enums.ParameterIn;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

/**
 * 일과 조회 API 문서: 단건, 내 목록, 오늘, 추천, 단계 그림
 * RoutineControllerDocs 가 묶어서 RoutineController 에 제공
 */
public interface RoutineQueryDocs {

  @Operation(summary = "일과 단건 조회", description = "본인 소유의 일과를 steps 포함해 조회합니다.")
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "조회 성공",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "403",
      description = "본인 소유가 아닌 일과에 접근",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_ACCESS_DENIED\",\"errorMessage\":\"해당 일과에 접근할 권한이 없습니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "404",
      description = "존재하지 않는 일과",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 일과입니다.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> getRoutine(Authentication authentication, String routineId);

  @Operation(summary = "내 일과 목록 조회", description = "인증된 본인이 소유한 모든 일과를 조회합니다.")
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공")
  })
  ResponseEntity<List<RoutineResponse>> getMyRoutines(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "오늘의 일과 목록 조회",
    description = """
      아이 홈 화면에 노출할 "오늘 할 일" 목록입니다. scheduledAt이 오늘(KST) 범위에 속하면서
      상태가 CONFIRMED 또는 COMPLETED인 일과만 예정 시각(scheduledAt) 오름차순으로 반환합니다.
      보호자 승인 전(PENDING_REVIEW) 일과는 포함되지 않습니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공")
  })
  ResponseEntity<List<RoutineResponse>> getTodayRoutines(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "추천 일과 목록 조회",
    description = """
      하드코딩된 50개 추천 일과 중 무작위 count개(아이콘 + 문구 + 자연어 예시)를 반환합니다. 보호자별 개인화는 하지 않습니다.
      count는 생략하면 4이며, 1 이상 전체 카탈로그 개수(현재 50개) 이하여야 합니다. 범위를 벗어나면 400을 반환합니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공"),
    @ApiResponse(
      responseCode = "400",
      description = "count가 1 미만이거나 전체 카탈로그 개수를 초과",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"입력값이 올바르지 않습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<List<RoutineSuggestionResponse>> getSuggestions(int count);

  @Operation(
    summary = "일과 단계 이미지 조회",
    description = "본인 소유 일과의 특정 단계에 생성된 이미지를 바이너리로 반환합니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공(이미지 바이너리)"),
    @ApiResponse(
      responseCode = "403",
      description = "본인 소유가 아닌 일과에 접근",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "404",
      description = "존재하지 않는 일과/단계이거나 이미지 파일을 찾을 수 없음",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_IMAGE_NOT_FOUND\",\"errorMessage\":\"이미지를 찾을 수 없습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<byte[]> getStepImage(Authentication authentication, String routineId, String stepId);
}
