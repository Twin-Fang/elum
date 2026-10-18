-- 의견 처리 상태 (이슈 #756). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- status: NEW(새 의견), IN_PROGRESS(확인 중), DONE(처리 완료). 기존 의견은 전부 NEW 로 채운다.
-- status_changed_at / status_changed_by: 마지막으로 처리 상태를 바꾼 시각과 관리자. 한 번도 안 바꿨으면 NULL.
--
-- 더하는 것만 한다. 옛 서버 이미지로 되돌려도 status 를 모른 채 읽고 쓰며, 새 행은 DEFAULT 'NEW' 가 된다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'NEW';
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMP(6);
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS status_changed_by VARCHAR(255);

-- 상태 필터 + 최신순 목록
CREATE INDEX IF NOT EXISTS idx_feedback_status_created ON feedback (status, created_at);
