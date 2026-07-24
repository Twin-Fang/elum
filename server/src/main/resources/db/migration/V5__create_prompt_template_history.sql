-- 프롬프트 수정 시 교체되기 직전의 content를 보관하는 이력 테이블 (append-only).
-- prod는 ddl-auto: validate라 Hibernate가 테이블을 만들지 않으므로 여기서 직접 생성한다.
-- 로컬 등 ddl-auto: update 환경에서 이미 생성됐을 수 있어 IF NOT EXISTS로 양쪽 모두 안전하게 한다.
CREATE TABLE IF NOT EXISTS prompt_template_history (
  id VARCHAR(255) NOT NULL,
  prompt_key VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP(6),
  updated_at TIMESTAMP(6),
  CONSTRAINT pk_prompt_template_history PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_prompt_template_history_key_created
  ON prompt_template_history (prompt_key, created_at);
