package com.chuseok22.elumserver.auth.application.controller;

import com.chuseok22.elumserver.auth.application.dto.request.LoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.SignUpRequest;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;

/** 개발 환경에서만 노출하는 제거 예정 비밀번호 인증 API 문서. */
@Tag(name = "Legacy Password Auth", description = "제거 예정인 개발용 비밀번호 인증 API")
public interface LegacyPasswordAuthControllerDocs {

  @Deprecated(forRemoval = true)
  @Operation(
    summary = "구형 비밀번호 회원가입",
    description = "구형 APK 회귀 시험 전용입니다. 운영 환경에는 매핑되지 않습니다.",
    deprecated = true
  )
  @ApiResponses({
    @ApiResponse(responseCode = "201", description = "개발 환경에서 회원가입 성공"),
    @ApiResponse(responseCode = "409", description = "이미 사용 중인 아이디")
  })
  ResponseEntity<Void> signUp(SignUpRequest request);

  @Deprecated(forRemoval = true)
  @Operation(
    summary = "구형 비밀번호 로그인",
    description = "구형 APK 회귀 시험 전용입니다. 운영 환경에는 매핑되지 않습니다.",
    deprecated = true
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "개발 환경에서 로그인 성공"),
    @ApiResponse(responseCode = "401", description = "아이디 또는 비밀번호 불일치")
  })
  ResponseEntity<TokenResponse> login(LoginRequest request, String deviceId);
}
