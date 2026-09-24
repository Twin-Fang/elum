package com.chuseok22.elumserver.member.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.dto.request.MemberCharacterUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberConsentRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberSupportGoalsUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberConsentResponse;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
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
      5. `profiles`에 연결된 이룸이를 먼저 연결된 차례로 담습니다. `X-Profile-Id`로 이룸이를 짚으면 위 당사자 항목이 그 이룸이가 됩니다.

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
  ResponseEntity<MemberResponse> getMyInfo(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

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
  ResponseEntity<MemberResponse> updateNickname(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    MemberNicknameUpdateRequest request
  );

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
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    MemberSupportGoalsUpdateRequest request
  );

  @Operation(
    summary = "캐릭터 설정",
    description = """
      보호자가 아이를 위해 선택한 캐릭터(루루/포포)를 저장합니다.
      저장된 값은 이후 일과 단계별 이미지 생성 시 캐릭터 참조 이미지로 사용됩니다.
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
      description = "character 값이 LULU/POPO가 아닌 잘못된 값인 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"입력값이 올바르지 않습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<MemberResponse> updateCharacter(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    MemberCharacterUpdateRequest request
  );

  @Operation(
    summary = "회원 탈퇴",
    description = """
      JWT로 인증된 보호자 본인의 계정을 탈퇴 처리합니다. 계정 행은 지우지 않고 WITHDRAWN 으로 보관합니다(#372).

      **처리 로직**
      1. Authorization 헤더의 accessToken에서 회원 ID(subject)를 추출합니다.
      2. 연결된 이룸이마다 "나가기"를 합니다(다중 보호자 #360) — 이 사람이 만든 일과(단계 포함, 임시저장 포함)·
         이 사람이 붙인 이룸이 휴대폰 연결과 세션·관계를 지웁니다. 혼자 돌보던 이룸이는 이룸이 정보까지 지우고,
         다른 보호자와 함께 돌보던 이룸이와 그들의 일과·별은 남깁니다.
      3. 세션·이룸이 휴대폰 연결·구독을 지우고, 재가입을 알아볼 최소한(계정 식별값·비밀번호 변환값·동의 기록·
         AI 이용 기록)만 보관 기간 동안 남깁니다. 보관 기간이 지나면 완전히 지웁니다.
      4. 이미 발급된 accessToken도 즉시 막습니다(tokenInvalidBefore).
      5. 모두 한 트랜잭션입니다. 중간에 실패하면 전부 되돌리고 계정은 그대로입니다.

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

  @Operation(
    summary = "약관 동의 상태 조회",
    description = """
      현재 계정의 약관 동의 상태를 반환합니다.

      `requiredCompleted`가 false면 앱은 서비스 진입 전에 동의 화면을 띄워야 합니다.
      """
  )
  ResponseEntity<MemberConsentResponse> getConsents(Authentication authentication);

  @Operation(
    summary = "약관 동의",
    description = """
      약관 동의를 기록합니다. 항목을 하나로 뭉치지 않고 **따로** 받습니다.

      **필수 항목** — 하나라도 false면 400을 반환합니다.
      - `termsAgreed` 서비스 이용약관
      - `privacyAgreed` 개인정보 수집·이용
      - `overseasTransferAgreed` 개인정보 국외 이전 (카드 생성 시 Google로 전달)
      - `guardianConfirmed` 만 14세 이상이며 아이의 법정대리인임을 확인

      **선택 항목**
      - `marketingAgreed` 서비스 소식 수신. 거부해도 서비스를 이용할 수 있으며,
        거부 의사도 그대로 저장합니다.

      동의 시각이 함께 기록됩니다. 약관을 개정하면 `consentVersion`으로 재동의 대상을 가립니다.
      """
  )
  ResponseEntity<MemberConsentResponse> agreeConsents(
    Authentication authentication, MemberConsentRequest request);
}
