package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;

@Tag(
  name = "ControlTowerAttention",
  description = "관제소 확인할 일 수집 (attention v1, #1229). **관제소 서버만 부릅니다.** 로그인·JWT 없이 X-Control-Token 이 인증입니다."
)
public interface ControlTowerAttentionControllerDocs {

  @Operation(
    summary = "관제소 확인할 일 스냅샷",
    description = """
      관제소가 1분마다 부르는 pull 엔드포인트입니다. 규격: suh-project-control docs/control-tower/attention.

      **처리 로직**
      1. 관리자 시스템 설정 `CONTROL_TOWER_ATTENTION_ENABLED` 가 꺼져 있으면 404 (관제소 "연동 꺼짐").
      2. `X-Control-Token` 을 환경 변수 `CONTROL_TOWER_ATTENTION_TOKEN`·`CONTROL_TOWER_ATTENTION_TOKEN_PREVIOUS` 와 상수 시간 비교합니다.
         없거나 틀리면 401. 서버에 토큰이 하나도 없으면 늘 401.
      3. 항목 6개를 0건이어도 늘 보냅니다: feedback.new, review.pending, job.stuck, ai.alert, report.unresolved (count), budget.daily (gauge, USD).
      4. 개수·값만 보냅니다. 의견 내용·회원 정보는 싣지 않습니다.
      5. 집계가 실패하면 503 (관제소는 마지막 값을 유지).
      """
  )
  ResponseEntity<ControlTowerAttentionResponse> getAttention(String presentedToken);
}
