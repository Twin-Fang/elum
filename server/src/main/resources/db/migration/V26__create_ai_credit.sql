-- 주간 AI 크레딧 장부 (이슈 #407, docs/superpowers/specs/2026-09-24-ai-credit-design.md 2장).
--
-- 회원당 계정 1행(잠금 지점) + 적립 묶음(grant) + 생성 작업(job) + 추가 전용 원장(ledger) + 정책 버전.
-- 모든 증감은 계정 행을 SELECT … FOR UPDATE 로 잡은 안에서 일어나 서버가 여러 대여도 한 줄로 선다.
--
-- 추가만 한다. 기존 표는 ai_call_log 에 비워 둘 수 있는 컬럼 하나를 더할 뿐이다 — 배포 뒤 옛 서버 이미지로
-- 되돌려도 옛 코드는 새 표를 모르고 그대로 돈다(Flyway 는 스키마를 되돌리지 않는다, V25 와 같은 약속).
--
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 if not exists · on conflict do nothing 으로 양쪽 모두 안전하게 한다.
-- 시각은 한국 시각(now() at time zone 'Asia/Seoul')으로 넣는다 — 앱이 LocalDateTime 을 운영 TZ(Asia/Seoul)로 쓴다.

-- 회원당 1행. member 에 외래키를 걸지 않는다 — 가입 트랜잭션 밖에서 계정을 만들 수 있어야 하고,
-- 완전 삭제(purge)는 행을 지우지 않고 member_id 만 떼어 재가입 때 identity_key 로 다시 붙인다.
create table if not exists ai_credit_account (
    id           varchar(255) primary key,
    member_id    varchar(255),
    -- sha256("{provider}:{providerUserId}") hex. 탈퇴 뒤에도 남긴다(재가입으로 주간 지급을 새로 받지 못하게).
    identity_key varchar(64),
    status       varchar(20)  not null default 'ACTIVE',
    created_at   timestamp(6),
    updated_at   timestamp(6),
    constraint uk_ai_credit_account_member unique (member_id),
    constraint uk_ai_credit_account_identity unique (identity_key)
);

-- 적립 묶음. 주간 지급·관리자 보너스가 각각 한 행이다. 만료가 달라 묶음으로 나눈다(만료 임박부터 차감).
create table if not exists ai_credit_grant (
    id             varchar(255) primary key,
    account_id     varchar(255) not null references ai_credit_account (id),
    source         varchar(30)  not null,
    amount         integer      not null,
    remaining      integer      not null,
    valid_from     timestamp(6) not null,
    -- null 이면 무기한
    expires_at     timestamp(6),
    -- 주간 지급만(ISO 주, 2026-W39). 같은 주 두 번 지급을 유니크가 막는다.
    period_key     varchar(10),
    policy_version integer,
    ref_id         varchar(255),
    created_at     timestamp(6),
    updated_at     timestamp(6),
    constraint uk_ai_credit_grant_period unique (account_id, period_key)
);

create index if not exists idx_ai_credit_grant_account_created on ai_credit_grant (account_id, created_at);

-- 생성 작업 1건 = 멱등 키 + 예약 자리. cost_snapshot 은 시작 시점 단가 JSON 이다.
create table if not exists ai_credit_job (
    id             varchar(255) primary key,
    account_id     varchar(255) not null references ai_credit_account (id),
    request_key    varchar(255) not null,
    kind           varchar(30)  not null,
    status         varchar(20)  not null,
    reserved       integer      not null default 0,
    charged        integer      not null default 0,
    overage        integer      not null default 0,
    image_count    integer      not null default 0,
    card_count     integer      not null default 0,
    policy_version integer,
    cost_snapshot  text,
    routine_id     varchar(255),
    step_id        varchar(255),
    started_at     timestamp(6) not null,
    finished_at    timestamp(6),
    fail_reason    varchar(500),
    created_at     timestamp(6),
    updated_at     timestamp(6),
    constraint uk_ai_credit_job_request unique (account_id, request_key)
);

create index if not exists idx_ai_credit_job_account_created on ai_credit_job (account_id, created_at);
-- 관리자 "멈춘 예약"(RESERVED 이면서 오래된 것)을 찾는 쪽.
create index if not exists idx_ai_credit_job_status_started on ai_credit_job (status, started_at);

-- 추가 전용 원장. delta 는 사용 가능량의 변화, balance_after 는 반영 뒤 사용 가능량이다.
create table if not exists ai_credit_ledger (
    id             varchar(255) primary key,
    account_id     varchar(255) not null references ai_credit_account (id),
    job_id         varchar(255),
    grant_id       varchar(255),
    type           varchar(20)  not null,
    delta          integer      not null,
    balance_after  integer      not null,
    action         varchar(30),
    policy_version integer,
    actor          varchar(255),
    reason         varchar(500),
    created_at     timestamp(6),
    updated_at     timestamp(6)
);

create index if not exists idx_ai_credit_ledger_account_created on ai_credit_ledger (account_id, created_at);
create index if not exists idx_ai_credit_ledger_job on ai_credit_ledger (job_id);

-- 정책 버전(추가 전용). 플랜별 지급량·행동별 단가를 JSON 으로 둬 플랜·행동이 늘어도 표를 바꾸지 않는다.
create table if not exists ai_credit_policy (
    id                      varchar(255) primary key,
    version                 integer      not null,
    enabled                 boolean      not null,
    effective_from          timestamp(6) not null,
    weekly_grant            text         not null,
    action_costs            text         not null,
    reservation_ttl_minutes integer      not null,
    grant_apply             varchar(20)  not null,
    created_by              varchar(255),
    reason                  varchar(500),
    created_at              timestamp(6),
    updated_at              timestamp(6),
    constraint uk_ai_credit_policy_version unique (version)
);

-- 시스템 설정 변경 이력. 누가 언제 무엇을 무엇으로 바꿨는지 — 크레딧을 끄고 켠 기록도 여기 남는다.
create table if not exists system_config_history (
    id         varchar(255) primary key,
    config_key varchar(255) not null,
    old_value  text,
    new_value  text,
    changed_by varchar(255),
    reason     varchar(500),
    created_at timestamp(6),
    updated_at timestamp(6)
);

create index if not exists idx_system_config_history_key_created on system_config_history (config_key, created_at);

-- 작업 하나의 실제 USD 를 대조하려고 AI 호출 기록에 작업 id 를 단다. 비워 둘 수 있다 — 옛 서버는 이 컬럼을 모른다.
alter table ai_call_log add column if not exists credit_job_id varchar(255);
create index if not exists idx_ai_call_log_credit_job on ai_call_log (credit_job_id);

-- 정책 v1 — 배포 즉시 켠다. FREE·PRO 주 100, 일과 글·그림·다시 만들기 1, 예약 유지 15분.
insert into ai_credit_policy (id, version, enabled, effective_from, weekly_grant, action_costs,
                              reservation_ttl_minutes, grant_apply, created_by, reason, created_at, updated_at)
values (gen_random_uuid()::text, 1, true, now() at time zone 'Asia/Seoul',
        '{"FREE":100,"PRO":100}', '{"ROUTINE_TEXT":1,"CARD_IMAGE":1,"IMAGE_REGENERATE":1}',
        15, 'NEXT_PERIOD', 'system', '정책 시작 (V26, #407)',
        now() at time zone 'Asia/Seoul', now() at time zone 'Asia/Seoul')
on conflict do nothing;

-- 기존 회원(활성·정지) 계정. 탈퇴 보관 중인 회원은 만들지 않는다 — 되살아나면 첫 요청에서 만들어진다.
-- identity_key 는 가장 먼저 연결한 소셜 신원으로 계산한다(가입 때 코드가 쓰는 것과 같은 식).
insert into ai_credit_account (id, member_id, identity_key, status, created_at, updated_at)
select gen_random_uuid()::text,
       m.id,
       (select encode(sha256(convert_to(i.provider || ':' || i.provider_user_id, 'UTF8')), 'hex')
        from auth_identity i
        where i.member_id = m.id
        order by i.created_at nulls last, i.id
        limit 1),
       'ACTIVE',
       now() at time zone 'Asia/Seoul',
       now() at time zone 'Asia/Seoul'
from member m
where m.status in ('ACTIVE', 'SUSPENDED')
on conflict do nothing;

-- 이번 주 주간 지급. 두 플랜 모두 100 이라 플랜을 가리지 않는다.
-- 주 시작 = 한국 시각 이번 주 월요일 0시, period_key 는 코드(CreditPeriod)와 같은 ISO 주 형식이다.
insert into ai_credit_grant (id, account_id, source, amount, remaining, valid_from, expires_at,
                             period_key, policy_version, ref_id, created_at, updated_at)
select gen_random_uuid()::text,
       a.id,
       'WEEKLY',
       100,
       100,
       date_trunc('week', now() at time zone 'Asia/Seoul'),
       date_trunc('week', now() at time zone 'Asia/Seoul') + interval '7 days',
       to_char(now() at time zone 'Asia/Seoul', 'IYYY-"W"IW'),
       1,
       null,
       now() at time zone 'Asia/Seoul',
       now() at time zone 'Asia/Seoul'
from ai_credit_account a
where a.member_id is not null
on conflict do nothing;

-- 위 지급의 GRANT 원장. 원장이 아직 없는 지급에만 — 다시 돌려도 두 번 남지 않는다.
insert into ai_credit_ledger (id, account_id, job_id, grant_id, type, delta, balance_after, action,
                              policy_version, actor, reason, created_at, updated_at)
select gen_random_uuid()::text,
       g.account_id,
       null,
       g.id,
       'GRANT',
       g.amount,
       g.amount,
       null,
       1,
       'system',
       '정책 시작 지급',
       now() at time zone 'Asia/Seoul',
       now() at time zone 'Asia/Seoul'
from ai_credit_grant g
where g.source = 'WEEKLY'
  and g.period_key = to_char(now() at time zone 'Asia/Seoul', 'IYYY-"W"IW')
  and not exists (select 1 from ai_credit_ledger l where l.grant_id = g.id);
