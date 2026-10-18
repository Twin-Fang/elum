-- 요금제 부여·회수 이력 (이슈 #751). 추가 전용: 기존 표는 건드리지 않는다.
--
-- subscription 은 "지금 상태"만 담아 다시 부여하면 이전 값이 사라진다. 이 표는 변경마다
-- 한 줄을 쌓아 누가·언제·왜·무엇에서 무엇으로 바꿨는지 남긴다.
--
-- member_id 는 외래키를 걸지 않는다. 탈퇴 직후에도 이력은 남기고, 보관 기간이 지나
-- 완전 삭제(purge)할 때 애플리케이션이 함께 지운다.
create table if not exists subscription_history (
    id                 varchar(255) primary key,
    member_id          varchar(255) not null,
    -- GRANT: 부여, REVOKE: 회수
    action             varchar(255) not null,
    -- 변경 직전·직후에 실제로 유효하던 요금제 (FREE, PRO)
    before_plan        varchar(255) not null,
    after_plan         varchar(255) not null,
    -- 부여 기간(일). null 이면 무기한이거나 회수
    duration_days      integer,
    before_expires_at  timestamp,
    after_expires_at   timestamp,
    reason             varchar(500) not null,
    -- 변경한 관리자 로그인 이름
    changed_by         varchar(255) not null,
    changed_at         timestamp    not null,
    created_at         timestamp,
    updated_at         timestamp
);

-- 회원 상세의 최근 이력 조회와 목록의 회원별 마지막 변경 조회
create index if not exists idx_subscription_history_member_changed
    on subscription_history (member_id, changed_at desc);
