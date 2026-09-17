-- 보호자 계정과 이룸이 휴대폰을 잇는 연결 (이슈 #200).
--
-- 암호 원문은 담지 않는다 — 연결 암호는 계정에 붙는 자격증명이라 refresh_token과 같이
-- 해시만 남긴다. 원문은 발급 응답 한 번에만 나간다.
create table if not exists device_link (
    id               varchar(36)  primary key,
    member_id        varchar(36)  not null,
    profile_id       varchar(36),
    code_hash        varchar(64)  not null,
    expires_at       timestamp    not null,
    redeemed_at      timestamp,
    linked_device_id varchar(255),
    revoked_at       timestamp,
    failed_attempts  integer      not null default 0,
    created_at       timestamp,
    updated_at       timestamp
);

create index if not exists idx_device_link_code_hash on device_link (code_hash);
create index if not exists idx_device_link_member    on device_link (member_id);
