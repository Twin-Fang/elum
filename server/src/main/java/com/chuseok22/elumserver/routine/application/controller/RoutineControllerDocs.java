package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.routine.application.dto.request.RewardUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineProgressSyncRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RecentRewardResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
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
  description = "부모 자연어 입력 기반 일과(Routine) 생성/검토/승인/단계 완료/단계 수정/단계 삭제/AI 추가 질문 API. 모든 엔드포인트는 accessToken(Bearer) 인증이 필요합니다."
)
public interface RoutineControllerDocs {

  @Operation(
    summary = "일과 생성",
    description = """
      부모가 입력한 자연어 일과를 받아 동기적으로 AI 파이프라인(로컬 LLM 마스킹 → Gemini 단계 세분화 → 단계별 이미지 생성)을 거쳐 PENDING_REVIEW 상태의 일과를 생성합니다.

      **처리 로직**
      1. 로컬 LLM 게이트로 원문의 민감정보를 마스킹합니다(마스킹 실패 시 fail-open으로 원문 그대로 진행).
      2. 마스킹된 텍스트를 Gemini에 전달해 제목과 최대 10단계의 설명을 생성합니다.
      3. 단계별로 Gemini 이미지 생성을 병렬 호출합니다. 한 단계가 일시적으로 실패하면 그
      단계만 1회 재시도하며, 재시도까지 실패하면 전체 요청이 실패합니다.
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
      선택한 도움 목표마다 정확히 하나씩 질문이 생성되므로 questions 배열의 길이는 항상 선택한 목표 수와 같습니다
      (Gemini 응답 중 일부만 무효여도 그 목표만 고정 질문으로 대체되어 개수가 줄어들지 않습니다).
      두 목표를 모두 선택하지 않았다면 required:false와 빈 questions를 반환하며, 이 경우 곧바로 POST /api/routines를 호출하면 됩니다.
      required:true면 questions 각각의 question/options를 사용자에게 순서대로 보여주고, 선택한 옵션의 label 값을 questions 순서 그대로
      POST /api/routines의 answers 필드(문자열 배열)로 전달하세요. options 각 항목은 emoji/label 쌍이며, 직접 입력 항목은 제공하지 않습니다.
      이 API는 아무것도 저장하지 않으며(Stateless), Gemini 호출이 실패해도 선택한 목표별 고정 질문으로 대체해 항상 200을 반환합니다.
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
  ResponseEntity<List<RoutineResponse>> getTodayRoutines(Authentication authentication);

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
      보상 설정 화면 상단에 띄울 **최근에 정한 보상 최대 3개**를 최신순으로 돌려줍니다.
      같은 보상이 여러 일과에 쓰였으면 하나로 합칩니다.

      보상을 한 번도 설정하지 않았으면 빈 배열이 내려갑니다. 이때 화면에서는 **섹션 자체를 숨깁니다.**
      """
  )
  ResponseEntity<List<RecentRewardResponse>> getRecentRewards(Authentication authentication);

  @Operation(
    summary = "지난 일과 목록 조회",
    description = """
      `scheduledAt`이 **오늘 이전**인 일과를 최신순 10개까지 돌려줍니다. 보호자 홈의 접힌 `지난 일과` 섹션용입니다.

      완료된 일과를 삭제하지 않는 이유는 **수행률 추이의 원본 데이터**이기 때문입니다.
      보이지 않게 접어둘 뿐 지우지 않습니다.
      """
  )
  ResponseEntity<List<RoutineResponse>> getPastRoutines(Authentication authentication);

  @Operation(
    summary = "임시저장 일과 목록 조회",
    description = """
      아직 승인하지 않은(`PENDING_REVIEW`) 일과를 최신순으로 돌려줍니다.

      카드를 만들었지만 `아이 화면으로 시작하기`를 누르지 않은 상태이며, **아이 화면에는 보이지 않습니다.**
      보호자 홈에서는 `[임시저장]` 배지로 표시하고, 탭하면 카드 검토 화면으로 이어집니다.
      """
  )
  ResponseEntity<List<RoutineResponse>> getDraftRoutines(Authentication authentication);

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
      - 단계별 완료 API와 달리 **순서를 검사하지 않습니다.** 오프라인에서 쌓인 변경을 한 번에 반영하기 위한 것입니다.
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
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "보호자 승인 전(PENDING_REVIEW) 일과",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_INVALID_STATUS\",\"errorMessage\":\"현재 상태에서는 처리할 수 없습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> syncProgress(
    Authentication authentication, String routineId, RoutineProgressSyncRequest request
  );

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
    summary = "일과 단계 수정",
    description = """
      보호자가 AI가 생성한 단계의 title과 description을 직접 수정합니다. AI를 다시 호출하지 않고 입력한 텍스트를 그대로 저장합니다.
      PENDING_REVIEW 상태의 일과에서만 수정할 수 있습니다. 승인(CONFIRMED) 이후에는 409를 반환합니다.
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
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계입니다.\"}"
        )
      )
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
  ResponseEntity<RoutineResponse> updateStep(
    Authentication authentication, String routineId, String stepId, RoutineStepUpdateRequest request
  );

  @Operation(
    summary = "일과 단계 삭제",
    description = """
      PENDING_REVIEW 상태 일과에서 카드 한 장을 삭제합니다. 삭제 후 남은 카드들의 순서(stepOrder)는 1부터 다시 채번됩니다.
      카드가 1장만 남은 경우 삭제할 수 없습니다.
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
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "PENDING_REVIEW 상태가 아니거나, 마지막 남은 한 장을 삭제하려는 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_MIN_COUNT\",\"errorMessage\":\"마지막 남은 단계는 삭제할 수 없습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> deleteStep(Authentication authentication, String routineId, String stepId);
}
