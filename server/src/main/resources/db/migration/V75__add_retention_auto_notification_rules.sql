-- 리텐션 자동 알림 4종 (#1409). 추가 전용: 기존 표·컬럼은 건드리지 않는다.
-- 제목·본문은 한국어 틀 (관리자가 고침). 다른 언어는 i18n/push-messages_{언어}.properties 의 push.auto.{종류}.title/body
-- route: AdminMessageRoute 이름 (DEVICE_LINK 는 앱이 모르면 홈으로 감). send_hour·send_minute: 한국 시각

-- 새 enum 값(종류 4개, 화면 DEVICE_LINK): 로컬 ddl-auto 가 표를 먼저 만들었으면 enum CHECK 제약이 있어 걷어냄 (V73·V74 와 같음)
DO $$
BEGIN
  IF to_regclass('public.auto_notification_rule') IS NOT NULL THEN
    ALTER TABLE auto_notification_rule DROP CONSTRAINT IF EXISTS auto_notification_rule_type_check;
    ALTER TABLE auto_notification_rule DROP CONSTRAINT IF EXISTS auto_notification_rule_route_check;
  END IF;
  IF to_regclass('public.notification_dispatch') IS NOT NULL THEN
    ALTER TABLE notification_dispatch DROP CONSTRAINT IF EXISTS notification_dispatch_auto_type_check;
  END IF;
  IF to_regclass('public.admin_message') IS NOT NULL THEN
    ALTER TABLE admin_message DROP CONSTRAINT IF EXISTS admin_message_route_check;
  END IF;
  IF to_regclass('public.scheduled_admin_push') IS NOT NULL THEN
    ALTER TABLE scheduled_admin_push DROP CONSTRAINT IF EXISTS scheduled_admin_push_route_check;
  END IF;
END $$;

-- 처음엔 모두 꺼 둔다 (문구 검토 후 관리자가 켬, V74 와 같음)
-- min_interval_days: 첫 일과 만들기 2 (가입 1일째·3일째 한 번씩), 보낸 일과 시작 전 1, 연속 기록 1, 기기 연결 90 (사실상 한 번)
INSERT INTO auto_notification_rule (type, enabled, title_template, body_template, route, send_hour, send_minute, min_interval_days)
VALUES
  ('ONBOARDED_NO_ROUTINE', FALSE, '✏️ {아이이름}의 첫 일과를 만들어 볼까요?', '하고 싶은 일을 한 줄로 적으면 카드로 만들어 드려요', 'HOME', 10, 0, 2),
  ('SENT_NOT_DONE', FALSE, '🌙 오늘 보낸 {일과}, 아직 시작 전이에요', '{아이이름}에게 함께 해 보자고 말해 주세요', 'HOME', 19, 0, 1),
  ('STREAK_AT_RISK', FALSE, '🔥 {아이이름}의 연속 기록이 이어지고 있어요', '오늘도 일과 하나를 마치면 기록이 이어져요', 'HOME', 18, 0, 1),
  ('LINK_PENDING', FALSE, '📱 {아이이름}의 기기를 연결해 볼까요?', '연결하면 보낸 일과가 이룸이 기기에 바로 도착해요', 'DEVICE_LINK', 11, 0, 90)
ON CONFLICT (type) DO NOTHING;
