-- 동적 시스템 설정(AI 모델명, 생성 파라미터, 요금 단가)의 단일 진실 공급원 테이블.
-- prod는 ddl-auto: validate라 Hibernate가 테이블을 만들지 않으므로 여기서 직접 생성한다.
-- 로컬 등 ddl-auto: update 환경에서 이미 생성됐을 수 있어 IF NOT EXISTS로 양쪽 모두 안전하게 한다.
CREATE TABLE IF NOT EXISTS system_config (
  id VARCHAR(255) NOT NULL,
  config_key VARCHAR(255) NOT NULL,
  config_value TEXT NOT NULL,
  created_at TIMESTAMP(6),
  updated_at TIMESTAMP(6),
  CONSTRAINT pk_system_config PRIMARY KEY (id),
  CONSTRAINT uk_system_config_key UNIQUE (config_key)
);
