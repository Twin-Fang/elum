-- 보호자가 앱에서 보낸 의견과 앱 상태 기록.
--
-- member 에 외래키를 걸지 않는다 — 탈퇴해도 관리자가 삭제할 때까지 남는다(기존 기록 테이블과 같다).
-- prod 는 ddl-auto: validate 라 Hibernate 가 테이블을 만들지 않는다. 로컬(ddl-auto: update)에서
-- 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.

CREATE TABLE IF NOT EXISTS feedback (
  id          VARCHAR(255) NOT NULL,
  member_id   VARCHAR(255) NOT NULL,
  -- 의견 원문. 2000자 검사는 서비스가 한다.
  message     TEXT         NOT NULL,
  -- 앱 상태 기록. 보내지 않으면 NULL. 64KB 검사는 서비스가 한다.
  app_log     TEXT,
  app_version VARCHAR(32),
  os          VARCHAR(64),
  created_at  TIMESTAMP(6),
  updated_at  TIMESTAMP(6),
  CONSTRAINT pk_feedback PRIMARY KEY (id)
);

-- 하루 건수 세기와 회원별 조회가 이 인덱스를 탄다.
CREATE INDEX IF NOT EXISTS idx_feedback_member_created ON feedback (member_id, created_at);
