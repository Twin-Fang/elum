-- 카드 그림 고쳐서 다시 그리기 (이슈 #1110). 새 그림을 바로 바꾸지 않고 보호자가 원래 그림과 나란히 보고 고른다.
-- image_candidate_path: 고르기 전 새 그림 열쇠 {stepId}/ai-{UUID}.{확장자}. 고르거나 버리면 NULL.
--
-- 더하는 것만 한다. 옛 서버 이미지로 되돌려도 이 컬럼을 모른 채 읽고 쓴다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE routine_step ADD COLUMN IF NOT EXISTS image_candidate_path VARCHAR(255);
