-- 푸시 기기 종류 구분 (이슈 #991). 추가 전용: 기존 행은 모두 보호자 기기라 NULL 그대로 둔다.
--
-- link_id: 이룸이 기기면 그 연결(device_link) ID, 보호자 기기면 NULL.
-- 이룸이 기기도 member_id 는 붙여 준 보호자라, 이 값 없이는 보호자 알림이 이룸이 기기로 샌다.
--
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE push_device ADD COLUMN IF NOT EXISTS link_id VARCHAR(255);
CREATE INDEX IF NOT EXISTS idx_push_device_link_id ON push_device (link_id);
