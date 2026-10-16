package com.chuseok22.elumserver.credit.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.credit.application.dto.response.CreditHistoryResponse;
import com.chuseok22.elumserver.credit.application.dto.response.CreditSummaryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "Credit",
  description = "주간 AI 크레딧 조회 API (#407). 보호자 accessToken(Bearer) 인증이 필요합니다."
)
public interface CreditControllerDocs {

  @Operation(
    summary = "내 AI 크레딧 조회",
    description = """
      이번 주 AI 크레딧 요약을 돌려줍니다. 보호자 설정 화면의 크레딧 카드와 홈의 "일과 만들기" 막기에 씁니다.

      **처리 로직**
      1. 계정이 없으면 만들고, 이번 주(한국 시각 월요일 0시 시작) 주간 지급이 없으면 지급합니다.
      2. 예약 유지 시간을 넘긴 진행 중 예약은 풀어 돌려줍니다.
      3. 사용 가능 = 유효한 적립의 남은 양 − 진행 중 예약. `bonus`는 주간이 아닌 적립의 남은 양,
         `used`는 이번 주기에 실제로 차감한 양입니다.
      4. `canStartRoutine` = 사용 가능 ≥ 일과 글 단가이고 멈춘 계정이 아님. `canGenerateImage`는 그림 단가로 같은 판정.
      5. `nextResetAt`은 시간대가 없는 서버 시각(한국 시각)이고, `nextResetAtOffset`은 같은 순간에 오프셋을 붙인 값입니다
         (예 `2026-09-28T00:00:00+09:00`). 앱은 `nextResetAtOffset`을 기기 시간대로 바꿔 보여줍니다 (#421).
         `canStartRoutine`에는 진행 중 작업이 들어가지 않습니다 — 진행 중인 일과 만들기는 `inProgress`로 판단합니다.

      **크레딧이 꺼져 있으면** `enabled=false`, 숫자는 0, 시각은 null, `canStartRoutine`·`canGenerateImage`는 true 입니다.
      앱은 카드를 숨기고 아무것도 막지 않습니다.

      **장부를 읽지 못하면 503 `AI_CREDIT_UNAVAILABLE`** — 0 으로 대신하지 않습니다(0 을 그리면 다 쓴 것으로 보입니다).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "조회 성공",
      content = @Content(schema = @Schema(implementation = CreditSummaryResponse.class))
    ),
    @ApiResponse(
      responseCode = "401",
      description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "503",
      description = "크레딧 장부를 읽지 못함",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"AI_CREDIT_UNAVAILABLE\",\"errorMessage\":\"잠시 뒤에 다시 시도해주세요.\"}"
        )
      )
    )
  })
  ResponseEntity<CreditSummaryResponse> getMine(Authentication authentication);

  @Operation(
    summary = "내 AI 크레딧 사용 내역 조회",
    description = """
      설정의 "크레딧 사용 내역" 화면이 쓰는 내역을 최근 것부터 한 쪽씩 돌려줍니다 (#658).

      **처리 로직**
      1. 본인 계정의 원장 중 사용 · 지급 · 만료 · 조정 줄만 보입니다. 예약 · 반환 · 초과는 숨깁니다.
      2. 일과 만들기는 글 몫(`ROUTINE_TEXT`)과 그림 몫(`CARD_IMAGES`, `cardCount` = 붙은 그림 수) 두 줄로 나뉩니다.
         잔액이 모자라 덜 차감됐으면 글 몫을 먼저 채웁니다.
      3. 지급은 출처로 종류가 나뉩니다: `WEEKLY_GRANT` · `AD_REWARD` · `ADMIN_BONUS` · `OTHER_GRANT`.
      4. 운영이 쓴 내부 사유 글은 내려주지 않습니다. 앱이 `kind`로 문구를 정합니다. 모르는 `kind`는 증감 부호로 일반 문구를 씁니다.
      5. `routineTitle`은 사용 줄에만 있고, 일과가 지워졌으면 null 입니다.
      6. `delta`는 사용이 음수, 지급이 양수입니다. `occurredAtOffset`을 기기 시간대로 바꿔 보여줍니다.

      `page`는 0부터, `size`는 1~50 (기본 30)이며 범위를 벗어나면 가까운 값으로 맞춥니다.
      `hasNext`가 true 면 다음 쪽이 있습니다. 계정이 아직 없으면 빈 쪽입니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "조회 성공",
      content = @Content(schema = @Schema(implementation = CreditHistoryResponse.class))
    ),
    @ApiResponse(
      responseCode = "401",
      description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    )
  })
  ResponseEntity<CreditHistoryResponse> getHistory(Authentication authentication, int page, int size);
}
