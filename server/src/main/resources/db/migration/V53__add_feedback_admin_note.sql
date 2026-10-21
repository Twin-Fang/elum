-- 의견 관리자 메모 (이슈 #655). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- admin_note: 관리자끼리 남기는 처리 메모 (최대 2,000자는 서버가 검사). 없으면 NULL.
-- admin_note_changed_at / admin_note_changed_by: 마지막으로 메모를 저장·지운 시각과 관리자. 한 번도 안 건드렸으면 NULL.
--
-- 더하는 것만 한다. 옛 서버 이미지로 되돌려도 이 컬럼을 모른 채 읽고 쓴다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS admin_note TEXT;
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS admin_note_changed_at TIMESTAMP(6);
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS admin_note_changed_by VARCHAR(255);
