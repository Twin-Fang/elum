package com.chuseok22.elumserver.auth.application.controller;

import com.chuseok22.elumserver.auth.application.dto.request.LoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.SignUpRequest;
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
  description = "보호자 회원가입 및 로그인 API. 로그인 성공 시 발급되는 accessToken은 이후 인증이 필요한 "
    + "모든 /api/** 요청의 Authorization 헤더에 사용됩니다."
)
public interface AuthControllerDocs {

  @Operation(
    summary = "회원가입",
    description = """
      보호자 계정을 아이디/비밀번호로 생성합니다.

      **처리 로직**
      1. 요청받은 username이 이미 사용 중인지 확인합니다.
      2. 이미 존재하면 409(DUPLICATE_USERNAME)를 반환합니다.
      3. 존재하지 않으면 비밀번호를 BCrypt로 해시한 뒤 회원을 생성합니다.

      **주의사항**
      - 회원가입만으로는 로그인되지 않습니다. 가입 후 별도로 로그인 API를 호출해 accessToken을 발급받아야 합니다.
      - 성공 시 응답 본문은 없습니다(201 Created, body 없음).
      - username/password는 보안상 요청 로그에 남기지 않습니다.
      """
  )
  @ApiResponses({
    @ApiResponse(responseCode = "201", description = "회원가입 성공. 응답 본문 없음."),
    @ApiResponse(
      responseCode = "400",
      description = "요청값 검증 실패 — username 4~20자, password 8~64자 조건 미충족 또는 필수값 누락",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"password: 비밀번호는 8자 이상 64자 이하로 입력해주세요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "이미 사용 중인 아이디로 가입을 시도한 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"DUPLICATE_USERNAME\",\"errorMessage\":\"이미 사용 중인 아이디입니다.\"}"
        )
      )
    )
  })
  ResponseEntity<Void> signUp(SignUpRequest request);

  @Operation(
    summary = "로그인",
    description = """
      아이디/비밀번호로 로그인하고 accessToken(JWT)을 발급받습니다.

      **처리 로직**
      1. username/password로 Spring Security 인증을 수행합니다.
      2. 아이디가 없거나 비밀번호가 일치하지 않으면 401(INVALID_CREDENTIALS)을 반환합니다.
      3. 인증에 성공하면 회원 ID를 subject로 하는 accessToken을 발급해 응답합니다.

      **사용 방법**
      - 응답의 accessToken을 클라이언트에 저장한 뒤, 인증이 필요한 API 호출 시 `Authorization: Bearer {accessToken}` 헤더로 전달하세요.
      - refreshToken은 발급하지 않습니다. accessToken이 만료되면 다시 로그인해야 합니다.
      """
  )
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "로그인 성공, accessToken 발급",
      content = @Content(schema = @Schema(implementation = TokenResponse.class))
    ),
    @ApiResponse(
      responseCode = "400",
      description = "요청값 검증 실패 — username/password 누락",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"username: 아이디는 필수입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "401",
      description = "아이디가 존재하지 않거나 비밀번호가 일치하지 않는 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_CREDENTIALS\",\"errorMessage\":\"아이디 또는 비밀번호가 올바르지 않습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<TokenResponse> login(LoginRequest request);
}
