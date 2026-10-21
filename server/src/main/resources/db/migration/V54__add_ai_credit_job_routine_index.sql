-- 일과별 크레딧 작업 조회 인덱스 (이슈 #652). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- 관리자 일과 상세의 "이 일과의 AI 작업" 카드가 routine_id 로 최근 작업 50건을 읽는다.
-- 인덱스가 없으면 일과 상세를 열 때마다 ai_credit_job 전체를 훑는다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
CREATE INDEX IF NOT EXISTS idx_ai_credit_job_routine_started ON ai_credit_job (routine_id, started_at);
