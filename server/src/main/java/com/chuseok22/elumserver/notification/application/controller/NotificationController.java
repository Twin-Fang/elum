package com.chuseok22.elumserver.notification.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationPageResponse;
import com.chuseok22.elumserver.notification.application.dto.response.UnreadSummaryResponse;
import com.chuseok22.elumserver.notification.application.service.NotificationQueryService;
import com.chuseok22.elumserver.notification.application.service.NotificationReadService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/// 보호자 알림 목록·안 읽음 요약·읽음 처리. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/notifications")
@RestController
@RequiredArgsConstructor
public class NotificationController implements NotificationControllerDocs {

  private final NotificationQueryService notificationQueryService;
  private final NotificationReadService notificationReadService;

  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<NotificationPageResponse> list(Authentication authentication,
    @RequestParam(required = false) String cursor, @RequestParam(required = false) Integer size) {
    return ResponseEntity.ok(notificationQueryService.page(Caller.from(authentication).memberId(), cursor, size));
  }

  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/unread-summary")
  public ResponseEntity<UnreadSummaryResponse> unreadSummary(Authentication authentication,
    @RequestParam(required = false) String platform) {
    return ResponseEntity.ok(notificationQueryService.unreadSummary(Caller.from(authentication).memberId(), platform));
  }

  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PostMapping("/{id}/read")
  public ResponseEntity<Void> markRead(Authentication authentication, @PathVariable String id) {
    notificationReadService.markRead(Caller.from(authentication).memberId(), id);
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/read-all")
  public ResponseEntity<Void> markAllRead(Authentication authentication) {
    notificationReadService.markAllRead(Caller.from(authentication).memberId());
    return ResponseEntity.noContent().build();
  }
}
