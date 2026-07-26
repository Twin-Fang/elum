package com.chuseok22.elumserver.common.application.controller;

import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 컨테이너 헬스체크용 liveness 엔드포인트.
 * Dockerfile HEALTHCHECK가 기존에 /actuator/health를 호출했지만 Actuator 의존성이 없어
 * 항상 404 → 30초마다 에러 dispatch 로그가 쌓였다. 의존성 추가 없이 이 엔드포인트로 대체한다.
 * /api/**, /admin/** 어느 securityMatcher에도 걸리지 않아 인증 없이 접근 가능하다
 * (SecurityConfig의 Swagger 경로와 동일한 구조).
 * 30초마다 호출되는 인프라 경로라 모니터링 로그 적재를 피하기 위해 @LogMonitoring은 붙이지 않는다.
 */
@RestController
public class HealthController implements HealthControllerDocs {

  @Override
  @GetMapping("/healthz")
  public ResponseEntity<Map<String, String>> healthz() {
    return ResponseEntity.ok(Map.of("status", "UP"));
  }
}
