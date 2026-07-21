package com.chuseok22.elumserver.member.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.dto.request.MemberNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberSupportGoalsUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
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
  name = "Member",
  description = "보호자 회원 정보 조회/온보딩(닉네임·도움 목표) API. 모든 엔드포인트는 accessToken(Bearer) 인증이 필요합니다."
)
public interface MemberControllerDocs {

  @Operation(
    summary = "내 정보 조회",
    description = """
      JWT로 인증된 보호자 본인의 정보를 조회합니다.

      **처리 로직**
      1. Authorization 헤더의 accessToken에서 회원 ID(subject)를 추출합니다.
      2. 해당 ID로 회원을 조회해 반환합니다.
      3. 토큰이 없거나 형식이 잘못됐거나 서명이 유효하지 않거나 만료된 경우 401을 반환합니다.
      4. 토큰은 유효하지만 대상 회원이 존재하지 않으면 404를 반환합니다(정상 흐름에서는 거의 발생하지 않는 예외 케이스입니다).

      **사용 방법**
      - Swagger UI에서 테스트하려면 우측 상단 Authorize 버튼에 로그인 API로 발급받은 accessToken을 입력하세요.
      - 실제 요청 시에는 `Authorization: Bearer {accessToken}` 헤더를 직접 담아 보내면 됩니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "조회 성공",
      content = @Content(schema = @Schema(implementation = MemberResponse.class))
    ),
    @ApiResponse(
      responseCode = "401",
      description = "accessToken이 없거나 유효하지 않은 경우 (형식 오류, 서명 불일치, 만료 포함)",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_TOKEN\",\"errorMessage\":\"유효하지 않은 토큰입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "404",
      description = "토큰은 유효하지만 대상 회원을 찾을 수 없는 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"MEMBER_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 회원입니다.\"}"
        )
      )
    )
  })
  ResponseEntity<MemberResponse> getMyInfo(Authentication authentication);

  @Operation(
    summary = "아이 호칭 설정",
    description = "보호자가 아이를 부를 호칭(별명)을 저장합니다. 이후 AI 카드 생성 프롬프트와 응답에 반영됩니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "저장 성공",
      content = @Content(schema = @Schema(implementation = MemberResponse.class))
    ),
    @ApiResponse(
      responseCode = "400",
      description = "nickname 누락",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"nickname: nickname은 필수입니다.\"}"
        )
      )
    )
  })
  ResponseEntity<MemberResponse> updateNickname(Authentication authentication, MemberNicknameUpdateRequest request);

  @Operation(
    summary = "도움 목표 설정",
    description = """
      보호자가 선택한 도움 목표를 저장합니다. 기존 선택을 전체 교체하며, 빈 배열을 보내면 전부 해제됩니다.
      저장된 값은 AI 카드 생성 시 준비물 질문 여부와 카드 작성 방식에 반영됩니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "저장 성공",
      content = @Content(schema = @Schema(implementation = MemberResponse.class))
    ),
    @ApiResponse(
      responseCode = "400",
      description = "supportGoals 누락 또는 잘못된 값",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"입력값이 올바르지 않습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<MemberResponse> updateSupportGoals(
    Authentication authentication, MemberSupportGoalsUpdateRequest request
  );

  @Operation(
    summary = "회원 탈퇴",
    description = """
      JWT로 인증된 보호자 본인의 계정을 완전히 삭제합니다(하드 삭제).

      **처리 로직**
      1. Authorization 헤더의 accessToken에서 회원 ID(subject)를 추출합니다.
      2. 해당 회원이 작성한 모든 일과(Routine)와 그 하위 단계(RoutineStep)를 함께 삭제합니다.
      3. 회원 레코드 자체를 삭제합니다. soft-delete가 아니므로 삭제 후에는 복구할 수 없고, 같은 아이디로 즉시 재가입할 수 있습니다.
      4. 이미 발급된 accessToken은 만료 시각까지는 유효할 수 있습니다(별도 토큰 무효화 없음).

      **사용 방법**
      - Swagger UI에서 테스트하려면 우측 상단 Authorize 버튼에 로그인 API로 발급받은 accessToken을 입력하세요.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "204",
      description = "탈퇴 성공(본문 없음)"
    ),
    @ApiResponse(
      responseCode = "401",
      description = "accessToken이 없거나 유효하지 않은 경우 (형식 오류, 서명 불일치, 만료 포함)",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_TOKEN\",\"errorMessage\":\"유효하지 않은 토큰입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "404",
      description = "토큰은 유효하지만 대상 회원을 찾을 수 없는 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"MEMBER_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 회원입니다.\"}"
        )
      )
    )
  })
  ResponseEntity<Void> withdraw(Authentication authentication);
}
