package com.chuseok22.elumserver.expertroutine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineImportRequest;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineDetailResponse;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineImportResponse;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineSummaryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.ArraySchema;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "ExpertRoutine",
  description = "전문가 일과: 관리자가 검수한 일과를 크레딧 없이 일과관리로 가져오는 API. 보호자 accessToken(Bearer) 인증이 필요하며 "
    + "이룸이 권한으로는 부를 수 없습니다. 프로필 헤더(X-Profile-Id)는 필요 없습니다."
)
public interface ExpertRoutineControllerDocs {

  @Operation(
    summary = "전문가 일과 목록",
    description = """
      공개되고 검수를 마친 전문가 일과를 관리자가 정한 순서대로 돌려줍니다. 요금제와 상관없이 볼 수 있습니다.

      **조건**
      1. `language` 를 비우면 요청의 `Accept-Language` 언어, 값이 있으면 그 언어(ko·en·ja·zh·es)의 일과만 나옵니다. 모르는 값이면 요청 언어로 봅니다.
      2. `category` 를 비우면 전체, 값이 있으면 6개 분류 중 하나여야 합니다. 모르는 값이면 400 `INVALID_INPUT_VALUE`.
      3. 그 언어의 일과가 없으면 빈 배열입니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(array = @ArraySchema(schema = @Schema(implementation = ExpertRoutineSummaryResponse.class)))),
    @ApiResponse(responseCode = "400", description = "모르는 분류(INVALID_INPUT_VALUE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<List<ExpertRoutineSummaryResponse>> getList(
    @Parameter(description = "분류. 비우면 전체") String category,
    @Parameter(description = "언어 코드. 비우면 요청 언어") String language
  );

  @Operation(
    summary = "전문가 일과 미리 보기",
    description = "카드 전부를 순서대로 돌려줍니다. 내렸거나 없는 일과는 404 `EXPERT_ROUTINE_NOT_FOUND`."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = ExpertRoutineDetailResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "내렸거나 없는 일과(EXPERT_ROUTINE_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<ExpertRoutineDetailResponse> getDetail(@Parameter(description = "전문가 일과 id") String expertRoutineId);

  @Operation(
    summary = "전문가 일과 가져오기",
    description = """
      전문가 일과를 이룸이의 일과관리에 원본 일과로 복사합니다. AI 를 부르지 않아 크레딧이 들지 않습니다.

      **동작**
      1. `ROUTINE_TEMPLATES` 권한이 없으면(Free) 403 `EXPERT_ROUTINE_PRO_ONLY`.
      2. 카드 문장·픽토그램·예시 이미지·보상 제안이 그대로 들어가고, 일과 언어는 전문가 일과의 언어입니다.
      3. `groupId` 가 없으면 일과관리 맨 앞, 있으면 그 묶음 맨 뒤에 들어갑니다.
      4. 가져간 일과는 보호자의 원본이라 고치거나 이야기·링크로 나눌 수 있습니다. 원본 전문가 일과를 고쳐도 바뀌지 않습니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "가져오기 성공",
      content = @Content(schema = @Schema(implementation = ExpertRoutineImportResponse.class))),
    @ApiResponse(responseCode = "400", description = "이룸이 id 없음 또는 이 이룸이의 묶음이 아님(INVALID_INPUT_VALUE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "Free 요금제(EXPERT_ROUTINE_PRO_ONLY) 또는 연결 없는 이룸이(PROFILE_ACCESS_DENIED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "내렸거나 없는 일과(EXPERT_ROUTINE_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<ExpertRoutineImportResponse> importToLibrary(
    Authentication authentication,
    @Parameter(description = "전문가 일과 id") String expertRoutineId,
    ExpertRoutineImportRequest request
  );
}
