package com.chuseok22.elumserver.auth.application.controller;

import com.chuseok22.elumserver.auth.application.dto.request.LoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.SignUpRequest;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.auth.application.service.AuthService;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RequestMapping("/api/auth")
@RestController
@RequiredArgsConstructor
public class AuthController implements AuthControllerDocs {

  private final AuthService authService;

  // signup/login 요청에는 비밀번호가, 로그인 응답에는 accessToken이 포함되므로
  // logParameters/logResult를 false로 두어 평문 비밀번호·토큰이 로그에 남지 않도록 한다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/signup")
  public ResponseEntity<Void> signUp(@RequestBody @Valid SignUpRequest request) {
    authService.signUp(request);
    return ResponseEntity.status(HttpStatus.CREATED).build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/login")
  public ResponseEntity<TokenResponse> login(@RequestBody @Valid LoginRequest request) {
    return ResponseEntity.ok(authService.login(request));
  }
}
