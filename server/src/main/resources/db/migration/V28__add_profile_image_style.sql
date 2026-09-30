-- 이룸이(profile)별 카드 그림 방식 (#457): CARTOON(만화, 기본) · REALISTIC(실사) · PHOTO_ONLY(직접 사진).
--
-- 운영은 ddl-auto: validate 라 Hibernate 가 컬럼을 만들지 않는다. 이 마이그레이션이 없으면 Profile 엔티티가
-- image_style 을 읽다가 서버가 뜨지 않는다.
--
-- 추가만 한다 (V25 원칙). 배포 뒤 옛 서버 이미지로 되돌려도 이 스키마 위에서 옛 코드가 돌아야 한다.
-- 옛 코드는 image_style 을 모르고 profile 을 INSERT 하므로 NOT NULL 컬럼에는 반드시 DEFAULT 가 있어야 한다.
-- 기존 행도 DEFAULT 로 CARTOON 이 채워져 지금 동작이 그대로다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE profile ADD COLUMN IF NOT EXISTS image_style VARCHAR(20) NOT NULL DEFAULT 'CARTOON';
