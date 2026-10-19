-- 온보딩 예시 일과 표시 (이슈 #803). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- is_example: 온보딩에서 고른 분류로 넣은 예시 일과면 TRUE. 기존 일과는 전부 FALSE.
-- 홈 '예시' 표시와 보유 일과 한도 집계 제외에 쓴다.
--
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE routine ADD COLUMN IF NOT EXISTS is_example BOOLEAN NOT NULL DEFAULT FALSE;
