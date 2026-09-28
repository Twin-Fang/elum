package com.chuseok22.elumserver.auth.application.controller;

import com.chuseok22.elumserver.auth.application.dto.request.LoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.SignUpRequest;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.auth.application.service.AuthService;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 이름만 받던 구형 APK와 로컬 E2E를 위한 비밀번호 인증 API.
 *
 * <p>운영에서는 빈 자체가 만들어지지 않아 구형 APK가 계정을 다시 생성할 수 없다. 로컬에서 과거 인증
 * 회귀 시험이 꼭 필요할 때만 환경변수로 명시적으로 연다.
 */
@Deprecated(forRemoval = true)
@SuppressWarnings("removal")
@Profile("!prod")
@ConditionalOnProperty(prefix = "elum.auth.legacy-password", name = "enabled", havingValue = "true")
@RequestMapping("/api/auth")
@RestController
@RequiredArgsConstructor
public class LegacyPasswordAuthController implements LegacyPasswordAuthControllerDocs {

  private static final String DEVICE_ID_HEADER = "X-Device-Id";

  private final AuthService authService;

  // 요청과 응답에 자격증명이 있으므로 값은 로그에 남기지 않는다.
  @Deprecated(forRemoval = true)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/signup")
  public ResponseEntity<Void> signUp(@RequestBody @Valid SignUpRequest request) {
    authService.signUp(request);
    return ResponseEntity.status(HttpStatus.CREATED).build();
  }

  @Deprecated(forRemoval = true)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/login")
  public ResponseEntity<TokenResponse> login(
    @RequestBody @Valid LoginRequest request,
    @RequestHeader(value = DEVICE_ID_HEADER, required = false) String deviceId
  ) {
    return ResponseEntity.ok(authService.login(request, deviceId));
  }
}
