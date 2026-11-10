-- 주간 리포트 정리 글 (끝난 주 한 번 만들어 저장). 추가 전용: 기존 표·컬럼은 건드리지 않는다.
--
-- lines: JSON 배열 [문장] (최대 3줄). 이룸이 이름은 {userName} 자리표시로 저장하고 응답할 때 끼워 넣는다.
-- source: AI | FALLBACK. 유일 키 (이룸이, 주 시작 월요일, 언어) — 한 번 만들면 다시 만들지 않는다.
-- 이룸이를 지우면 함께 지운다 (ON DELETE CASCADE, 서비스도 직접 지움).
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.
CREATE TABLE IF NOT EXISTS weekly_report_summary (
  id         VARCHAR(255) NOT NULL PRIMARY KEY,
  profile_id VARCHAR(255) NOT NULL REFERENCES profile (id) ON DELETE CASCADE,
  week_start DATE         NOT NULL,
  language   VARCHAR(8)   NOT NULL,
  lines      TEXT         NOT NULL,
  source     VARCHAR(16)  NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT now(),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_weekly_report_summary_profile_week_language
  ON weekly_report_summary (profile_id, week_start, language);
