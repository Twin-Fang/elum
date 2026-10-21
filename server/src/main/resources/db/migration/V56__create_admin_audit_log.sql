-- 관리자 동작 기록 (이슈 #653). 추가 전용: 기존 표·컬럼은 건드리지 않는다.
--
-- 정지·해제·강제 로그아웃·Pro 발급/회수·프롬프트 저장·의견 삭제·탈퇴 계정 즉시 삭제·로그 파일 삭제 등 관리자 동작 1건이 1줄.
-- detail 은 짧은 요약만 담는다 (메모·사유·프롬프트 원문, 비밀번호·토큰은 넣지 않는다).
-- request_id 는 그 요청의 MDC requestId (서버 로그·X-Request-Id 와 같은 값), 없으면 NULL.
-- member 에 외래키를 걸지 않는다 — 탈퇴 계정을 완전히 지워도 "누가 지웠나" 기록은 남아야 한다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id             VARCHAR(255) NOT NULL PRIMARY KEY,
  admin_username VARCHAR(255) NOT NULL,
  action         VARCHAR(50)  NOT NULL,
  target_type    VARCHAR(30)  NOT NULL,
  target_id      VARCHAR(255),
  detail         VARCHAR(500),
  request_id     VARCHAR(64),
  created_at     TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at     TIMESTAMP    NOT NULL DEFAULT now()
);
-- 목록: 최신순·기간
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created_at ON admin_audit_log (created_at);
-- 대상별 (회원 상세의 '이 회원 관련 관리자 기록')
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_target ON admin_audit_log (target_type, target_id);
-- 관리자별
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin_username ON admin_audit_log (admin_username);
