package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

/**
 * 일과 단계 편집 API 문서: 추가, 수정, 삭제 (카드 그림 바꾸기·새로 그리기는 RoutineStepImageDocs)
 * RoutineControllerDocs 가 묶어서 RoutineController 에 제공
 */
public interface RoutineStepEditDocs {

  @Operation(
    summary = "일과 카드 추가",
    description = """
      보호자가 카드를 한 장 직접 추가합니다. 카드는 **맨 뒤**에 붙고 stepOrder는 1..N으로 정규화됩니다.

      **그림은 `generateImage: true` 일 때만 만듭니다 (#407).** 빼거나 false 면 그림 없이 카드만 추가합니다.
      크레딧이 켜져 있으면 그림 1장 단가를 예약하고(초과 허용 없음), 모자라거나 계정이 멈춰 있으면 **카드는 추가하고**
      응답 `imageSkippedReason`에 `AI_CREDIT_INSUFFICIENT`(또는 `AI_CREDIT_ACCOUNT_FROZEN`)를 담습니다.
      요금제에 AI 맞춤 그림이 없으면(Free · `FREE_AI_IMAGE_GENERATION` 꺼짐) 예약 없이 카드만 추가하고 `AI_IMAGE_NOT_ALLOWED`를 담습니다(픽토그램).
      그림이 카드에 붙으면 차감하고, 비용 상한·횟수 제한·생성 실패·카드 삭제로 못 붙이면 예약을 돌려줍니다.
      장부 오류면 503 `AI_CREDIT_UNAVAILABLE`로 카드 추가도 실패합니다.

      **그림은 AI가 만들지만 응답을 기다리지 않습니다.** 이미지 생성은 몇 초 걸리므로
      카드를 먼저 만들어 응답하고, 그림은 커밋 뒤 백그라운드에서 채웁니다.
      따라서 이 응답의 `imagePath`는 **거의 항상 null**입니다.
      클라이언트는 2~3초 뒤 일과를 다시 조회해 채워졌는지 확인하고,
      그 동안 "그림 만드는 중"을 보여 주세요 (#198 §9).

      **그림이 실패해도 카드 추가는 성공합니다.** `imagePath`가 null로 남으며
      클라이언트가 기본 그림으로 채웁니다. 자동 재시도는 하지 않습니다(카드당 1회).

      그림체는 그 일과 프로필의 캐릭터를 그대로 넘기므로 기존 카드들과 맞습니다.

      **모든 상태에서 추가할 수 있습니다** (PENDING_REVIEW · CONFIRMED · COMPLETED).
      COMPLETED였던 일과에 카드를 더하면 "전부 완료"가 깨지므로 CONFIRMED로 되돌아갑니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "추가 성공 (imagePath는 아직 null)",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "400",
      description = "제목이 비었거나 100자 초과 · 설명 300자 초과",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
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
      responseCode = "503",
      description = "그림을 요청했는데 크레딧 장부를 읽지 못함 — 카드도 추가하지 않는다",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"AI_CREDIT_UNAVAILABLE\",\"errorMessage\":\"잠시 뒤에 다시 시도해주세요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "카드가 이미 10장",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_MAX_COUNT\",\"errorMessage\":\"카드는 10장까지 만들 수 있어요.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> addStep(
    Authentication authentication, String routineId, RoutineStepCreateRequest request
  );

  @Operation(
    summary = "일과 단계 수정 · 순서 변경",
    description = """
      보호자가 카드의 title, description, stepOrder를 직접 수정합니다. AI를 다시 호출하지 않고 입력한 텍스트를 그대로 저장합니다.

      **보낸 필드만 바뀝니다.** 순서만 옮길 때는 stepOrder만 보내면 제목·설명은 그대로 남습니다.

      stepOrder를 보내면 카드를 그 자리로 옮기고 나머지를 1..N으로 다시 채워 응답합니다.
      범위를 벗어난 값은 끝으로 붙입니다(400을 던지지 않습니다).

      **모든 상태에서 수정할 수 있습니다** (PENDING_REVIEW · CONFIRMED · COMPLETED).
      이룸이에게 보낸 뒤에도 고칠 수 있어야 한다는 전문가 자문 요구에 따른 것입니다 (이슈 #199).
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
      responseCode = "400",
      description = "제목 100자 초과 · 설명 300자 초과 · stepOrder가 1 미만",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    )
  })
  ResponseEntity<RoutineResponse> updateStep(
    Authentication authentication, String routineId, String stepId, RoutineStepUpdateRequest request
  );

  @Operation(
    summary = "일과 단계 삭제",
    description = """
      카드 한 장을 삭제합니다. 삭제 후 남은 카드들의 순서(stepOrder)는 1부터 다시 채번됩니다.
      카드가 1장만 남은 경우 삭제할 수 없습니다.

      **모든 상태에서 삭제할 수 있습니다** (PENDING_REVIEW · CONFIRMED · COMPLETED) — 이슈 #199.

      **이미 완료한 카드를 지우면 그 별도 함께 회수됩니다.** 별은 "완료한 카드 수"를 따라가므로,
      카드가 사라졌는데 별만 남으면 이룸이 화면의 별 개수를 설명할 수 없습니다.
      또 마지막 미완료 카드를 지워 전부 완료가 되면 일과가 COMPLETED로 바뀝니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "삭제 성공",
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
      description = "PENDING_REVIEW 상태가 아니거나, 마지막 남은 한 장을 삭제하려는 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_MIN_COUNT\",\"errorMessage\":\"마지막 남은 단계는 삭제할 수 없어요.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> deleteStep(Authentication authentication, String routineId, String stepId);
}
