-- 회원 활동 추적(마지막 로그인/활동, 로그인 횟수)과 계정 정지·강제 로그아웃용 컬럼 추가.
-- prod는 ddl-auto: validate라 Hibernate가 컬럼을 만들지 않으므로 여기서 직접 추가한다.
-- 로컬 등 ddl-auto: update 환경에서 이미 생성됐을 수 있어 IF NOT EXISTS로 양쪽 모두 안전하게 한다.
ALTER TABLE member ADD COLUMN IF NOT EXISTS status VARCHAR(255) NOT NULL DEFAULT 'ACTIVE';
ALTER TABLE member ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP(6);
ALTER TABLE member ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMP(6);
ALTER TABLE member ADD COLUMN IF NOT EXISTS login_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE member ADD COLUMN IF NOT EXISTS token_invalid_before TIMESTAMP(6);
