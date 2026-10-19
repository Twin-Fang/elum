package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineLibraryOrderRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineTitleUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
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
 * 일과관리 API 문서: 목록, 보내기, 복사하기, 지우기, 제목 수정 (#804)
 * RoutineControllerDocs 가 묶어서 RoutineController 에 제공
 */
public interface RoutineLibraryDocs {

  @Operation(
    summary = "일과관리 목록 조회",
    description = """
      보호자 `일과관리` 탭에 보일 **원본 일과**를 칸 순서(`libraryOrder` 오름차순, 없으면 맨 뒤) 다음 최신순으로 돌려줍니다.

      - 보낸 상태(`CONFIRMED`·`COMPLETED`)만 담습니다. 임시저장(`PENDING_REVIEW`)은 빠집니다.
      - `보내기`로 만든 일과(`sourceRoutineId` 가 있는 일과)는 빠집니다. 같은 일과가 날마다 쌓이지 않게 합니다.
      - 일과관리에서 지운 일과는 빠집니다.
      - `복사하기`로 만든 일과는 **여기에만** 있고 홈 목록(오늘·지난·전체)에는 뜨지 않습니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<List<RoutineResponse>> getLibraryRoutines(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "일과관리 칸 순서 저장",
    description = """
      낱개 일과와 묶음을 **한 줄**로 세운 차례를 저장합니다 (보호자만). 받은 차례가 0부터의 자리가 되어
      낱개는 `libraryOrder`, 묶음은 `displayOrder` 에 같은 번호 공간으로 저장됩니다.

      - 요청은 `{"cells":[{"type":"ROUTINE","id":"..."},{"type":"GROUP","id":"..."}]}` 입니다.
      - 빠뜨린 칸은 받은 칸 뒤에 기존 순서(묶음 먼저)대로 붙습니다. 아무것도 지우지 않습니다.
      - 없는 ID·남의 이룸이 칸·묶음 안 일과·지운 일과는 400(`ROUTINE_GROUP_INVALID_MEMBER`).
      - 종류·ID가 비었거나 같은 칸이 두 번이면 400(`INVALID_INPUT_VALUE`).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<Void> reorderLibrary(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineLibraryOrderRequest request
  );

  @Operation(
    summary = "일과관리 보내기",
    description = """
      원본 일과의 카드를 그대로 복사해 **오늘 일과**를 만듭니다. **AI를 호출하지 않습니다.**
      카드 복사 방식은 `일과 복제(다시 하기)`와 같고, 새 일과의 `sourceRoutineId` 에 원본 ID가 들어갑니다.

      - 원본 하나는 **하루 한 번** 보냅니다. 원본이 이미 오늘 일과이거나 오늘 보낸 일과가 있으면 409(`ROUTINE_ALREADY_SENT_TODAY`).
      - 원본이 아닌 일과(`sourceRoutineId` 가 있는 일과)나 임시저장은 409(`ROUTINE_INVALID_STATUS`).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "오늘 일과를 만듦",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "409",
      description = "오늘 이미 보냄 / 원본이 아님",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_ALREADY_SENT_TODAY\",\"errorMessage\":\"오늘 이미 보낸 일과예요.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> send(Authentication authentication, String routineId);

  @Operation(
    summary = "일과관리 복사하기",
    description = """
      원본 일과의 카드를 복사해 **새 원본**을 일과관리에 만듭니다. **AI를 호출하지 않습니다.**

      - 제목은 `원본 제목 복사` 입니다 (일과 언어를 따르고, 100자를 넘으면 원본 제목 쪽을 자릅니다).
      - 상태는 `CONFIRMED`, `sourceRoutineId` 는 null 입니다.
      - **일과관리에만 있고 보호자·이룸이 홈에는 뜨지 않습니다.** 고친 뒤 `보내기`로 오늘 일과를 만듭니다.
      - 원본이 아닌 일과나 임시저장은 409(`ROUTINE_INVALID_STATUS`).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<RoutineResponse> copy(Authentication authentication, String routineId);

  @Operation(
    summary = "일과관리에서 지우기",
    description = """
      일과관리 목록에서 일과를 뺍니다. **만든 사람만** 할 수 있습니다 (그 밖은 403 `ROUTINE_NOT_CREATOR`).

      - 보통은 **목록에서만 숨깁니다.** 완료 기록과 이 원본으로 보낸 일과는 그대로 남습니다.
      - `복사하기`로 만든 일과이고 완료한 단계도, 이 일과로 보낸 일과도 없으면 일과를 지웁니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<Void> removeFromLibrary(Authentication authentication, String routineId);

  @Operation(
    summary = "일과 제목 수정",
    description = """
      일과 제목만 바꿉니다. **만든 사람만** 할 수 있습니다 (그 밖은 403 `ROUTINE_NOT_CREATOR`).

      - 앞뒤 공백을 지운 뒤 1~30자여야 합니다. 비었거나 길면 400(`INVALID_INPUT_VALUE`).
      - 이 일과만 바뀝니다. 이 원본으로 이미 보낸 일과의 제목은 그대로입니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<RoutineResponse> updateTitle(
    Authentication authentication, String routineId, RoutineTitleUpdateRequest request
  );
}
