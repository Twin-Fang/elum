package com.chuseok22.elumserver.notification.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.notification.application.dto.request.PushDeviceRegisterRequest;
import com.chuseok22.elumserver.notification.application.service.PushDeviceService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/// 보호자 푸시 기기 등록·해제. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/push-devices")
@RestController
@RequiredArgsConstructor
public class PushDeviceController implements PushDeviceControllerDocs {

  private final PushDeviceService pushDeviceService;

  // 푸시 토큰이 서버 로그에 남으면 안 되므로 파라미터·결과를 남기지 않는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping
  public ResponseEntity<Void> register(Authentication authentication, @RequestBody PushDeviceRegisterRequest request) {
    pushDeviceService.register(Caller.from(authentication).memberId(), request);
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{token}")
  public ResponseEntity<Void> unregister(Authentication authentication, @PathVariable String token) {
    pushDeviceService.unregister(Caller.from(authentication).memberId(), token);
    return ResponseEntity.noContent().build();
  }
}
