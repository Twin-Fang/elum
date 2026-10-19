-- 일과관리 원본 구분 (이슈 #804). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- source_routine_id: "보내기"로 만든 오늘 일과의 원본 일과 ID. 원본이면 NULL — 기존 일과는 모두 원본이다.
-- library_only: 일과관리 "복사하기"로 만든 일과. 일과관리에만 있고 홈 목록에는 뜨지 않는다.
-- library_hidden: 보호자가 일과관리에서 지운 원본. 기록이 남아 있어 행은 지우지 않고 목록에서만 뺀다.
--
-- 옛 서버 이미지는 이 컬럼을 모르고 routine 을 INSERT 하므로 NOT NULL 에는 반드시 DEFAULT 가 있어야 한다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE routine ADD COLUMN IF NOT EXISTS source_routine_id VARCHAR(255);
ALTER TABLE routine ADD COLUMN IF NOT EXISTS library_only BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE routine ADD COLUMN IF NOT EXISTS library_hidden BOOLEAN NOT NULL DEFAULT FALSE;

-- 보내기마다 "오늘 이미 보냈는가"를 묻는다
CREATE INDEX IF NOT EXISTS idx_routine_source_routine_id ON routine (source_routine_id);
