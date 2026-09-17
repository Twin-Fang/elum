package com.chuseok22.elumserver.auth.application.controller;

import com.chuseok22.elumserver.auth.application.dto.request.LoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.OAuthLoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.RefreshTokenRequest;
import com.chuseok22.elumserver.auth.application.dto.request.SignUpRequest;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.auth.application.service.AuthService;
import com.chuseok22.elumserver.auth.application.service.OAuthLoginService;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RequestMapping("/api/auth")
@RestController
@RequiredArgsConstructor
public class AuthController implements AuthControllerDocs {

  /** 기기별 세션 구분용. 기존 앱은 보내지 않으므로 없어도 동작해야 한다. */
  private static final String DEVICE_ID_HEADER = "X-Device-Id";

  private final AuthService authService;
  private final OAuthLoginService oAuthLoginService;

  // 요청에는 비밀번호·소셜 토큰이, 응답에는 accessToken·refreshToken이 담기므로
  // logParameters/logResult를 false로 두어 자격증명이 로그에 남지 않도록 한다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/signup")
  public ResponseEntity<Void> signUp(@RequestBody @Valid SignUpRequest request) {
    authService.signUp(request);
    return ResponseEntity.status(HttpStatus.CREATED).build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/login")
  public ResponseEntity<TokenResponse> login(
    @RequestBody @Valid LoginRequest request,
    @RequestHeader(value = DEVICE_ID_HEADER, required = false) String deviceId
  ) {
    return ResponseEntity.ok(authService.login(request, deviceId));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/oauth/{provider}")
  public ResponseEntity<TokenResponse> oauthLogin(
    @PathVariable String provider,
    @RequestBody @Valid OAuthLoginRequest request,
    @RequestHeader(value = DEVICE_ID_HEADER, required = false) String deviceId
  ) {
    return ResponseEntity.ok(oAuthLoginService.login(provider, request.token(), deviceId));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/refresh")
  public ResponseEntity<TokenResponse> refresh(
    @RequestBody @Valid RefreshTokenRequest request,
    @RequestHeader(value = DEVICE_ID_HEADER, required = false) String deviceId
  ) {
    return ResponseEntity.ok(authService.refresh(request.refreshToken(), deviceId));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/logout")
  public ResponseEntity<Void> logout(@RequestBody @Valid RefreshTokenRequest request) {
    authService.logout(request.refreshToken());
    return ResponseEntity.noContent().build();
  }
}
