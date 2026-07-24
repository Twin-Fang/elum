-- AI 호출(Gemini 텍스트/이미지, 로컬 LLM) 1건당 결과·토큰·추정 비용을 기록하는 테이블.
-- prod는 ddl-auto: validate라 Hibernate가 테이블을 만들지 않으므로 여기서 직접 생성한다.
-- 로컬 등 ddl-auto: update 환경에서 이미 생성됐을 수 있어 IF NOT EXISTS로 양쪽 모두 안전하게 한다.
CREATE TABLE IF NOT EXISTS ai_call_log (
  id VARCHAR(255) NOT NULL,
  member_id VARCHAR(255),
  call_type VARCHAR(255) NOT NULL,
  model VARCHAR(255),
  success BOOLEAN NOT NULL,
  error_message VARCHAR(500),
  latency_ms BIGINT,
  prompt_tokens INTEGER,
  output_tokens INTEGER,
  total_tokens INTEGER,
  estimated_cost_usd DOUBLE PRECISION,
  created_at TIMESTAMP(6),
  updated_at TIMESTAMP(6),
  CONSTRAINT pk_ai_call_log PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_ai_call_log_member_created ON ai_call_log (member_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ai_call_log_created ON ai_call_log (created_at);
