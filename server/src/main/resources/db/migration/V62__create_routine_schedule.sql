-- 요일별 반복 일과 (이슈 #782, #1080). 추가 전용: 기존 표·컬럼은 건드리지 않는다.
--
-- 일과관리 원본 하나에 한 줄: 고른 요일(weekdays_mask) + 시각(time_of_day) + 이룸이 기기 알림 여부.
-- weekdays_mask: 월 1 · 화 2 · 수 4 · 목 8 · 금 16 · 토 32 · 일 64 의 합 (0 은 저장하지 않는다).
-- owner_member_id: 마지막으로 저장한 보호자. 이 보호자의 요금제(ROUTINE_SCHEDULE)로 실행 여부를 판정한다.
-- last_materialized_date / last_notified_date: 그날 오늘 일과를 만들었는가 / 알림을 보냈는가 (같은 날 두 번 막기).
-- routine·member 에 외래키를 걸지 않는다 (source_routine_id 와 같은 방식). 원본이 사라지면 실행할 때 지운다.
-- V60 은 #1083, V61 은 #1071(스토어 구독)이 쓰므로 V62 를 쓴다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.
CREATE TABLE IF NOT EXISTS routine_schedule (
  id                     VARCHAR(255) NOT NULL PRIMARY KEY,
  routine_id             VARCHAR(255) NOT NULL,
  profile_id             VARCHAR(255) NOT NULL,
  owner_member_id        VARCHAR(255) NOT NULL,
  weekdays_mask          INTEGER      NOT NULL,
  time_of_day            TIME         NOT NULL,
  is_notify_enabled      BOOLEAN      NOT NULL DEFAULT TRUE,
  last_materialized_date DATE,
  last_notified_date     DATE,
  created_at             TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at             TIMESTAMP    NOT NULL DEFAULT now()
);
-- 원본 하나에 예약 하나
CREATE UNIQUE INDEX IF NOT EXISTS uk_routine_schedule_routine_id ON routine_schedule (routine_id);
-- 이룸이별 목록 (주간 계획 · 오늘 일과 조회 때 만들기)
CREATE INDEX IF NOT EXISTS idx_routine_schedule_profile_id ON routine_schedule (profile_id);
-- 1분마다 그 시각 예약 찾기
CREATE INDEX IF NOT EXISTS idx_routine_schedule_time_of_day ON routine_schedule (time_of_day);
