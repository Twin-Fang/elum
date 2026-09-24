-- 탈퇴를 소프트 딜리트로 바꾼다 (이슈 #372).
--
-- V22 는 공지(#370 create_app_notice)가 먼저 썼다. 내용은 순서와 무관하게 돈다.
--
-- 탈퇴하면 계정 행을 지우지 않고 status = 'WITHDRAWN' 으로 남긴다. 완전히 지우면 같은 소셜 계정으로
-- 다시 가입해 무료 사용량을 0 부터 새로 받을 수 있어서다. withdrawn_at 은 보관 만료일의 기준이다 —
-- 보관 기간(MEMBER_WITHDRAWN_RETENTION_DAYS)이 지나면 스케줄러가 행을 완전히 지운다.
--
-- ddl-auto 로 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다 (V8 과 같은 이유).
ALTER TABLE member ADD COLUMN IF NOT EXISTS withdrawn_at TIMESTAMP(6);

-- status 는 V8 이 VARCHAR 로 만들었지만, ddl-auto 가 먼저 만든 환경에서는 Hibernate 가 enum 값 목록으로
-- check 제약(member_status_check)을 걸었을 수 있다. 그 목록에는 WITHDRAWN 이 없어 탈퇴가 통째로 실패한다.
-- 값 검사는 enum 이 한다. 없으면 아무 일도 하지 않는다.
ALTER TABLE member DROP CONSTRAINT IF EXISTS member_status_check;

-- 만료 정리 스케줄러가 매일 "탈퇴 상태이면서 탈퇴 시각이 기준 이전"인 행을 찾는다.
CREATE INDEX IF NOT EXISTS idx_member_status_withdrawn_at ON member (status, withdrawn_at);
