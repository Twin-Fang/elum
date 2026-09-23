-- 보호자 홈 공지 팝업 (이슈 #370).
--
-- 베타 AI 한도·이벤트·업데이트 안내를 보호자에게 미리 알릴 통로가 없었다. 점검 모드는 앱을
-- 통째로 막고, 강제 업데이트는 버전 안내뿐이다. 관리자가 올리고 보호자 홈에서 슬라이드로 뜬다.
--
-- ⚠️ 번호는 머지 순서대로 잡는다. 다중 보호자 1단계(#360)도 V22 를 쓰려 한다 — 먼저 머지되는
--    쪽이 V22 이고 나머지는 다음 번호로 파일 이름을 바꾼다. 내용은 서로 겹치지 않는다.
--
-- prod 는 ddl-auto: validate 라 Hibernate 가 테이블을 만들지 않는다. 로컬(ddl-auto: update)에서
-- 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
--
-- 보지 않기 일수는 여기 두지 않는다. 팝업 하나에 체크박스가 하나라 공지마다 다르면 설명할 수
-- 없다 — 시스템 설정 NOTICE_HIDE_DAYS 하나로 둔다(SystemConfigInitializer 가 채운다).

CREATE TABLE IF NOT EXISTS app_notice (
  id           VARCHAR(255)  NOT NULL,
  -- **강조** 표기를 그대로 담는다. 길이는 표기까지 센다.
  title        VARCHAR(40)   NOT NULL,
  -- 줄바꿈은 LF 로 담는다.
  body         VARCHAR(1000) NOT NULL,
  -- 저장소 열쇠(공지아이디/임의값.확장자). 경로가 아니다. 없으면 글만 있는 공지.
  image_key    VARCHAR(255),
  -- 문구와 링크는 둘 다 있거나 둘 다 없다. 링크는 https 만. 검증은 서버 코드가 한다.
  button_label VARCHAR(20),
  button_url   VARCHAR(500),
  -- ALL, IOS, ANDROID
  platform     VARCHAR(20)   NOT NULL,
  -- 클수록 먼저. 같으면 starts_at 이 늦은 것이 먼저.
  priority     INTEGER       NOT NULL DEFAULT 0,
  -- "다시 보이게" 저장마다 +1. 앱의 숨김 기록과 값이 다르면 다시 뜬다.
  revision     INTEGER       NOT NULL DEFAULT 1,
  -- 한국 시각. ends_at 이 NULL 이면 끌 때까지. [starts_at, ends_at) 동안 게시한다.
  starts_at    TIMESTAMP(6)  NOT NULL,
  ends_at      TIMESTAMP(6),
  -- 기간과 별개로 관리자가 켜고 끈다.
  enabled      BOOLEAN       NOT NULL,
  created_by   VARCHAR(255)  NOT NULL,
  updated_by   VARCHAR(255)  NOT NULL,
  created_at   TIMESTAMP(6),
  updated_at   TIMESTAMP(6),
  CONSTRAINT pk_app_notice PRIMARY KEY (id)
);
