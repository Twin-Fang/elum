package com.chuseok22.elumserver.ai.application.controller;

import com.chuseok22.elumserver.ai.application.dto.request.SensitiveInfoCheckRequest;
import com.chuseok22.elumserver.ai.application.dto.response.SensitiveInfoCheckResponse;
import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RequestMapping("/api/internal/sensitive-check")
@RestController
@RequiredArgsConstructor
public class LocalLlmTestController implements LocalLlmTestControllerDocs {

  private final SensitiveInfoGuardService sensitiveInfoGuardService;

  // 요청/응답에 민감정보 원문이 포함될 수 있으므로 logParameters/logResult를 false로 둔다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping
  public ResponseEntity<SensitiveInfoCheckResponse> check(@RequestBody @Valid SensitiveInfoCheckRequest request) {
    SensitiveInfoCheckResponse response =
      SensitiveInfoCheckResponse.from(sensitiveInfoGuardService.check(request.text()));
    return ResponseEntity.ok(response);
  }
}
