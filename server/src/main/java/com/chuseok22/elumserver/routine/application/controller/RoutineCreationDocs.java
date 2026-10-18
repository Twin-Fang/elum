package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
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
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

/**
 * 일과 생성 API 문서: 일과 생성, AI 추가 질문
 * RoutineControllerDocs 가 묶어서 RoutineController 에 제공
 */
public interface RoutineCreationDocs {

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

      **AI 크레딧 (#407)**
      - `Idempotency-Key` 헤더를 보내세요. `카드 만들기`를 새로 누를 때 새 키, 실패 뒤 `다시 하기`는 같은 키입니다.
        빼면 서버가 요청마다 새 키를 만듭니다(구버전 앱 호환 — 멱등 없음).
      - 검사 순서: 쿨다운(429) → (크레딧 꺼짐이면 하루·주간 횟수) → 보유 일과 수 → 서비스 하루 비용 상한 → 이룸이 접근 → 크레딧 예약.
      - 같은 키가 이미 끝났으면 AI를 다시 부르지 않고 저장된 일과를 돌려줍니다(이때 `credit`은 null).
        같은 키가 아직 만드는 중이면 409 `AI_CREDIT_JOB_IN_PROGRESS`.
      - 사용 가능 < 일과 글 단가면 403 `AI_CREDIT_INSUFFICIENT`, 멈춘 계정은 403 `AI_CREDIT_ACCOUNT_FROZEN`,
        장부 오류는 503 `AI_CREDIT_UNAVAILABLE`.
      - 시작한 일과는 끝까지 만듭니다. 청구 = 글 단가 + 그림 단가 × 붙은 그림 수, 잔액이 모자란 몫은 빚으로 남기지 않습니다.
        응답 `credit`에 카드 수·그림 수·차감량·남은 양이 담깁니다(크레딧 꺼짐이면 null).
      - 생성·저장이 실패하면 예약을 돌려줍니다.

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
      responseCode = "403",
      description = "이번 주 크레딧 부족(AI_CREDIT_INSUFFICIENT) 또는 멈춘 계정(AI_CREDIT_ACCOUNT_FROZEN)",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"AI_CREDIT_INSUFFICIENT\",\"errorMessage\":\"이번 주 크레딧을 모두 사용했어요. 월요일 0시에 다시 채워져요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "같은 Idempotency-Key 작업이 아직 진행 중",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"AI_CREDIT_JOB_IN_PROGRESS\",\"errorMessage\":\"이미 만들고 있어요. 잠시 뒤에 확인해주세요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "503",
      description = "크레딧 장부를 읽지 못함(fail-closed)",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"AI_CREDIT_UNAVAILABLE\",\"errorMessage\":\"잠시 뒤에 다시 시도해주세요.\"}"
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
  ResponseEntity<RoutineResponse> create(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    @Parameter(in = ParameterIn.HEADER, name = "Idempotency-Key",
      description = "생성 요청 멱등 키(255자 이하). 같은 키로 다시 보내면 AI를 다시 부르지 않는다. 빼면 서버가 만든다")
    String idempotencyKey,
    RoutineCreateRequest request
  );

  @Operation(
    summary = "AI 추가 질문 생성",
    description = """
      보호자가 선택한 도움 목표(PREPARE_ITEMS/PREPARE_NEW)가 있을 때만 일과 생성 전에 확인할 질문을 만듭니다.
      선택한 도움 목표마다 정확히 하나씩 질문이 생성되므로 questions 배열의 길이는 항상 선택한 목표 수와 같습니다
      (Gemini 응답 중 일부만 무효여도 그 목표만 고정 질문으로 대체되어 개수가 줄어들지 않습니다).
      두 목표를 모두 선택하지 않았다면 required:false와 빈 questions를 반환하며, 이 경우 곧바로 POST /api/routines를 호출하면 됩니다.
      required:true면 questions 각각의 question/options를 사용자에게 순서대로 보여주고, 선택한 옵션의 label 값을 questions 순서 그대로
      POST /api/routines의 answers 필드(문자열 배열)로 전달하세요. options 각 항목은 emoji/label 쌍이며, 직접 입력 항목은 제공하지 않습니다.
      이 API는 아무것도 저장하지 않으며(Stateless), Gemini 호출이 실패해도 선택한 목표별 고정 질문으로 대체해 200을 반환합니다.

      **AI 크레딧 (#407)**: 차감은 없지만 크레딧이 켜져 있고 사용 가능 < 일과 글 단가면 AI를 부르기 전에
      403 `AI_CREDIT_INSUFFICIENT`(멈춘 계정은 403 `AI_CREDIT_ACCOUNT_FROZEN`, 장부 오류는 503 `AI_CREDIT_UNAVAILABLE`)로 막습니다.
      도움 목표와 무관하게 봅니다 — 다음 단계인 일과 생성에서 같은 이유로 막히기 때문입니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "403",
      description = "이번 주 크레딧 부족 또는 멈춘 계정",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"AI_CREDIT_INSUFFICIENT\",\"errorMessage\":\"이번 주 크레딧을 모두 사용했어요. 월요일 0시에 다시 채워져요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "200",
      description = "생성 성공(required:false 포함, AI 실패여도 200)",
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
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineQuestionRequest request
  );
}
