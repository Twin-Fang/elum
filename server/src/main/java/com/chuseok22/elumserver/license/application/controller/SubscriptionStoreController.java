package com.chuseok22.elumserver.license.application.controller;

import com.chuseok22.elumserver.license.application.dto.request.AppleSubscriptionVerifyRequest;
import com.chuseok22.elumserver.license.application.dto.request.GoogleSubscriptionVerifyRequest;
import com.chuseok22.elumserver.license.application.dto.response.SubscriptionVerifyResponse;
import com.chuseok22.elumserver.license.application.service.SubscriptionStatusService;
import com.chuseok22.elumserver.license.application.service.store.AppleSubscriptionService;
import com.chuseok22.elumserver.license.application.service.store.GoogleSubscriptionService;
import com.chuseok22.elumserver.license.application.service.store.StoreVerification;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/// 앱이 스토어 결제 후 서버에 확인을 맡기는 곳. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다 (#1071)
@RequestMapping("/api/subscriptions")
@RestController
@RequiredArgsConstructor
public class SubscriptionStoreController implements SubscriptionStoreControllerDocs {

  private final AppleSubscriptionService appleSubscriptionService;
  private final GoogleSubscriptionService googleSubscriptionService;
  private final SubscriptionStatusService subscriptionStatusService;

  // 영수증 JWS·구매 토큰이 들어 있어 파라미터를 남기지 않는다
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/apple")
  public ResponseEntity<SubscriptionVerifyResponse> verifyApple(
    Authentication authentication, @RequestBody AppleSubscriptionVerifyRequest request
  ) {
    String memberId = Caller.from(authentication).memberId();
    StoreVerification verification = request == null
      ? appleSubscriptionService.verifyFromClient(memberId, null, null)
      : appleSubscriptionService.verifyFromClient(memberId, request.signedTransaction(), request.signedRenewalInfo());
    return ResponseEntity.ok(new SubscriptionVerifyResponse(verification, subscriptionStatusService.statusOf(memberId)));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/google")
  public ResponseEntity<SubscriptionVerifyResponse> verifyGoogle(
    Authentication authentication, @RequestBody GoogleSubscriptionVerifyRequest request
  ) {
    String memberId = Caller.from(authentication).memberId();
    StoreVerification verification = request == null
      ? googleSubscriptionService.verifyFromClient(memberId, null, null)
      : googleSubscriptionService.verifyFromClient(memberId, request.purchaseToken(), request.productId());
    return ResponseEntity.ok(new SubscriptionVerifyResponse(verification, subscriptionStatusService.statusOf(memberId)));
  }
}
