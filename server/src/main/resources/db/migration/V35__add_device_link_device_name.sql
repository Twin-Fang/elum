-- 이룸이 휴대폰의 기기 이름("iPhone 16"). 연결할 때 앱이 모델명만 보낸다.
--
-- 추가만 한다(NULL 허용, 기본값 없음). 옛 앱은 이름을 보내지 않고 기존 행도 비어 있으며,
-- 옛 서버 이미지로 되돌려도 이 컬럼을 모르고 동작한다. IF NOT EXISTS 로 로컬(ddl-auto: update)과 양립한다.
ALTER TABLE device_link ADD COLUMN IF NOT EXISTS device_name VARCHAR(60);
