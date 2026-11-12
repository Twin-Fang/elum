-- 알림 고도화 (#1275): 자동 알림 규칙, 예약 발송, 발송·열림 기록, 종류별 끄기. 추가 전용: 기존 표·컬럼은 건드리지 않는다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.

-- 자동 알림 규칙: 종류마다 한 줄. 관리자 화면에서 켜고 끄고 문구·시각·간격을 고친다 (다시 배포 없이 반영)
-- route: AdminMessageRoute 이름 (HOME, PLAN, MY_CREDIT). send_hour·send_minute: 한국 시각
-- last_run_date: 그날 이미 돌았는지 (인스턴스가 둘이어도 하루 한 번만 선점)
CREATE TABLE IF NOT EXISTS auto_notification_rule (
  type              VARCHAR(40)  NOT NULL PRIMARY KEY,
  enabled           BOOLEAN      NOT NULL DEFAULT FALSE,
  title_template    VARCHAR(50)  NOT NULL,
  body_template     VARCHAR(300) NOT NULL,
  route             VARCHAR(20)  NOT NULL,
  send_hour         INTEGER      NOT NULL,
  send_minute       INTEGER      NOT NULL,
  min_interval_days INTEGER      NOT NULL,
  last_run_date     DATE,
  updated_by        VARCHAR(100),
  created_at        TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at        TIMESTAMP    NOT NULL DEFAULT now()
);

-- 처음엔 모두 꺼 둔다 (문구 검토 후 관리자가 켬). 오늘 일과 보내기는 08:00: 야간(21~08시) 금지와 맞춤
INSERT INTO auto_notification_rule (type, enabled, title_template, body_template, route, send_hour, send_minute, min_interval_days)
VALUES
  ('DAILY_ROUTINE_NUDGE', FALSE, '🌤️ 오늘 {일과}도 {아이이름}에게 보내 줄까요?', '눌러서 오늘 일과를 보내 보세요', 'HOME', 8, 0, 1),
  ('COMEBACK', FALSE, '✨ 이번 주 {아이이름}에게 새 일과를 만들어 볼까요?', '이야기에 다른 보호자들의 일과도 올라와 있어요', 'HOME', 10, 0, 7),
  ('TALK_POPULAR', FALSE, '📚 다른 보호자들이 많이 담은 일과가 올라왔어요', '이야기에서 인기 일과를 둘러보세요', 'HOME', 11, 0, 7),
  ('PRO_GIFT_ENDING', FALSE, '🎁 Pro 선물이 {날짜}에 끝나요', '계속 쓰시려면 요금제를 확인해 주세요', 'PLAN', 10, 0, 30),
  ('FIRST_ROUTINE_DONE', FALSE, '🎉 {아이이름}이 첫 일과를 끝냈어요!', '눌러서 오늘 한 일을 확인해 보세요', 'HOME', 8, 0, 1)
ON CONFLICT (type) DO NOTHING;

-- 예약 발송: 관리자가 정한 시각에 운영자 알림 보내기 (#1273 과 같은 받는 사람 고르기)
-- status: PENDING 기다림, SENDING 보내는 중(선점), SENT 보냄, CANCELED 취소, FAILED 실패
-- target_mode: MEMBERS(member_ids 쉼표 목록) 또는 CONDITION(joined_on_or_before + minimum_ai_call_count)
CREATE TABLE IF NOT EXISTS scheduled_admin_push (
  id                    VARCHAR(255) NOT NULL PRIMARY KEY,
  title                 VARCHAR(50)  NOT NULL,
  body                  VARCHAR(300) NOT NULL,
  route                 VARCHAR(20)  NOT NULL,
  target_mode           VARCHAR(20)  NOT NULL,
  member_ids            TEXT,
  joined_on_or_before   DATE,
  minimum_ai_call_count INTEGER,
  scheduled_at          TIMESTAMP    NOT NULL,
  status                VARCHAR(20)  NOT NULL,
  admin_message_id      VARCHAR(255),
  recipient_count       INTEGER,
  recorded_count        INTEGER,
  sent_device_count     INTEGER,
  failed_device_count   INTEGER,
  failure_reason        VARCHAR(100),
  created_by            VARCHAR(100),
  processed_at          TIMESTAMP,
  created_at            TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at            TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_scheduled_admin_push_status_at ON scheduled_admin_push (status, scheduled_at);

-- 발송 기록: 받는 사람마다 한 줄 (자동·운영자 직접·예약 공통). 푸시 data 의 dispatchId 가 이 id
-- source: AUTO_RULE, ADMIN_MANUAL, ADMIN_SCHEDULED. auto_type: 자동 알림 종류 (자동만)
-- opened_at: 앱이 그 알림을 눌러 열었다고 알린 첫 시각
CREATE TABLE IF NOT EXISTS notification_dispatch (
  id                  VARCHAR(255) NOT NULL PRIMARY KEY,
  member_id           VARCHAR(255) NOT NULL,
  source              VARCHAR(20)  NOT NULL,
  auto_type           VARCHAR(40),
  admin_message_id    VARCHAR(255),
  sent_at             TIMESTAMP    NOT NULL,
  sent_device_count   INTEGER      NOT NULL DEFAULT 0,
  failed_device_count INTEGER      NOT NULL DEFAULT 0,
  opened_at           TIMESTAMP,
  created_at          TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at          TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notification_dispatch_member_sent ON notification_dispatch (member_id, sent_at);
CREATE INDEX IF NOT EXISTS idx_notification_dispatch_sent_at ON notification_dispatch (sent_at);

-- 종류별 끄기 3개 (기본 켜짐): 오늘 일과 보내기, 추천(다시 찾기·이야기 인기), 요금제 안내(Pro 선물 끝나기 전)
ALTER TABLE notification_setting
  ADD COLUMN IF NOT EXISTS routine_nudge_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE notification_setting
  ADD COLUMN IF NOT EXISTS suggestion_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE notification_setting
  ADD COLUMN IF NOT EXISTS plan_reminder_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- admin_audit_log.action·target_type 새 값: V73 이 로컬 CHECK 제약을 이미 걷어냈지만, 그 뒤 ddl-auto 가 다시 걸었을 수 있어 한 번 더
DO $$
BEGIN
  IF to_regclass('public.admin_audit_log') IS NOT NULL THEN
    ALTER TABLE admin_audit_log DROP CONSTRAINT IF EXISTS admin_audit_log_action_check;
    ALTER TABLE admin_audit_log DROP CONSTRAINT IF EXISTS admin_audit_log_target_type_check;
  END IF;
END $$;
