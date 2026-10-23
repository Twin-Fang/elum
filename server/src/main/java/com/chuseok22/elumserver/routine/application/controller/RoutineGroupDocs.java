package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineGroupCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineGroupNameUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineGroupRoutinesUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineGroupResponse;
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
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

/**
 * 일과관리 묶음 API 문서: 목록, 만들기, 이름·구성 바꾸기, 풀기, 복사하기, 묶음째 보내기 (#806)
 */
@Tag(name = "일과관리 묶음", description = "일과관리 원본 일과를 폴더처럼 모은 묶음 (보호자만)")
public interface RoutineGroupDocs {

  @Operation(
    summary = "묶음 목록 조회",
    description = """
      이룸이의 일과관리 묶음을 묶음 순서(`displayOrder`) → 만든 차례로 돌려줍니다.

      - `routineIds` 는 묶음 안 차례대로이고 이룸이가 보는 순서입니다. 항상 1개 이상입니다.
      - 묶음에 든 일과도 `GET /api/routines/library` 에 그대로 나옵니다. 앱이 이 목록으로 폴더를 짭니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<List<RoutineGroupResponse>> getGroups(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "묶음 만들기",
    description = """
      원본 일과 1개 이상을 받은 차례대로 새 묶음에 넣습니다. 새 묶음은 묶음 목록 맨 뒤에 붙습니다.

      - 이름은 앞뒤 공백을 지운 뒤 1~12자. 아니면 400(`INVALID_INPUT_VALUE`). 빈 ID·중복 ID도 400(`INVALID_INPUT_VALUE`).
      - 일과가 없으면 400(`ROUTINE_GROUP_TOO_SMALL`).
      - 넣을 수 있는 일과는 이 이룸이의 **일과관리 원본**뿐입니다 — 보내기로 만든 일과, 일과관리에서 지운 일과,
        임시저장, 다른 이룸이 일과는 400(`ROUTINE_GROUP_INVALID_MEMBER`).
      - 일과는 한 묶음에만 듭니다. 다른 묶음에 있던 일과는 옮겨 오고, 그 묶음이 비면 풀립니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "묶음을 만듦",
      content = @Content(schema = @Schema(implementation = RoutineGroupResponse.class))),
    @ApiResponse(responseCode = "400", description = "이름이 맞지 않음 / 일과 없음 / 넣을 수 없는 일과",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_GROUP_TOO_SMALL\",\"errorMessage\":\"묶음에는 일과를 1개 이상 넣어 주세요.\"}")))
  })
  ResponseEntity<RoutineGroupResponse> create(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineGroupCreateRequest request
  );

  @Operation(
    summary = "묶음 이름 바꾸기",
    description = """
      묶음 이름만 바꿉니다. 앞뒤 공백을 지운 뒤 1~12자, 아니면 400(`INVALID_INPUT_VALUE`).

      - 이미 묶음째 보낸 오늘 일과의 묶음 이름(`sentGroupName`)은 그대로입니다.
      - 없는 묶음·다른 이룸이 묶음은 404(`ROUTINE_GROUP_NOT_FOUND`).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<RoutineGroupResponse> rename(
    Authentication authentication, String groupId, RoutineGroupNameUpdateRequest request
  );

  @Operation(
    summary = "묶음 구성 바꾸기",
    description = """
      묶음의 구성과 차례를 한 번에 바꿉니다 (넣기·빼기·순서 바꾸기).

      - 목록에서 빠진 일과는 묶음에서 나갑니다 (일과는 그대로).
      - 비어 있으면 400(`ROUTINE_GROUP_TOO_SMALL`). 묶음을 풀려면 `DELETE` 를 부릅니다.
      - 일과 조건과 다른 묶음에서 옮겨 오는 규칙은 묶음 만들기와 같습니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<RoutineGroupResponse> replaceRoutines(
    Authentication authentication, String groupId, RoutineGroupRoutinesUpdateRequest request
  );

  @Operation(
    summary = "묶음 풀기",
    description = """
      묶음을 지웁니다. **일과는 지우지 않고** 묶음에서만 뺍니다.
      없는 묶음·다른 이룸이 묶음은 404(`ROUTINE_GROUP_NOT_FOUND`).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<Void> delete(Authentication authentication, String groupId);

  @Operation(
    summary = "묶음 복사하기",
    description = """
      묶음의 일과를 하나씩 일과관리에 복사하고(**AI 호출 없음**) 같은 차례로 새 묶음에 넣습니다.

      - 새 묶음 이름은 `묶음 이름 복사` (12자를 넘으면 원래 이름 쪽을 자릅니다). 묶음 목록 맨 뒤에 붙습니다.
      - 복사한 일과는 일과관리 `복사하기`와 같고(일과관리에만 있고 홈에 뜨지 않음), 제목은 원래 제목 그대로입니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  ResponseEntity<RoutineGroupResponse> copy(Authentication authentication, String groupId);

  @Operation(
    summary = "묶음째 보내기",
    description = """
      묶음의 일과를 차례대로 **오늘 일과**로 만듭니다. 일과마다 일과관리 `보내기`와 같습니다(**AI 호출 없음**).

      - 만든 일과에는 `sentGroupId`·`sentGroupName`(보낸 때 이름)·`sentGroupOrder`(묶음 안 자리, 0부터)가 들어갑니다.
        이룸이 홈은 이 값으로 묶음 상자를 그립니다.
      - 오늘 이미 보낸 일과는 건너뜁니다(오류 아님). 하나도 보내지 못했으면 409(`ROUTINE_ALREADY_SENT_TODAY`).
      - 응답은 이번에 만든 오늘 일과 목록(묶음 차례대로)입니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "오늘 일과를 만듦"),
    @ApiResponse(responseCode = "409", description = "묶음의 일과를 모두 오늘 이미 보냄",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_ALREADY_SENT_TODAY\",\"errorMessage\":\"오늘 이미 보낸 일과예요.\"}")))
  })
  ResponseEntity<List<RoutineResponse>> send(Authentication authentication, String groupId);
}
