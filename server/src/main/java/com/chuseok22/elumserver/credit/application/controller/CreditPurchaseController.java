package com.chuseok22.elumserver.credit.application.controller;

import com.chuseok22.elumserver.credit.application.dto.request.AppleCreditPurchaseRequest;
import com.chuseok22.elumserver.credit.application.dto.request.GoogleCreditPurchaseRequest;
import com.chuseok22.elumserver.credit.application.dto.response.CreditPacksResponse;
import com.chuseok22.elumserver.credit.application.dto.response.CreditPurchaseResponse;
import com.chuseok22.elumserver.credit.application.service.purchase.AppleCreditPurchaseService;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPackQueryService;
import com.chuseok22.elumserver.credit.application.service.purchase.GoogleCreditPurchaseService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/// 추가 크레딧 구매: 꾸러미 목록, 스토어 결제 확인·적립. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/credits")
@RestController
@RequiredArgsConstructor
public class CreditPurchaseController implements CreditPurchaseControllerDocs {

  private final CreditPackQueryService packQueryService;
  private final AppleCreditPurchaseService appleCreditPurchaseService;
  private final GoogleCreditPurchaseService googleCreditPurchaseService;

  @LogMonitoring(logParameters = false, logResult = true, logExecutionTime = true)
  @GetMapping("/packs")
  public ResponseEntity<CreditPacksResponse> getPacks() {
    return ResponseEntity.ok(packQueryService.getPacks());
  }

  // 영수증 JWS·구매 토큰이 들어 있어 파라미터를 남기지 않는다
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/purchases/apple")
  public ResponseEntity<CreditPurchaseResponse> purchaseApple(
    Authentication authentication, @RequestBody AppleCreditPurchaseRequest request
  ) {
    String memberId = Caller.from(authentication).memberId();
    return ResponseEntity.ok(appleCreditPurchaseService.verify(memberId, request == null ? null : request.signedTransaction()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/purchases/google")
  public ResponseEntity<CreditPurchaseResponse> purchaseGoogle(
    Authentication authentication, @RequestBody GoogleCreditPurchaseRequest request
  ) {
    String memberId = Caller.from(authentication).memberId();
    return ResponseEntity.ok(request == null
      ? googleCreditPurchaseService.verify(memberId, null, null)
      : googleCreditPurchaseService.verify(memberId, request.productId(), request.purchaseToken()));
  }
}
