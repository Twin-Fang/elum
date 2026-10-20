package com.chuseok22.elumserver.notification.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.notification.application.dto.request.NotificationSettingRequest;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationSettingResponse;
import com.chuseok22.elumserver.notification.application.service.NotificationSettingService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/// 보호자 알림 설정 조회·저장. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/notification-settings")
@RestController
@RequiredArgsConstructor
public class NotificationSettingController implements NotificationSettingControllerDocs {

  private final NotificationSettingService notificationSettingService;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<NotificationSettingResponse> get(Authentication authentication) {
    return ResponseEntity.ok(notificationSettingService.get(Caller.from(authentication).memberId()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping
  public ResponseEntity<NotificationSettingResponse> update(Authentication authentication,
    @RequestBody NotificationSettingRequest request) {
    return ResponseEntity.ok(notificationSettingService.update(Caller.from(authentication).memberId(), request));
  }
}
