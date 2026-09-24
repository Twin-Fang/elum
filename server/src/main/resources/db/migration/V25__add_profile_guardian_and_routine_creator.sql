-- 이룸이 한 명에 보호자 여럿 — 1단계 "늘리고 옮긴다" (docs/superpowers/specs/2026-09-23-multi-guardian-design.md 5장, 이슈 #360).
--
-- 명세는 이 파일을 V22 로 적었다. V22~V24 는 그 사이 공지(#370)·탈퇴 보관(#372)·프롬프트 키(#375)가 먼저 썼다.
-- 명세의 "V23 — 메우고 줄인다"는 4단계(#364)에서 이 다음 번호로 쓴다.
--
-- 지금은 이룸이(profile)가 보호자 계정 하나에만 붙는다(profile.member_id). 두 번째 보호자가 붙을 자리가
-- 없고, 한 사람이 탈퇴하면 이룸이와 일과가 통째로 사라진다. 관계를 표로 뗀다.
--
-- 추가만 한다. 배포 뒤 옛 서버 이미지로 되돌려도 이 스키마 위에서 옛 코드가 돌아야 한다
-- (Flyway 는 스키마를 되돌리지 않고, 무중단 배포가 없어 되돌릴 곳이 옛 이미지뿐이다).
--   * routine.created_by 는 비워 둘 수 있다. 옛 코드는 이 컬럼을 모르고 일과를 만든다.
--   * profile.member_id 는 지우지 않고 NULL 만 허용한다. 옛 코드는 이 값으로 프로필을 찾는다.
--   * 관계 표의 외래키는 ON DELETE CASCADE 다. 옛 코드는 이 표를 모르고 탈퇴 때 profile 을, 보관 기간이
--     지난 완전 삭제(#372) 때 member 를 지우므로, CASCADE 가 없으면 옛 서버에서 둘 다 외래키에 걸린다.
-- NOT NULL 과 member_id 삭제는 4단계(#364, 다음 배포의 줄이기 마이그레이션)에서 한다.
--
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 if not exists 로 양쪽 모두 안전하게 한다.

create table if not exists profile_guardian (
    id         varchar(255) primary key,
    profile_id varchar(255) not null references profile (id) on delete cascade,
    member_id  varchar(255) not null references member (id) on delete cascade,
    -- 화면에서 부르는 이름(보호자·센터 선생님)일 뿐 권한에 쓰지 않는다
    kind       varchar(30)  not null default 'GUARDIAN',
    joined_at  timestamp    not null,
    created_at timestamp,
    updated_at timestamp,
    constraint uk_profile_guardian unique (profile_id, member_id)
);

-- "이 보호자의 이룸이들"을 찾는 쪽. (profile_id, member_id) 유니크가 이룸이 쪽 조회를 맡는다.
create index if not exists idx_profile_guardian_member on profile_guardian (member_id);

-- 지금의 1:1 을 그대로 관계로 옮긴다. 합류 시각은 프로필이 생긴 때다 — 처음 만든 보호자가
-- "가장 먼저 합류한 사람"이어야 대표 보호자 넘기기(E14)가 맞게 돈다.
-- 이미 관계가 있는 프로필은 건너뛴다. 다시 돌려도 중복이 생기지 않는다.
insert into profile_guardian (id, profile_id, member_id, kind, joined_at, created_at, updated_at)
select gen_random_uuid()::text, p.id, p.member_id, 'GUARDIAN', coalesce(p.created_at, now()), now(), now()
from profile p
where p.member_id is not null
  and not exists (select 1 from profile_guardian g where g.profile_id = p.id);

-- 일과를 만든 사람. 승인·수정·삭제는 만든 사람만 하고, 보유 일과 한도도 이 값으로 센다.
alter table routine add column if not exists created_by varchar(255) references member (id);
create index if not exists idx_routine_created_by on routine (created_by);

-- 기존 일과는 그 프로필의 보호자가 만든 것이다 (지금은 한 명뿐이다).
update routine r
set created_by = (select p.member_id from profile p where p.id = r.profile_id)
where r.created_by is null;

-- 처음 만든 보호자가 나가도 이룸이가 남을 수 있어야 한다. 남은 보호자에게 넘기거나 비워야 하는데
-- NOT NULL 이면 비울 수 없다.
alter table profile alter column member_id drop not null;

-- device_link.profile_id 는 운영에서 NULL 0건이지만 NOT NULL 도 4단계로 미룬다 (같은 이유).

-- 초대 코드 (명세 4-1 · 4-6). 표만 먼저 만든다 — 발급·입력 API 는 2단계(#361)다. 명세 5장이 이 마이그레이션에
-- 함께 넣었다. device_link 와 같은 모양으로 원문은 담지 않고 해시만 남긴다.
-- 외래키는 관계 표와 같은 이유로 지우는 쪽을 막지 않는다 — 이 표를 모르는 서버(1단계 서버)로 되돌려도
-- 탈퇴가 돌아야 한다. 사용한 사람이 탈퇴하면 기록만 남기고 사람은 비운다.
create table if not exists profile_invite (
    id              varchar(255) primary key,
    code_hash       varchar(64)  not null,
    profile_id      varchar(255) not null references profile (id) on delete cascade,
    issued_by       varchar(255) not null references member (id) on delete cascade,
    expires_at      timestamp    not null,
    redeemed_by     varchar(255) references member (id) on delete set null,
    redeemed_at     timestamp,
    revoked_at      timestamp,
    failed_attempts integer      not null default 0,
    created_at      timestamp,
    updated_at      timestamp
);

create index if not exists idx_profile_invite_code_hash on profile_invite (code_hash);
create index if not exists idx_profile_invite_profile on profile_invite (profile_id);
