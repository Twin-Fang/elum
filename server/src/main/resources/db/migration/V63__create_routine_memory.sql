-- 이룸이별 AI 메모 (이슈 #1082, Pro). 추가 전용: 기존 표·컬럼의 뜻은 바꾸지 않는다.
--
-- routine.ai_draft_cards: AI 가 처음 만든 카드 글 스냅샷 (JSON 배열 [{"title","description"}]).
--   Pro + AI 메모 켜짐일 때 만든 일과에만 남는다. 보호자 입력 원문은 넣지 않는다 (카드 글만).
--   일과를 지우면 행과 함께 사라진다. 보호자가 메모를 모두 지우면 NULL 로 비운다.
-- routine.memory_reflected_at: 이 일과의 "처음 > 확정" 차이를 메모에 반영한(또는 건너뛴) 시각. NULL 이면 아직.
--
-- routine_memory: 이룸이 1명당 1행. lines 는 JSON 배열 [{"text","source"}] (source: AI | GUARDIAN, 최대 10줄),
--   dismissed_lines 는 보호자가 지운 AI 줄(다시 만들지 않게, 최대 20개). 진단·장애·정도 표현은 서버가 걸러 저장하지 않는다.
--   이룸이를 지우면 함께 지운다 (ON DELETE CASCADE, 서비스도 직접 지움).
--
-- 옛 서버 이미지로 되돌려도 새 컬럼·표를 모른 채 그대로 동작한다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.
ALTER TABLE routine ADD COLUMN IF NOT EXISTS ai_draft_cards TEXT;
ALTER TABLE routine ADD COLUMN IF NOT EXISTS memory_reflected_at TIMESTAMP(6);

-- 메모 갱신 대상 찾기: 스냅샷이 있고 아직 반영 안 한 일과만 (대부분의 행은 빠지는 부분 색인)
CREATE INDEX IF NOT EXISTS idx_routine_memory_pending
  ON routine (profile_id) WHERE ai_draft_cards IS NOT NULL AND memory_reflected_at IS NULL;

CREATE TABLE IF NOT EXISTS routine_memory (
  id              VARCHAR(255) NOT NULL PRIMARY KEY,
  profile_id      VARCHAR(255) NOT NULL REFERENCES profile (id) ON DELETE CASCADE,
  enabled         BOOLEAN      NOT NULL DEFAULT TRUE,
  lines           TEXT         NOT NULL DEFAULT '[]',
  dismissed_lines TEXT         NOT NULL DEFAULT '[]',
  last_built_at   TIMESTAMP(6),
  created_at      TIMESTAMP(6) NOT NULL DEFAULT now(),
  updated_at      TIMESTAMP(6) NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_routine_memory_profile_id ON routine_memory (profile_id);
