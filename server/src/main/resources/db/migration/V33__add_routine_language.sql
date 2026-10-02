-- 일과의 콘텐츠 언어 (다국어 #526, 계획 2).
--
-- 일과를 만든 요청의 화면 언어를 켜진 언어 목록(system_config ENABLED_CONTENT_LOCALES)에 비춰 정해 일과에 저장한다.
-- 보호자가 고르지 않는다. 카드 글과 음성이 이 값을 따른다.
-- 기존 일과는 모두 한국어로 만들어졌으므로 DEFAULT 'ko' 로 채운다.
--
-- 추가만 한다 (V25 원칙). 옛 서버 이미지는 이 컬럼을 모르고 routine 을 INSERT 하므로 NOT NULL 에는 반드시 DEFAULT 가 있어야 한다.
-- 운영은 ddl-auto: validate 라 이 마이그레이션이 없으면 Routine 엔티티가 language 를 읽다가 서버가 뜨지 않는다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE routine ADD COLUMN IF NOT EXISTS language VARCHAR(8) NOT NULL DEFAULT 'ko';
