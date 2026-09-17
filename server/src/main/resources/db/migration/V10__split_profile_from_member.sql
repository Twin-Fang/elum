-- 로그인 계정(member)에서 당사자 정보를 profile로 떼어낸다.
--
-- 한 테이블에 섞여 있으면 당사자 기기가 서버에 접속하려고 보호자의
-- 아이디·비밀번호를 써야 한다. 그 기기를 잃어버리면 계정 전체가 열린다.
-- 보호자와 당사자가 각자 기기를 쓰려면 먼저 이 둘이 갈라져야 한다.
--
-- 기존 데이터는 1:1로 옮긴다. member 한 줄 → profile 한 줄.

CREATE TABLE profile (
    id          VARCHAR(255) PRIMARY KEY,
    member_id   VARCHAR(255) NOT NULL REFERENCES member (id),
    nickname    VARCHAR(255),
    character   VARCHAR(255),
    total_stars INTEGER      NOT NULL DEFAULT 0,
    created_at  TIMESTAMP,
    updated_at  TIMESTAMP
);

CREATE INDEX idx_profile_member ON profile (member_id);

CREATE TABLE profile_support_goals (
    profile_id   VARCHAR(255) NOT NULL REFERENCES profile (id),
    support_goal VARCHAR(255) NOT NULL
);

CREATE INDEX idx_profile_support_goals ON profile_support_goals (profile_id);

-- 기존 회원마다 프로필 하나를 만든다
INSERT INTO profile (id, member_id, nickname, character, total_stars, created_at, updated_at)
SELECT gen_random_uuid()::text, id, nickname, character, COALESCE(total_stars, 0), created_at, updated_at
FROM member;

INSERT INTO profile_support_goals (profile_id, support_goal)
SELECT p.id, g.support_goal
FROM member_support_goals g
         JOIN profile p ON p.member_id = g.member_id;

-- 일과를 프로필에 연결한다. 일과는 계정이 아니라 당사자에게 속한다.
ALTER TABLE routine ADD COLUMN profile_id VARCHAR(255);

UPDATE routine r
SET profile_id = (SELECT p.id FROM profile p WHERE p.member_id = r.member_id);

-- 프로필이 없는 일과가 남으면 NOT NULL을 걸 수 없다. 남아 있다면 데이터가
-- 어긋난 것이므로 여기서 멈추는 편이 낫다.
ALTER TABLE routine ALTER COLUMN profile_id SET NOT NULL;
ALTER TABLE routine ADD CONSTRAINT fk_routine_profile FOREIGN KEY (profile_id) REFERENCES profile (id);
CREATE INDEX idx_routine_profile ON routine (profile_id);

-- 옮긴 컬럼을 정리한다
ALTER TABLE routine DROP COLUMN member_id;

DROP TABLE member_support_goals;
ALTER TABLE member DROP COLUMN nickname;
ALTER TABLE member DROP COLUMN character;
ALTER TABLE member DROP COLUMN total_stars;
