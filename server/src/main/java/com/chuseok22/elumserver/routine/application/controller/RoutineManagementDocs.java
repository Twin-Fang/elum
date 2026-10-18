package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RewardUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineReorderRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepReorderRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RecentRewardResponse;
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
 * 일과 관리 API 문서: 확정, 순서, 보상, 최근 보상, 지난·임시 목록, 복제, 삭제
 * RoutineControllerDocs 가 묶어서 RoutineController 에 제공
 */
public interface RoutineManagementDocs {

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
    summary = "일과 순서 변경",
    description = """
      홈 목록에 보이는 일과 순서를 바꿉니다.

      **화면에 보이는 전체를 차례대로 보냅니다.** 일부만 보내 부분 갱신하는 방식이 아닙니다 —
      부분 갱신은 두 곳에서 동시에 순서를 바꿀 때 뒤엉킵니다.

      - 보낸 차례대로 1부터 번호가 붙습니다. 앞에 있을수록 위입니다.
      - 하나라도 남의 일과이거나 없는 일과가 섞이면 **아무것도 바꾸지 않고** 거부합니다.
        절반만 반영되면 화면과 서버의 순서가 어긋나 더 나쁩니다.
      - 같은 ID가 두 번 오면 거부합니다.
      - 빈 목록은 아무 일도 하지 않고 성공으로 답합니다.
      - 그사이 일과가 늘거나 줄었으면 409(ROUTINE_ORDER_CONFLICT) — 목록을 다시 받아 보냅니다.
      """
  )
  ResponseEntity<Void> reorder(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineReorderRequest request
  );

  @Operation(
    summary = "행동 단계 순서 변경",
    description = """
      일과 안의 행동 단계 순서를 바꿉니다.

      **일과 순서 변경(`PATCH /api/routines/order`)과 같은 방식입니다.**
      화면에 보이는 단계 전체를 차례대로 보냅니다.

      - 보낸 차례대로 1부터 번호가 붙습니다. 앞에 있을수록 먼저 하는 단계입니다.
      - **일부만 보내면 거부합니다.** 빠진 단계의 차례를 알 수 없기 때문입니다.
      - 없는 단계나 다른 일과의 단계가 섞이면 **아무것도 바꾸지 않고** 거부합니다.
        절반만 반영되면 보호자가 본 순서와 이룸이 화면의 순서가 어긋나 더 나쁩니다.
      - 같은 ID가 두 번 오면 거부합니다.
      - 빈 목록은 아무 일도 하지 않고 성공으로 답합니다.
      """
  )
  ResponseEntity<Void> reorderSteps(
    Authentication authentication, String routineId, RoutineStepReorderRequest request
  );

  @Operation(
    summary = "보상(강화물) 수정",
    description = """
      일과에 설정된 보상을 바꾸거나 해제합니다.

      보상은 **보호자가 정하고 앱은 보여주기만 합니다.** 실제로 주는 사람은 보호자입니다.
      일과를 만든 뒤에도 바꿀 수 있어야 보호자가 관리한다고 할 수 있어 별도 엔드포인트로 둡니다.

      - `rewardText`와 `rewardPresetKey`를 모두 비우면 보상이 해제되고, 아동 화면에서 보상 UI가 사라집니다.
      - 정의되지 않은 프리셋 키는 무시하고 null로 저장합니다. 잘못된 키 때문에 요청이 실패하지 않습니다.
      - 100자를 넘으면 서버에서 잘라 저장합니다.
      """
  )
  ResponseEntity<RoutineResponse> updateReward(
    Authentication authentication, String routineId, RewardUpdateRequest request
  );

  @Operation(
    summary = "최근 사용한 보상 조회",
    description = """
      보상 설정 화면 입력칸 아래에 띄울 **최근에 정한 보상 최대 4개**를 최신순으로 돌려줍니다.
      같은 보상이 여러 일과에 쓰였으면 하나로 합칩니다.

      보상을 한 번도 설정하지 않았으면 빈 배열이 내려갑니다. 이때 화면에서는 **섹션 자체를 숨깁니다.**
      """
  )
  ResponseEntity<List<RecentRewardResponse>> getRecentRewards(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "지난 일과 목록 조회",
    description = """
      `scheduledAt`이 **오늘 이전**인 일과를 최신순 10개까지 돌려줍니다. 보호자 홈의 접힌 `지난 일과` 섹션용입니다.

      **이룸이에게 보낸 일과(`CONFIRMED`·`COMPLETED`)만** 담습니다. 임시저장(`PENDING_REVIEW`)은
      빠집니다 — 오늘 만들다 둔 임시저장이 다음 날 지난 일과에 뜨지 않게 합니다. 오늘 일과와 같은 기준입니다.

      완료된 일과를 삭제하지 않는 이유는 **수행률 추이의 원본 데이터**이기 때문입니다.
      보이지 않게 접어둘 뿐 지우지 않습니다.
      """
  )
  ResponseEntity<List<RoutineResponse>> getPastRoutines(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "임시저장 일과 목록 조회",
    description = """
      아직 승인하지 않은(`PENDING_REVIEW`) 일과를 최신순으로 돌려줍니다.

      카드를 만들었지만 `아이 화면으로 시작하기`를 누르지 않은 상태이며, **아이 화면에는 보이지 않습니다.**
      보호자 홈에서는 `[임시저장]` 배지로 표시하고, 탭하면 카드 검토 화면으로 이어집니다.
      """
  )
  ResponseEntity<List<RoutineResponse>> getDraftRoutines(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "일과 복제 (다시 하기)",
    description = """
      기존 일과의 카드를 그대로 복사해 **오늘 일과**를 하나 더 만듭니다. **AI를 호출하지 않습니다.**

      **동작**
      - `title`·단계(제목/설명/이미지)·보상을 복사합니다.
      - 상태는 `CONFIRMED`, `scheduledAt`은 오늘 09:00입니다. 이미 검토를 거친 카드라 다시 승인받지 않습니다.
      - 모든 단계의 완료 상태는 초기화됩니다.
      - 원문(`rawInputText`)은 복사하지 않습니다. 원문을 계속 보관하지 않는다는 원칙을 따릅니다.

      매일 같은 준비를 하는 경우 AI 호출 없이 탭 한 번으로 오늘 일과가 만들어집니다.
      """
  )
  ResponseEntity<RoutineResponse> duplicate(Authentication authentication, String routineId);

  @Operation(
    summary = "임시저장 일과 삭제",
    description = """
      **`PENDING_REVIEW` 상태의 일과만** 삭제합니다. 그 외 상태는 `ROUTINE_INVALID_STATUS`로 거절합니다.

      승인된 일과를 지우지 않는 이유는 수행률 기록의 원본이기 때문입니다.
      카드 검토 화면에서 나갈 때 뜨는 팝업의 `삭제하기`가 이 엔드포인트를 호출합니다.
      """
  )
  ResponseEntity<Void> delete(Authentication authentication, String routineId);
}
