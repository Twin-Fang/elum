package com.chuseok22.elumserver.auth.application.controller;

import com.chuseok22.elumserver.auth.application.dto.request.OAuthLoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.RefreshTokenRequest;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;

@Tag(
  name = "Auth",
  description = "보호자 소셜 로그인 및 토큰 갱신 API. 로그인 성공 시 발급되는 accessToken은 이후 인증이 필요한 "
    + "모든 /api/** 요청의 Authorization 헤더에 사용됩니다."
)
public interface AuthControllerDocs {

  @Operation(
    summary = "소셜 로그인 (카카오 · 네이버 · 구글 · 애플)",
    description = """
      제공자 SDK로 받은 토큰을 서버가 확인한 뒤, 서비스 토큰(accessToken · refreshToken)을 발급합니다.

      **경로 변수 provider**
      - `kakao` · `naver` — 액세스 토큰을 보냅니다.
      - `google` · `apple` — ID 토큰(JWT)을 보냅니다.

      **처리 로직**
      1. 제공자에게 토큰을 확인시킵니다. 이때 이 토큰이 **우리 앱을 위해 발급된 것인지**까지 검사합니다.
      2. `provider + providerUserId`로 계정을 찾습니다. 이메일로 찾지 않습니다.
      3. 계정이 있으면 로그인하고, 없으면 계정과 프로필을 함께 만듭니다.
      4. accessToken과 refreshToken을 발급합니다.

      **주의사항**
      - 제공자 토큰은 확인 후 폐기합니다. 서버에 저장하지 않습니다.
      - 제공자가 검증한 이메일이 이미 다른 계정에 쓰이고 있으면 409(OAUTH_EMAIL_CONFLICT)를 반환합니다.
        자동으로 합치지 않습니다 — 기존 방법으로 로그인한 뒤 계정 설정에서 연결해야 합니다.
      - `X-Device-Id` 헤더를 보내면 기기별로 세션을 구분해 관리할 수 있습니다. 선택 사항입니다.
      """
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "로그인 성공. accessToken · refreshToken 발급"),
    @ApiResponse(
      responseCode = "400",
      description = "지원하지 않는 provider이거나 token이 비어 있는 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"OAUTH_PROVIDER_UNSUPPORTED\",\"errorMessage\":\"지원하지 않는 로그인 방식입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "401",
      description = "토큰이 위조·만료되었거나 다른 앱에서 발급된 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"OAUTH_VERIFICATION_FAILED\",\"errorMessage\":\"소셜 로그인 확인에 실패했습니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "제공자가 검증한 이메일이 이미 다른 계정에 등록된 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"OAUTH_EMAIL_CONFLICT\",\"errorMessage\":\"이미 다른 방법으로 가입된 이메일입니다.\"}"
        )
      )
    )
  })
  ResponseEntity<TokenResponse> oauthLogin(String provider, OAuthLoginRequest request, String deviceId);

  @Operation(
    summary = "토큰 갱신",
    description = """
      refreshToken으로 새 accessToken과 새 refreshToken을 받습니다.

      **처리 로직**
      1. 받은 refreshToken을 확인합니다.
      2. 새 accessToken과 **새 refreshToken**을 발급하고, 사용한 refreshToken은 즉시 만료시킵니다.

      **주의사항**
      - 갱신할 때마다 refreshToken이 바뀝니다. 응답으로 받은 새 값으로 반드시 덮어쓰세요.
      - **이미 사용한 refreshToken을 다시 보내면** 토큰이 복사됐다고 보고 그 계정의 모든 세션을
        끊습니다(401 REFRESH_TOKEN_REUSED). 이 응답을 받으면 다시 로그인시켜야 합니다.
      - 앱은 accessToken이 만료됐을 때 이 API를 한 번만 호출하도록 만들어야 합니다.
        동시에 여러 번 호출하면 정상 사용자가 재사용으로 오인돼 로그아웃됩니다.
      """
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "갱신 성공. 새 accessToken · refreshToken 발급"),
    @ApiResponse(
      responseCode = "401",
      description = "refreshToken이 유효하지 않거나(만료·폐기·위조) 이미 사용된 토큰인 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = {
          @ExampleObject(
            name = "유효하지 않음",
            value = "{\"errorCode\":\"REFRESH_TOKEN_INVALID\",\"errorMessage\":\"유효하지 않은 리프레시 토큰입니다.\"}"
          ),
          @ExampleObject(
            name = "재사용 감지",
            value = "{\"errorCode\":\"REFRESH_TOKEN_REUSED\",\"errorMessage\":\"다시 로그인해 주세요.\"}"
          )
        }
      )
    )
  })
  ResponseEntity<TokenResponse> refresh(RefreshTokenRequest request, String deviceId);

  @Operation(
    summary = "로그아웃",
    description = """
      refreshToken이 속한 계정의 세션을 모두 끊습니다.

      **주의사항**
      - accessToken은 만료 전까지 살아 있습니다. 클라이언트가 저장된 토큰을 함께 지워야 합니다.
      - 이미 만료·폐기된 토큰을 보내도 200을 반환합니다. 로그아웃은 실패할 이유가 없습니다.
      """
  )
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "로그아웃 처리 완료. 응답 본문 없음.")
  })
  ResponseEntity<Void> logout(RefreshTokenRequest request);
}
