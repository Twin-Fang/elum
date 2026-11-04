-- AI 호출 기록에 키 별명 (이슈 #1083). Claude 키가 여러 개라 어느 키가 응답·실패했는지 남긴다.
-- key_label: 관리자가 붙인 키 별명 (예: 회사 키). 키 값은 넣지 않는다. 키가 하나뿐인 제공자(Gemini·OpenAI)는 NULL.
--
-- 더하는 것만 한다. 옛 서버 이미지로 되돌려도 이 컬럼을 모른 채 읽고 쓴다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE ai_call_log ADD COLUMN IF NOT EXISTS key_label VARCHAR(100);
