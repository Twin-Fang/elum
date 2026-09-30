-- 보상형 광고 시청 → AI 크레딧 지급 기록 (이슈 #463, docs/superpowers/specs/2026-09-30-ad-reward-server-design.md 7장).
--
-- 광고 한 번 = 세션 한 행. nonce 가 시청과 회원을 잇는 유일한 끈이고, 한 번의 시청이 두 번 지급되지 않게
-- 세 겹으로 막는다: 상태 전이(PENDING → GRANTED 한 번), nonce 유니크, transaction_id 유니크.
--
-- 추가만 한다. 기존 표는 건드리지 않는다 — 배포 뒤 옛 서버 이미지로 되돌려도 옛 코드는 새 표를 모르고 그대로 돈다
-- (Flyway 는 스키마를 되돌리지 않는다, V26·V27 과 같은 약속). 기능은 시스템 설정 AD_REWARD_ENABLED(기본 꺼짐)로 막혀 있다.
--
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 if not exists 로 양쪽 모두 안전하게 한다.
-- member 에 외래키를 걸지 않는다 — 탈퇴해도 지급 기록은 남는다(크레딧 원장과 같은 이유).
create table if not exists ad_reward_session (
    id              varchar(255) primary key,
    member_id       varchar(255) not null,
    nonce           varchar(64)  not null,
    status          varchar(20)  not null,
    expires_at      timestamp(6) not null,
    granted_at      timestamp(6),
    granted_credits integer      not null default 0,
    -- 서명이 맞는 콜백을 주지 않은 사유(DISABLED · AD_UNIT · NOT_PENDING · EXPIRED · FROZEN · DAILY_LIMIT)
    reject_reason   varchar(30),
    -- Google 이 시청 한 번마다 붙이는 ID. 지급된 뒤에만 채운다(null 은 여러 행 허용).
    transaction_id  varchar(255),
    grant_id        varchar(255),
    created_at      timestamp(6),
    updated_at      timestamp(6),
    constraint uk_ad_reward_session_nonce unique (nonce),
    constraint uk_ad_reward_session_tx unique (transaction_id)
);

create index if not exists idx_ad_reward_session_member_status on ad_reward_session (member_id, status, expires_at);

-- 광고 보상 지급은 ai_credit_grant.source 에 새 값 AD_REWARD 를 넣는다. 운영 DB 는 V26 이 varchar(30) 으로 만들어 제약이
-- 없지만, 로컬에서 ddl-auto 가 먼저 표를 만들었다면 Hibernate 가 그때의 enum 값 목록으로 CHECK 제약
-- (ai_credit_grant_source_check)을 걸어 둔다 — V24 와 같은 함정이다. 값의 유효성은 코드(enum)가 지키므로 걷어낸다.
-- 제약이 없으면 아무 일도 하지 않는다(IF EXISTS). 표가 아직 없는 새 환경에서도 실패하지 않게 to_regclass 로 먼저 본다.
DO $$
BEGIN
  IF to_regclass('public.ai_credit_grant') IS NOT NULL THEN
    ALTER TABLE ai_credit_grant DROP CONSTRAINT IF EXISTS ai_credit_grant_source_check;
  END IF;
END $$;
