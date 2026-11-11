package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.multipart.MultipartFile;

/**
 * 보호자 목소리 녹음 API 문서 (#787): 올리기, 지우기, 받기
 * RoutineStepAudioController 에 제공 (Swagger 묶음은 RoutineControllerDocs 와 같음)
 */
@Tag(name = RoutineControllerDocs.TAG_NAME, description = RoutineControllerDocs.TAG_DESCRIPTION)
public interface RoutineStepVoiceDocs {

  @Operation(
    summary = "카드 보호자 목소리 올리기 (Pro)",
    description = """
      보호자가 카드 한 장을 자기 목소리로 녹음해 올립니다. 이룸이 기기는 이 녹음을 기본 음성보다 먼저 틉니다.

      - **Pro(GUARDIAN_VOICE) 만** 올릴 수 있습니다. 아니면 403 `GUARDIAN_VOICE_NOT_ALLOWED`.
      - 형식은 바이트로 판정합니다: MP4/M4A(AAC) 만. 1MB 이하, 15초 이하.
      - 올릴 때마다 새 열쇠가 생기고 옛 녹음은 다른 카드가 안 가리키면 지웁니다.
      - 일과를 만든 보호자만 올릴 수 있습니다(이룸이 기기 불가).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "올린 뒤 카드 (guardianVoicePath 가 새 열쇠)"),
    @ApiResponse(
      responseCode = "400",
      description = "형식이 아니거나 1MB·15초 초과, 파일 누락",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"GUARDIAN_VOICE_TOO_LONG\",\"errorMessage\":\"녹음은 15초까지 할 수 있어요. 조금 짧게 다시 녹음해 주세요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "403",
      description = "Pro 가 아님, 또는 일과를 만든 보호자가 아님(이룸이 포함)",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"GUARDIAN_VOICE_NOT_ALLOWED\",\"errorMessage\":\"보호자 목소리 녹음은 Pro에서 쓸 수 있어요.\"}"
        )
      )
    ),
    @ApiResponse(responseCode = "404", description = "존재하지 않는 일과 또는 단계"),
    @ApiResponse(responseCode = "500", description = "녹음 저장 실패 (GUARDIAN_VOICE_SAVE_FAILED)")
  })
  ResponseEntity<RoutineStepResponse> uploadStepVoice(
    Authentication authentication,
    @Parameter(description = "일과 ID") String routineId,
    @Parameter(description = "카드 ID") String stepId,
    @Parameter(description = "녹음 파일 (필드명 voice, m4a, 1MB·15초 이하)") MultipartFile voice
  );

  @Operation(
    summary = "카드 보호자 목소리 지우기",
    description = """
      카드의 녹음을 지웁니다. **요금제와 상관없이** 언제나 지울 수 있습니다(Pro 가 끝나도).
      녹음이 없어도 성공합니다. 파일은 다른 카드(복제한 일과)가 안 가리키면 커밋 뒤 지웁니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "지운 뒤 카드 (guardianVoicePath null)"),
    @ApiResponse(responseCode = "403", description = "일과를 만든 보호자가 아님(이룸이 포함)"),
    @ApiResponse(responseCode = "404", description = "존재하지 않는 일과 또는 단계")
  })
  ResponseEntity<RoutineStepResponse> deleteStepVoice(
    Authentication authentication,
    @Parameter(description = "일과 ID") String routineId,
    @Parameter(description = "카드 ID") String stepId
  );

  @Operation(
    summary = "카드 보호자 목소리 받기",
    description = """
      카드 녹음(audio/mp4)을 받습니다. ETag = 녹음 열쇠, 같은 값을 If-None-Match 로 보내면 304.

      - 보호자 기기: 녹음이 있으면 언제나 받습니다(미리 듣기).
      - 이룸이 기기: **녹음한 보호자가 지금 Pro 일 때만** 받습니다. 아니면 404 — 앱은 기본 음성으로 읽습니다.
      - 녹음이 없으면 404.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "녹음 (audio/mp4)"),
    @ApiResponse(responseCode = "304", description = "가진 녹음과 같음"),
    @ApiResponse(responseCode = "404", description = "녹음 없음 또는 이룸이 기기에서 재생 불가(Pro 아님)")
  })
  ResponseEntity<byte[]> getStepVoice(
    Authentication authentication,
    @Parameter(description = "일과 ID") String routineId,
    @Parameter(description = "카드 ID") String stepId,
    @Parameter(description = "가진 녹음 열쇠(ETag)") String ifNoneMatch
  );
}
