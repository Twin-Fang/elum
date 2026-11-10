-- AI 메모리 (보호자 한 사람 x 이룸이 한 명의 규칙). 추가 전용: 옛 routine_memory 표는 그대로 두고 쓰지 않는다.
-- 옛 표의 데이터는 옮기지 않는다 (기능이 운영에서 꺼져 있어 비어 있다고 본다).
-- routine.ai_draft_cards / routine.memory_reflected_at (V63) 은 그대로 쓴다.
--
-- routine_memory_setting: (이룸이, 보호자)별 켜짐. 행이 없으면 켜짐
-- routine_memory_rule: 규칙. type WORD|SPLIT|MERGE|ADD|REMOVE|MANUAL, status ACTIVE|WATCHING|OFF, source AI|MANUAL
-- routine_memory_evidence: 규칙을 뒷받침한 일과 (규칙마다 일과 하나는 한 번만 셈)
-- routine_memory_edit: 일과마다 한 줄의 수정 기록 (AI 없이 서버가 셈). extraction_state PENDING|DONE|FAILED
-- routine_memory_rejection: 보호자가 지운 규칙 (같은 수정을 AI 가 다시 가져와도 되살리지 않음)
-- 이룸이·보호자가 지워지면 DB 가 함께 지운다 (ON DELETE CASCADE).
CREATE TABLE IF NOT EXISTS routine_memory_setting (
  id          VARCHAR(255) NOT NULL PRIMARY KEY,
  profile_id  VARCHAR(255) NOT NULL REFERENCES profile (id) ON DELETE CASCADE,
  member_id   VARCHAR(255) NOT NULL REFERENCES member (id) ON DELETE CASCADE,
  enabled     BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMP(6),
  updated_at  TIMESTAMP(6)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_routine_memory_setting_owner ON routine_memory_setting (profile_id, member_id);

CREATE TABLE IF NOT EXISTS routine_memory_rule (
  id              VARCHAR(255) NOT NULL PRIMARY KEY,
  profile_id      VARCHAR(255) NOT NULL REFERENCES profile (id) ON DELETE CASCADE,
  member_id       VARCHAR(255) NOT NULL REFERENCES member (id) ON DELETE CASCADE,
  type            VARCHAR(20)  NOT NULL,
  status          VARCHAR(20)  NOT NULL,
  source          VARCHAR(20)  NOT NULL,
  summary         VARCHAR(255) NOT NULL,
  before_text     VARCHAR(255),
  after_text      VARCHAR(255),
  evidence_count  INTEGER      NOT NULL DEFAULT 0,
  created_at      TIMESTAMP(6),
  updated_at      TIMESTAMP(6)
);
CREATE INDEX IF NOT EXISTS idx_routine_memory_rule_owner ON routine_memory_rule (profile_id, member_id);

CREATE TABLE IF NOT EXISTS routine_memory_evidence (
  id             VARCHAR(255) NOT NULL PRIMARY KEY,
  rule_id        VARCHAR(255) NOT NULL REFERENCES routine_memory_rule (id) ON DELETE CASCADE,
  routine_id     VARCHAR(255) NOT NULL,
  routine_title  VARCHAR(255),
  observed_at    TIMESTAMP(6) NOT NULL,
  created_at     TIMESTAMP(6),
  updated_at     TIMESTAMP(6)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_routine_memory_evidence_rule_routine ON routine_memory_evidence (rule_id, routine_id);
CREATE INDEX IF NOT EXISTS idx_routine_memory_evidence_routine ON routine_memory_evidence (routine_id);

CREATE TABLE IF NOT EXISTS routine_memory_edit (
  id                   VARCHAR(255) NOT NULL PRIMARY KEY,
  profile_id           VARCHAR(255) NOT NULL REFERENCES profile (id) ON DELETE CASCADE,
  member_id            VARCHAR(255) NOT NULL REFERENCES member (id) ON DELETE CASCADE,
  routine_id           VARCHAR(255) NOT NULL,
  routine_title        VARCHAR(255),
  edited_at            TIMESTAMP(6) NOT NULL,
  card_count_before    INTEGER      NOT NULL,
  card_count_after     INTEGER      NOT NULL,
  changed_text_count   INTEGER      NOT NULL,
  extraction_state     VARCHAR(20)  NOT NULL,
  created_at           TIMESTAMP(6),
  updated_at           TIMESTAMP(6)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_routine_memory_edit_routine ON routine_memory_edit (routine_id);
CREATE INDEX IF NOT EXISTS idx_routine_memory_edit_owner ON routine_memory_edit (profile_id, member_id, edited_at);

CREATE TABLE IF NOT EXISTS routine_memory_rejection (
  id           VARCHAR(255) NOT NULL PRIMARY KEY,
  profile_id   VARCHAR(255) NOT NULL REFERENCES profile (id) ON DELETE CASCADE,
  member_id    VARCHAR(255) NOT NULL REFERENCES member (id) ON DELETE CASCADE,
  type         VARCHAR(20)  NOT NULL,
  before_text  VARCHAR(255),
  after_text   VARCHAR(255),
  created_at   TIMESTAMP(6),
  updated_at   TIMESTAMP(6)
);
CREATE INDEX IF NOT EXISTS idx_routine_memory_rejection_owner ON routine_memory_rejection (profile_id, member_id);
