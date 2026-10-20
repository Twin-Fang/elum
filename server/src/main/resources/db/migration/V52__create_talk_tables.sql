-- 이야기(보호자 커뮤니티) 표 일곱 개와 기존 표의 컬럼 넷 (이슈 #913). 추가 전용: 기존 표·컬럼은 건드리지 않는다.
--
-- 일곱 표 모두 member·routine 에 외래키를 걸지 않는다 — 옛 서버 이미지의 탈퇴·완전 삭제가 이 표들을 모르고 member 를 지운다.
-- 기존 표에 더하는 컬럼은 NULL 허용이거나 DEFAULT 가 있다 — 옛 서버의 INSERT 가 이 컬럼을 몰라도 깨지지 않는다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.

-- 글: 보호자가 나눈 일과 1건. 집계 3개는 서비스가 증감한다
CREATE TABLE IF NOT EXISTS talk_post (
  id               VARCHAR(255) NOT NULL PRIMARY KEY,
  author_member_id VARCHAR(255) NOT NULL,
  source_routine_id VARCHAR(255),
  title            VARCHAR(100) NOT NULL,
  note             TEXT,
  category         VARCHAR(20)  NOT NULL,
  language         VARCHAR(8)   NOT NULL DEFAULT 'ko',
  step_count       INTEGER      NOT NULL DEFAULT 0,
  status           VARCHAR(20)  NOT NULL DEFAULT 'VISIBLE',
  helpful_count    INTEGER      NOT NULL DEFAULT 0,
  comment_count    INTEGER      NOT NULL DEFAULT 0,
  import_count     INTEGER      NOT NULL DEFAULT 0,
  created_at       TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at       TIMESTAMP    NOT NULL DEFAULT now()
);
-- 목록: 보이는 글을 언어(·분류)별 최신순
CREATE INDEX IF NOT EXISTS idx_talk_post_status_language_created
  ON talk_post (status, language, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_talk_post_status_language_category_created
  ON talk_post (status, language, category, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_talk_post_author_member_id ON talk_post (author_member_id);
CREATE INDEX IF NOT EXISTS idx_talk_post_source_routine_id ON talk_post (source_routine_id);
-- 같은 원본 일과로 보이는 글은 하나만 (동시 두 번 올리기 방지, JPA @Index 로는 부분 인덱스를 못 씀)
CREATE UNIQUE INDEX IF NOT EXISTS uk_talk_post_visible_source
  ON talk_post (source_routine_id) WHERE status = 'VISIBLE';

-- 글의 카드: 올릴 때의 스냅샷 (원본 일과를 고쳐도 글은 그대로)
CREATE TABLE IF NOT EXISTS talk_post_step (
  id                VARCHAR(255) NOT NULL PRIMARY KEY,
  post_id           VARCHAR(255) NOT NULL,
  step_order        INTEGER      NOT NULL,
  title             TEXT,
  description       TEXT         NOT NULL,
  image_key         VARCHAR(255),
  pictogram_id      VARCHAR(100),
  example_image_id  VARCHAR(100),
  is_blurred        BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at        TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_talk_post_step_post_order ON talk_post_step (post_id, step_order);

-- 댓글
CREATE TABLE IF NOT EXISTS talk_comment (
  id               VARCHAR(255) NOT NULL PRIMARY KEY,
  post_id          VARCHAR(255) NOT NULL,
  author_member_id VARCHAR(255) NOT NULL,
  body             TEXT         NOT NULL,
  status           VARCHAR(20)  NOT NULL DEFAULT 'VISIBLE',
  created_at       TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at       TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_talk_comment_post_created ON talk_comment (post_id, created_at);

-- 도움이 됐어요: 한 글에 한 사람이 한 번
CREATE TABLE IF NOT EXISTS talk_helpful (
  id         VARCHAR(255) NOT NULL PRIMARY KEY,
  post_id    VARCHAR(255) NOT NULL,
  member_id  VARCHAR(255) NOT NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at TIMESTAMP    NOT NULL DEFAULT now(),
  CONSTRAINT uk_talk_helpful_post_member UNIQUE (post_id, member_id)
);

-- 가져간 기록: 누가 어느 프로필의 어떤 일과로 가져갔는가
CREATE TABLE IF NOT EXISTS talk_import (
  id         VARCHAR(255) NOT NULL PRIMARY KEY,
  post_id    VARCHAR(255) NOT NULL,
  member_id  VARCHAR(255) NOT NULL,
  profile_id VARCHAR(255) NOT NULL,
  routine_id VARCHAR(255) NOT NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_talk_import_post_created ON talk_import (post_id, created_at);

-- 신고: 한 대상에 한 사람이 한 번. resolved_at 이 비면 미처리
CREATE TABLE IF NOT EXISTS talk_report (
  id                 VARCHAR(255) NOT NULL PRIMARY KEY,
  target_type        VARCHAR(20)  NOT NULL,
  target_id          VARCHAR(255) NOT NULL,
  post_id            VARCHAR(255) NOT NULL,
  reporter_member_id VARCHAR(255) NOT NULL,
  reason             VARCHAR(20)  NOT NULL,
  resolved_at        TIMESTAMP,
  created_at         TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at         TIMESTAMP    NOT NULL DEFAULT now(),
  CONSTRAINT uk_talk_report_target_reporter UNIQUE (target_type, target_id, reporter_member_id)
);

-- 차단: 차단한 사람 > 차단당한 사람
CREATE TABLE IF NOT EXISTS talk_block (
  id                VARCHAR(255) NOT NULL PRIMARY KEY,
  blocker_member_id VARCHAR(255) NOT NULL,
  blocked_member_id VARCHAR(255) NOT NULL,
  created_at        TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at        TIMESTAMP    NOT NULL DEFAULT now(),
  CONSTRAINT uk_talk_block_blocker_blocked UNIQUE (blocker_member_id, blocked_member_id)
);

-- 이야기에서 가져와 만든 일과면 그 글 ID. 비면 가져오지 않은 일과
ALTER TABLE routine ADD COLUMN IF NOT EXISTS talk_post_id VARCHAR(255);

-- 이야기 이용 규칙에 동의한 시각. 비면 동의 전
ALTER TABLE member ADD COLUMN IF NOT EXISTS talk_rules_agreed_at TIMESTAMP;

-- 이야기 푸시 설정 둘: 댓글, 가져감. 기존 행은 켜짐
ALTER TABLE notification_setting
  ADD COLUMN IF NOT EXISTS talk_commented_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE notification_setting
  ADD COLUMN IF NOT EXISTS talk_imported_enabled BOOLEAN NOT NULL DEFAULT TRUE;
