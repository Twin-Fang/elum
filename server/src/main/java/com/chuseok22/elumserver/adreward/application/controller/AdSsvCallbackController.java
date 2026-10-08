package com.chuseok22.elumserver.adreward.application.controller;

import com.chuseok22.elumserver.adreward.application.service.AdRewardGrantService;
import com.chuseok22.elumserver.adreward.application.service.AdRewardResult;
import com.chuseok22.elumserver.adreward.application.service.SsvCallback;
import com.chuseok22.elumserver.adreward.application.service.SsvCallbackVerifier;
import com.chuseok22.elumserver.adreward.application.service.SsvInvalidException;
import com.chuseok22.elumserver.adreward.application.service.SsvKeysUnavailableException;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Google AdMob 이 광고 시청이 끝날 때 부르는 서버 콜백. 인증이 없고 **서명이 인증**이다.
 *
 * <p>응답 코드 규칙: 서명이 틀리면 400, 키를 못 구하면 503(Google 이 다시 보내게), 서명이 맞으면 결과와 무관하게 200 —
 * 이미 준 시청이나 규칙에 걸린 경우에도 200 이라 Google 이 의미 없이 다시 보내지 않는다. 지급 중 DB 오류는 예외로 올라가
 * 500 이 되고, 세션이 그대로라 재시도 때 다시 처리된다.
 */
@Slf4j
@RequestMapping("/api/ads")
@RestController
@RequiredArgsConstructor
public class AdSsvCallbackController implements AdSsvCallbackControllerDocs {

  private final SsvCallbackVerifier verifier;
  private final AdRewardGrantService grantService;

  // 쿼리에 nonce·서명이 들어 있어 파라미터를 남기지 않는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/ssv")
  public ResponseEntity<String> receive(HttpServletRequest request) {
    SsvCallback callback;
    try {
      // 디코딩 전 원문이 필요하다 — 서명은 원문 쿼리에 대한 것이다.
      callback = verifier.verify(request.getQueryString());
    } catch (SsvInvalidException e) {
      log.warn("광고 보상 콜백을 거절했다(서명·형식): {}", e.getMessage());
      return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("invalid");
    } catch (SsvKeysUnavailableException e) {
      return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body("unavailable");
    }

    AdRewardResult result = grantService.grant(callback);
    log.info("광고 보상 콜백 처리: outcome={}, reason={}", result.outcome(), result.reason());
    return ResponseEntity.ok("ok");
  }
}
