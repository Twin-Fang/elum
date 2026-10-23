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

/// 푸시 기기 등록·해제 (보호자·이룸이 기기). 권한은 SecurityConfig 가 GUARDIAN·ELUMI 둘 다 연다
/// 이룸이 기기 구분(linkId)은 토큰에서만 읽음 (요청 본문 값 안 믿음)
@RequestMapping("/api/push-devices")
@RestController
@RequiredArgsConstructor
public class PushDeviceController implements PushDeviceControllerDocs {

  private final PushDeviceService pushDeviceService;

  // 푸시 토큰이 서버 로그에 남으면 안 되므로 파라미터·결과를 남기지 않는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping
  public ResponseEntity<Void> register(Authentication authentication, @RequestBody PushDeviceRegisterRequest request) {
    Caller caller = Caller.from(authentication);
    pushDeviceService.register(caller.memberId(), caller.linkId(), request);
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{token}")
  public ResponseEntity<Void> unregister(Authentication authentication, @PathVariable String token) {
    Caller caller = Caller.from(authentication);
    pushDeviceService.unregister(caller.memberId(), caller.linkId(), token);
    return ResponseEntity.noContent().build();
  }
}
