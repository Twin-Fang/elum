-- 보호자 닉네임 (이슈 #849). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- member.nickname: 가입 시 서버가 자동 생성(형용사+명사-4자리). 겹치지 않아야 한다(유니크).
--   기존 회원 값은 서버 기동 시 MemberNicknameBackfill 이 채운다 — 생성기가 Java 라이브러리라 SQL 로 못 채움.
--   그래서 NOT NULL 은 걸지 않는다. Postgres 유니크 인덱스는 NULL 여럿을 허용한다.
--
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE member ADD COLUMN IF NOT EXISTS nickname VARCHAR(50);
CREATE UNIQUE INDEX IF NOT EXISTS uk_member_nickname ON member (nickname);
