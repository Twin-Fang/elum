-- 회원 하루 방문 기록 (관리자 방문 추이). 추가 전용: 기존 표·컬럼은 건드리지 않는다.
--
-- member 에 외래키를 걸지 않는다 — 옛 서버 이미지의 탈퇴·완전 삭제가 이 표를 모르고 member 를 지운다(V47 과 같다).
-- 탈퇴할 때 MemberService 가 그 회원 줄을 지운다 (방침 보관 항목이 아님).
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.
CREATE TABLE IF NOT EXISTS member_daily_visit (
  id         VARCHAR(255) NOT NULL PRIMARY KEY,
  member_id  VARCHAR(255) NOT NULL,
  visit_date DATE         NOT NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at TIMESTAMP    NOT NULL DEFAULT now(),
  CONSTRAINT uk_member_daily_visit_member_date UNIQUE (member_id, visit_date)
);
CREATE INDEX IF NOT EXISTS idx_member_daily_visit_date ON member_daily_visit (visit_date);

-- 첫 줄: 오늘 이미 활동한 회원 (배포 당일 방문 수가 0부터 시작하지 않게). 두 번 돌아도 고유 제약으로 무시된다.
INSERT INTO member_daily_visit (id, member_id, visit_date)
SELECT md5(id || ':' || CAST(CURRENT_DATE AS TEXT)), id, CURRENT_DATE
FROM member
WHERE last_activity_at >= CURRENT_DATE
  AND status <> 'WITHDRAWN'
ON CONFLICT (member_id, visit_date) DO NOTHING;
