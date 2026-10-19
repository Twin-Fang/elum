-- 일과관리 묶음 (이슈 #806). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- routine_group: 보호자가 일과관리에서 원본 일과를 모은 묶음(폴더). 이룸이 단위다.
--   created_by 에는 외래키를 걸지 않는다 — 만든 보호자가 나가도 묶음은 이룸이에 남는다.
--   이룸이를 지우면 묶음도 함께 지운다(ON DELETE CASCADE).
--   name 은 서비스가 1~12자로 검사한다. 컬럼은 넉넉히 40.
--
-- routine.group_id / group_order: 원본 일과가 속한 묶음과 묶음 안 차례(0부터). 묶음 밖이면 NULL.
--   source_routine_id 처럼 외래키 없는 문자열이다 — 묶음을 풀면 서비스가 두 값을 NULL 로 되돌린다.
-- routine.sent_group_id / sent_group_name / sent_group_order: 묶음째 보내기로 만든 오늘 일과의 스냅샷.
--   묶음 이름을 바꾸거나 풀어도 그날 이룸이 홈의 묶음 상자는 보낸 때 모양 그대로다.
--
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
CREATE TABLE IF NOT EXISTS routine_group (
  id            VARCHAR(255) NOT NULL,
  profile_id    VARCHAR(255) NOT NULL REFERENCES profile (id) ON DELETE CASCADE,
  created_by    VARCHAR(255) NOT NULL,
  name          VARCHAR(40)  NOT NULL,
  display_order INTEGER      NOT NULL DEFAULT 0,
  created_at    TIMESTAMP(6),
  updated_at    TIMESTAMP(6),
  CONSTRAINT pk_routine_group PRIMARY KEY (id)
);

-- 묶음 목록은 이룸이 단위로 묻는다
CREATE INDEX IF NOT EXISTS idx_routine_group_profile_id ON routine_group (profile_id);

ALTER TABLE routine ADD COLUMN IF NOT EXISTS group_id VARCHAR(255);
ALTER TABLE routine ADD COLUMN IF NOT EXISTS group_order INTEGER;
ALTER TABLE routine ADD COLUMN IF NOT EXISTS sent_group_id VARCHAR(255);
ALTER TABLE routine ADD COLUMN IF NOT EXISTS sent_group_name VARCHAR(40);
ALTER TABLE routine ADD COLUMN IF NOT EXISTS sent_group_order INTEGER;

-- 묶음 목록·묶음째 보내기마다 "이 묶음의 일과"를 묻는다
CREATE INDEX IF NOT EXISTS idx_routine_group_id ON routine (group_id);
