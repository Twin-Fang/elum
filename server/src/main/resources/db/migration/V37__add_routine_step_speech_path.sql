-- 단계 음성 저장 열쇠 (#675). 형식: {stepId}/{문장 해시 16자}.wav
--
-- nullable — 아직 만들지 않았거나 만들기 실패, 한국어가 아닌 일과는 null 이다. 주기 작업이 null 을 메운다.
ALTER TABLE routine_step ADD COLUMN IF NOT EXISTS speech_path VARCHAR(255);
