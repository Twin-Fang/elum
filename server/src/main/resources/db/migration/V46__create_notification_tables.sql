-- 알림 기록·푸시 기기·알림 설정·공지 확인 (이슈 #827). 추가 전용: 기존 표·컬럼은 건드리지 않는다.
--
-- 네 표 모두 member 에 외래키를 걸지 않는다 — 옛 서버 이미지의 탈퇴·완전 삭제가 이 표들을 모르고 member 를 지운다.
-- 정리는 NotificationCleanupService 가 맡는다. 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.

-- 알림 목록: (member_id, group_key) 한 줄에 같은 묶음의 발생을 모은다
CREATE TABLE IF NOT EXISTS notification (
  id               VARCHAR(255) NOT NULL PRIMARY KEY,
  member_id        VARCHAR(255) NOT NULL,
  profile_id       VARCHAR(255),
  type             VARCHAR(40)  NOT NULL,
  target_id        VARCHAR(255),
  group_key        VARCHAR(255) NOT NULL,
  subject_ids      TEXT,
  occurrence_count INTEGER      NOT NULL DEFAULT 1,
  last_occurred_at TIMESTAMP    NOT NULL,
  read_at          TIMESTAMP,
  created_at       TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at       TIMESTAMP    NOT NULL DEFAULT now(),
  CONSTRAINT uk_notification_member_group UNIQUE (member_id, group_key)
);
CREATE INDEX IF NOT EXISTS idx_notification_member_last_occurred
  ON notification (member_id, last_occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_profile_id ON notification (profile_id);

-- 푸시 받을 기기: 토큰 하나가 한 줄
CREATE TABLE IF NOT EXISTS push_device (
  id                 VARCHAR(255)  NOT NULL PRIMARY KEY,
  member_id          VARCHAR(255)  NOT NULL,
  token              VARCHAR(4096) NOT NULL,
  platform           VARCHAR(20)   NOT NULL,
  locale             VARCHAR(8)    NOT NULL DEFAULT 'ko',
  last_registered_at TIMESTAMP     NOT NULL,
  created_at         TIMESTAMP     NOT NULL DEFAULT now(),
  updated_at         TIMESTAMP     NOT NULL DEFAULT now(),
  CONSTRAINT uk_push_device_token UNIQUE (token)
);
CREATE INDEX IF NOT EXISTS idx_push_device_member_id ON push_device (member_id);

-- 알림 설정: 푸시 여부만 정한다. 행이 없으면 모두 켜짐
CREATE TABLE IF NOT EXISTS notification_setting (
  member_id                 VARCHAR(255) NOT NULL PRIMARY KEY,
  all_enabled               BOOLEAN      NOT NULL DEFAULT TRUE,
  routine_completed_enabled BOOLEAN      NOT NULL DEFAULT TRUE,
  routine_sent_enabled      BOOLEAN      NOT NULL DEFAULT TRUE,
  co_guardian_joined_enabled BOOLEAN     NOT NULL DEFAULT TRUE,
  credit_refilled_enabled   BOOLEAN      NOT NULL DEFAULT TRUE,
  feedback_resolved_enabled BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at                TIMESTAMP    NOT NULL DEFAULT now()
);

-- 공지 확인: 회원이 공지 목록을 마지막으로 본 시각
CREATE TABLE IF NOT EXISTS notice_seen (
  member_id  VARCHAR(255) NOT NULL PRIMARY KEY,
  seen_at    TIMESTAMP    NOT NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at TIMESTAMP    NOT NULL DEFAULT now()
);

-- 공지를 "다시 보이게" 고친 시각 (revision 을 올린 때). 비면 고친 적 없음
ALTER TABLE app_notice ADD COLUMN IF NOT EXISTS revised_at TIMESTAMP;
