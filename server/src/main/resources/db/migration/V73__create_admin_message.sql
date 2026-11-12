-- 운영자 알림 (이슈 #1273). 추가 전용: 기존 표·컬럼은 건드리지 않는다.
--
-- 관리자가 보낸 알림 한 번이 한 줄. 받는 사람마다의 알림함 줄(notification, type = ADMIN_MESSAGE)은 target_id 로 이 줄을 가리킨다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.
CREATE TABLE IF NOT EXISTS admin_message (
  id         VARCHAR(255) NOT NULL PRIMARY KEY,
  title      VARCHAR(50)  NOT NULL,
  body       VARCHAR(300) NOT NULL,
  route      VARCHAR(20)  NOT NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at TIMESTAMP    NOT NULL DEFAULT now()
);

-- notification.type 에 새 값 ADMIN_MESSAGE, admin_audit_log.action·target_type 에 새 값을 넣는다. 운영 DB 는 V47·V56 이
-- varchar 로 만들어 제약이 없지만, 로컬에서 ddl-auto 가 먼저 표를 만들었다면 Hibernate 가 그때의 enum 값 목록으로
-- CHECK 제약을 걸어 둔다 — V24 와 같은 함정이다. 값의 유효성은 코드(enum)가 지키므로 걷어낸다 (없으면 아무 일도 안 함).
DO $$
BEGIN
  IF to_regclass('public.notification') IS NOT NULL THEN
    ALTER TABLE notification DROP CONSTRAINT IF EXISTS notification_type_check;
  END IF;
  IF to_regclass('public.admin_audit_log') IS NOT NULL THEN
    ALTER TABLE admin_audit_log DROP CONSTRAINT IF EXISTS admin_audit_log_action_check;
    ALTER TABLE admin_audit_log DROP CONSTRAINT IF EXISTS admin_audit_log_target_type_check;
  END IF;
END $$;
