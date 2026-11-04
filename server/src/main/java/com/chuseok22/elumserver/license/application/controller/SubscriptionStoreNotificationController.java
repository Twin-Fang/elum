package com.chuseok22.elumserver.license.application.controller;

import com.chuseok22.elumserver.license.application.dto.request.AppleNotificationRequest;
import com.chuseok22.elumserver.license.application.service.store.AppleSubscriptionService;
import com.chuseok22.elumserver.license.application.service.store.GoogleSubscriptionService;
import com.chuseok22.elumserver.license.application.service.store.StoreNotificationOutcome;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 스토어 서버가 부르는 결제 알림 2개. 인증 헤더 없음: Apple 은 알림 서명, Google 은 푸시 주소 토큰이 인증 (#1071)
 * 응답 코드: 처리·무시 200, 서명·형식 오류 400, 토큰 불일치 403, 꺼짐·확인 실패 503 (스토어가 다시 보냄)
 */
@RequestMapping("/api/subscriptions")
@RestController
@RequiredArgsConstructor
public class SubscriptionStoreNotificationController implements SubscriptionStoreNotificationControllerDocs {

  private final AppleSubscriptionService appleSubscriptionService;
  private final GoogleSubscriptionService googleSubscriptionService;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/apple/notifications")
  public ResponseEntity<String> receiveApple(@RequestBody(required = false) AppleNotificationRequest request) {
    StoreNotificationOutcome outcome = appleSubscriptionService.handleNotification(request == null ? null : request.signedPayload());
    return toResponse(outcome);
  }

  // 쿼리에 알림 토큰이 있어 파라미터를 남기지 않는다
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/google/notifications")
  public ResponseEntity<String> receiveGoogle(
    @RequestParam(name = "token", required = false) String token, @RequestBody(required = false) String body
  ) {
    return toResponse(googleSubscriptionService.handleNotification(token, body));
  }

  private static ResponseEntity<String> toResponse(StoreNotificationOutcome outcome) {
    return ResponseEntity.status(outcome.getHttpStatus()).body(outcome.name().toLowerCase());
  }
}
