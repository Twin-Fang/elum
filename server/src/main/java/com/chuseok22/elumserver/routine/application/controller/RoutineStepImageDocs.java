package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepImageCandidateApplyRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepImageRedrawRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepImageCandidateResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
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
 * 카드 AI 그림 새로 그리기 API 문서: 그리기(후보), 후보 받기, 새 그림으로 바꾸기, 원래 그림 그대로
 * RoutineControllerDocs 가 묶어서 RoutineController 에 제공
 */
public interface RoutineStepImageDocs {

  @Operation(
    summary = "카드 AI 그림 다시 그리기 · AI 그림 그리기 (후보 만들기)",
    description = """
      카드 그림을 새로 그려 **후보**로 둡니다. 카드 그림(`imagePath`)은 바뀌지 않고, 보호자가 원래 그림과 나란히 보고 고르면
      `POST .../image/candidate/apply` 로 바꿉니다. 응답이 올 때까지 수 초 걸립니다(그림 생성을 기다림).

      **요금제**: AI 맞춤 그림 권한(`entitlements.aiImageGeneration`)이 없으면 403 `AI_IMAGE_NOT_ALLOWED` (크레딧 예약 전).

      **대상**: `aiPicture=true` 인 카드(다시 그리기) 또는 그림이 없는 카드(`imagePath=null`, 처음 그리기 — 픽토그램 카드).
      보호자 사진·이야기에서 가져온 그림·설명 없는 카드·직접 사진 방식 이룸이는 409 입니다.

      **요청 본문(선택)**: `requestText`(고치고 싶은 점, 60자 이하 — 넘으면 400 `INVALID_INPUT_VALUE`), `hints`(칩:
      `SIMPLER` · `NO_BACKGROUND` · `NO_PEOPLE` · `BRIGHTER`). 그림 지시문에 보호자 요청으로 덧붙습니다. 비우면 같은 조건으로 다시 그립니다.

      **크레딧**: 다시 그리기는 `IMAGE_REGENERATE`(Pro 하루 무료 한도 안이면 0, `freeImageRegeneratesLeftToday`),
      처음 그리기는 카드 그림 단가 `CARD_IMAGE`(무료 한도에 넣지 않음). 후보를 저장하면 정산하고(원래 그림을 골라도 돌려주지 않음),
      실패하면 예약을 돌려줍니다.

      **응답**: `candidateImagePath`(고를 때 그대로 보냄), `isFirstPicture`. 다시 그리면 이전 후보는 지워집니다.

      **권한**: 카드 수정과 같습니다. 일과를 만든 보호자만 가능하고 이룸이는 403 입니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "후보를 만들었음 (카드 그림은 그대로)"),
    @ApiResponse(
      responseCode = "400",
      description = "요청 글이 60자를 넘음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "403",
      description = "AI 맞춤 그림 없는 요금제, 크레딧 부족·동결, 일과를 만든 보호자가 아님",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"AI_IMAGE_NOT_ALLOWED\",\"errorMessage\":\"AI 맞춤 그림은 Pro 에서 쓸 수 있어요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "404",
      description = "존재하지 않는 일과 또는 단계",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "409",
      description = "새로 그릴 수 없는 카드, 또는 그리는 사이 그림이 바뀜",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_IMAGE_NOT_REGENERATABLE\",\"errorMessage\":\"이 카드는 그림을 다시 그릴 수 없어요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "429",
      description = "그림 요청이 너무 잦음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "503",
      description = "그림 생성 실패 또는 서비스 하루 비용 상한 (크레딧은 돌려줌)",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_IMAGE_REGENERATE_FAILED\",\"errorMessage\":\"그림을 다시 그리지 못했어요. 크레딧은 쓰지 않았어요. 잠시 후 다시 해 주세요.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineStepImageCandidateResponse> regenerateStepImage(
    Authentication authentication,
    @Parameter(description = "일과 ID") String routineId,
    @Parameter(description = "카드 ID") String stepId,
    RoutineStepImageRedrawRequest request
  );

  @Operation(
    summary = "새 그림 후보 받기",
    description = """
      고르기 전 새 그림 후보의 이미지 바이트를 줍니다. 후보가 없으면(이미 골랐거나 버림) 404 `ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND`.
      일과를 만든 보호자만 받을 수 있습니다(이룸이 403).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "이미지 바이트 (image/png 등)"),
    @ApiResponse(
      responseCode = "404",
      description = "후보 없음",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND\",\"errorMessage\":\"새 그림을 찾을 수 없어요. 다시 그려 주세요.\"}"
        )
      )
    )
  })
  ResponseEntity<byte[]> getStepImageCandidate(
    Authentication authentication,
    @Parameter(description = "일과 ID") String routineId,
    @Parameter(description = "카드 ID") String stepId
  );

  @Operation(
    summary = "새 그림으로 바꾸기",
    description = """
      후보를 카드 그림으로 바꿉니다. `candidateImagePath` 가 지금 후보와 다르면(다시 그려 바뀜·이미 고름) 404 이고 카드 그림은 그대로입니다.

      **응답**: 바뀐 카드(`RoutineStepResponse`). `imagePath` 가 새 값이라 이미지 캐시를 갱신하세요. 옛 AI 그림 파일은 정리합니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "바꿈"),
    @ApiResponse(
      responseCode = "404",
      description = "후보 없음·다른 후보",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    )
  })
  ResponseEntity<RoutineStepResponse> applyStepImageCandidate(
    Authentication authentication,
    @Parameter(description = "일과 ID") String routineId,
    @Parameter(description = "카드 ID") String stepId,
    RoutineStepImageCandidateApplyRequest request
  );

  @Operation(
    summary = "원래 그림 그대로 (후보 버리기)",
    description = "후보를 지웁니다. 카드 그림은 그대로이고 크레딧은 돌려주지 않습니다(그림은 이미 그림). 후보가 없어도 204 입니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "버림")
  })
  ResponseEntity<Void> discardStepImageCandidate(
    Authentication authentication,
    @Parameter(description = "일과 ID") String routineId,
    @Parameter(description = "카드 ID") String stepId
  );
}
