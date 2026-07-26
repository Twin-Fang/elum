package com.chuseok22.elumserver.common.application.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.Map;
import org.springframework.http.ResponseEntity;

@Tag(
  name = "Health",
  description = "인프라 상태 확인 API. 컨테이너 헬스체크와 배포 검증 단계가 호출한다."
)
public interface HealthControllerDocs {

  @Operation(
    summary = "서버 상태 확인",
    description = """
      서버가 요청을 처리할 수 있는 상태인지 확인합니다.

      **용도**
      - 컨테이너(Docker Swarm) HEALTHCHECK가 30초마다 호출합니다.
      - 배포 워크플로우의 기동 검증 단계가 폴백 경로로 사용합니다.

      **주의사항**
      - 인증이 필요 없습니다.
      - DB 등 외부 의존성은 검사하지 않는 가벼운 liveness 체크입니다.
      """
  )
  @ApiResponse(responseCode = "200", description = "서버 정상. {\"status\": \"UP\"} 반환.")
  ResponseEntity<Map<String, String>> healthz();
}
