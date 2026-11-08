package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionResponse;
import com.chuseok22.elumserver.admin.application.service.ControlTowerAttentionService;
import com.chuseok22.elumserver.common.application.exception.JsonErrorResponse;
import com.chuseok22.elumserver.common.infrastructure.constant.SecurityPaths;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

/**
 * 관제소 확인할 일 수집 GET /control/attention: 켜짐 확인(404) > 토큰 검사(401) > 스냅샷(200, 실패 503)
 * @LogMonitoring 없음: 관제소가 1분마다 불러 요청 로그만 채움 (AdminStatsApiController 배지와 같음)
 */
@Slf4j
@RestController
@JsonErrorResponse
@RequiredArgsConstructor
public class ControlTowerAttentionController implements ControlTowerAttentionControllerDocs {

  static final String TOKEN_HEADER_NAME = "X-Control-Token";

  private final ControlTowerAttentionService controlTowerAttentionService;

  @Override
  @GetMapping(SecurityPaths.CONTROL_ATTENTION)
  public ResponseEntity<ControlTowerAttentionResponse> getAttention(
    @RequestHeader(value = TOKEN_HEADER_NAME, required = false) String presentedToken
  ) {
    if (!controlTowerAttentionService.isEnabled()) {
      return ResponseEntity.notFound().build();
    }
    if (!controlTowerAttentionService.isTokenAccepted(presentedToken)) {
      log.warn("[control attention] rejected 401 : {}", presentedToken == null ? "token missing" : "token mismatch");
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }
    controlTowerAttentionService.recordCollected();
    try {
      return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(controlTowerAttentionService.buildSnapshot());
    } catch (RuntimeException e) {
      log.warn("[control attention] snapshot failed 503 : {}", e.getClass().getSimpleName(), e);
      return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
    }
  }
}
