package com.chuseok22.elumserver.adreward.application.controller;

import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardOfferResponse;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardSessionResponse;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardSessionStatusResponse;
import com.chuseok22.elumserver.adreward.application.service.AdRewardSessionService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/// 보호자가 광고를 보고 크레딧을 받는 흐름 (#463). 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/credits/ad-rewards")
@RestController
@RequiredArgsConstructor
public class AdRewardController implements AdRewardControllerDocs {

  private final AdRewardSessionService sessionService;

  // nonce 는 한 번용 비밀에 가까워 파라미터·결과는 남기지 않는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/offer")
  public ResponseEntity<AdRewardOfferResponse> offer(Authentication authentication) {
    return ResponseEntity.ok(AdRewardOfferResponse.from(sessionService.offer(Caller.from(authentication).memberId())));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/sessions")
  public ResponseEntity<AdRewardSessionResponse> createSession(Authentication authentication) {
    return ResponseEntity.ok(AdRewardSessionResponse.from(sessionService.create(Caller.from(authentication).memberId())));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/sessions/{nonce}")
  public ResponseEntity<AdRewardSessionStatusResponse> getSessionStatus(
    Authentication authentication, @PathVariable String nonce
  ) {
    return ResponseEntity.ok(AdRewardSessionStatusResponse.from(
      sessionService.status(Caller.from(authentication).memberId(), nonce)));
  }
}
