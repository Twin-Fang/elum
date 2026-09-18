-- 계정의 요금제 구독 (이슈 #158).
--
-- 무엇이 Free고 무엇이 Pro인지는 여기 담지 않는다. 그건 system_config에 있고,
-- 이 표는 "이 계정이 지금 어느 플랜인가"만 안다. 한도 숫자가 바뀌어도 이 표는
-- 손댈 일이 없다.
--
-- 이룸이(profile)가 아니라 계정(member)에 붙는다. 돈을 내는 쪽이 보호자이고
-- 당사자는 로그인하지 않기 때문이다. 기관이 여러 이룸이를 지원하는 경우는
-- 별도 구독이 아니라 "이룸이 몇 명까지" 권한으로 표현된다.
--
-- source·external_ref는 결제를 붙일 자리다. 앱 스토어 심사 전이라 지금은
-- 인앱결제를 쓸 수 없어 비워 둔다. 영수증 검증이 생기면 그 서비스가 같은 표에
-- APPLE_IAP·GOOGLE_IAP로 쓰면 되고, 권한을 묻는 코드는 바뀌지 않는다.
create table if not exists subscription (
    id           varchar(255) primary key,
    member_id    varchar(255) not null unique references member (id),
    plan         varchar(255) not null,
    status       varchar(255) not null,
    started_at   timestamp,
    -- null이면 기간 제한이 없다. Free와 관리자 무기한 발급이 여기 해당한다.
    expires_at   timestamp,
    source       varchar(255) not null,
    external_ref varchar(255),
    memo         varchar(500),
    created_at   timestamp,
    updated_at   timestamp
);

-- 권한 판정이 회원 단위 단건 조회라 이 인덱스만 있으면 된다.
-- (member_id는 unique 제약이 이미 인덱스를 만들지만, 이름을 고정해 두면
--  나중에 실행 계획을 볼 때 헷갈리지 않는다)
create index if not exists idx_subscription_member on subscription (member_id);

-- 이미 가입해 있는 계정에도 Free 구독을 만들어 둔다.
--
-- 기능상 꼭 필요한 작업은 아니다. 구독 행이 없는 계정은 코드가 Free로 보기
-- 때문이다. 그래도 채워 두는 이유는 관리자 화면에서 모든 계정의 구독이 같은
-- 모양으로 보이고, "언제부터 Free였는지"가 남기 때문이다.
--
-- 영향을 최소화한다.
--   * 기존 표를 하나도 건드리지 않는다. 순수하게 행만 넣는다.
--   * 이미 구독이 있는 계정은 건너뛴다. 다시 돌려도 중복이 생기지 않는다.
--   * 시작 시각은 계정이 만들어진 때로 둔다 — 그때부터 Free였던 게 맞다.
insert into subscription (id, member_id, plan, status, source, started_at, memo, created_at, updated_at)
select gen_random_uuid()::text,
       m.id,
       'FREE',
       'ACTIVE',
       'SIGNUP',
       m.created_at,
       '기존 계정 일괄 생성 (V18)',
       now(),
       now()
from member m
where not exists (select 1 from subscription s where s.member_id = m.id);
