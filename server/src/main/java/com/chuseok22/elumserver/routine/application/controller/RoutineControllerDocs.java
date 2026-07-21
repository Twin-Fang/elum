package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineReviseRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "Routine",
  description = "부모 자연어 입력 기반 일과(Routine) 생성/검토/승인/단계 완료/단계 수정/AI 추가 질문 API. 모든 엔드포인트는 accessToken(Bearer) 인증이 필요합니다."
)
public interface RoutineControllerDocs {

  @Operation(
    summary = "일과 생성",
    description = """
      부모가 입력한 자연어 일과를 받아 동기적으로 AI 파이프라인(로컬 LLM 마스킹 → Gemini 단계 세분화 → 단계별 이미지 생성)을 거쳐 PENDING_REVIEW 상태의 일과를 생성합니다.

      **처리 로직**
      1. 로컬 LLM 게이트로 원문의 민감정보를 마스킹합니다(마스킹 실패 시 fail-open으로 원문 그대로 진행).
      2. 마스킹된 텍스트를 Gemini에 전달해 제목과 최대 10단계의 설명을 생성합니다.
      3. 단계별로 Gemini 이미지 생성을 병렬 호출합니다. 하나라도 실패하면 전체 요청이 실패합니다.
      4. 모든 단계가 성공적으로 생성된 뒤에만 일과를 저장합니다.

      **주의**: AI 파이프라인 특성상 응답까지 수십 초가 걸릴 수 있습니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "생성 성공",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "400",
      description = "rawInputText/scheduledAt 누락 등 입력값 오류",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"rawInputText: rawInputText는 필수입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "502",
      description = "Gemini 텍스트/이미지 생성 실패 또는 10단계 초과",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_AI_GENERATION_FAILED\",\"errorMessage\":\"AI 생성 처리에 실패했습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> create(Authentication authentication, RoutineCreateRequest request);

  @Operation(
    summary = "AI 추가 질문 생성",
    description = """
      보호자가 선택한 도움 목표(PREPARE_ITEMS/PREPARE_NEW)가 있을 때만 일과 생성 전에 확인할 질문을 만듭니다.
      두 목표를 모두 선택하지 않았다면 required:false를 반환하며, 이 경우 곧바로 POST /api/routines를 호출하면 됩니다.
      required:true면 question/options를 사용자에게 보여주고, 선택/직접입력한 값을 POST /api/routines의 answers 필드로 전달하세요.
      이 API는 아무것도 저장하지 않으며(Stateless), Gemini 호출이 실패해도 고정 질문으로 대체해 항상 200을 반환합니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "생성 성공(required:false 포함 항상 200)",
      content = @Content(schema = @Schema(implementation = RoutineQuestionResponse.class))
    ),
    @ApiResponse(
      responseCode = "400",
      description = "rawInputText 누락",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"rawInputText: rawInputText는 필수입니다.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineQuestionResponse> generateQuestion(
    Authentication authentication, RoutineQuestionRequest request
  );

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
  ResponseEntity<List<RoutineResponse>> getMyRoutines(Authentication authentication);

  @Operation(
    summary = "일과 재생성(피드백)",
    description = """
      부모의 자연어 피드백을 받아 기존 단계+피드백을 컨텍스트로 AI 파이프라인을 다시 실행합니다.
      기존 단계는 전부 교체되며, CONFIRMED 상태였더라도 다시 PENDING_REVIEW로 전환됩니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "재생성 성공",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "403",
      description = "본인 소유가 아닌 일과에 접근",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "404",
      description = "존재하지 않는 일과",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "502",
      description = "Gemini 생성 실패 또는 10단계 초과",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    )
  })
  ResponseEntity<RoutineResponse> revise(
    Authentication authentication, String routineId, RoutineReviseRequest request
  );

  @Operation(
    summary = "일과 승인",
    description = "PENDING_REVIEW 상태의 일과를 CONFIRMED로 확정합니다. PENDING_REVIEW가 아닌 상태(이미 CONFIRMED이거나 COMPLETED)면 409를 반환합니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "승인 성공",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "409",
      description = "PENDING_REVIEW 상태가 아님",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_INVALID_STATUS\",\"errorMessage\":\"현재 상태에서는 처리할 수 없습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> confirm(Authentication authentication, String routineId);

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
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "CONFIRMED 상태가 아니거나, 이미 완료된 단계이거나, 순서를 위반한 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_ORDER_VIOLATION\",\"errorMessage\":\"이전 단계를 먼저 완료해야 합니다.\"}"
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
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "CONFIRMED/COMPLETED 상태가 아니거나, 미완료 단계이거나, 가장 최근 완료 단계가 아닌 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_CANCEL_ORDER_VIOLATION\",\"errorMessage\":\"가장 최근에 완료한 단계만 취소할 수 있습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> cancelStep(
    Authentication authentication, String routineId, String stepId
  );

  @Operation(
    summary = "일과 단계 설명 수정",
    description = """
      보호자가 AI가 생성한 단계 설명 문구를 직접 수정합니다. AI를 다시 호출하지 않고 입력한 텍스트를 그대로 저장합니다.
      PENDING_REVIEW/CONFIRMED/COMPLETED 등 일과 상태와 무관하게 항상 수정할 수 있으며, 완료(completed) 여부는 변경되지 않습니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "수정 성공",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "400",
      description = "description 누락",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"description: description은 필수입니다.\"}"
        )
      )
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
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계입니다.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> updateStepDescription(
    Authentication authentication, String routineId, String stepId, RoutineStepUpdateRequest request
  );
}
