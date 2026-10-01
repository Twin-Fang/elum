-- 다중 보호자 4단계 "메우고 줄인다" (docs/superpowers/specs/2026-09-23-multi-guardian-design.md 5장, 이슈 #364).
--
-- 명세는 이 파일을 V23 으로 적었다. 그 번호는 계획 당시 값이고 지금 운영의 마지막은 V31 이라 V32 로 쓴다.
--
-- !!! 이 마이그레이션은 되돌릴 수 없다 — 옛 서버 이미지로 되돌리면 깨진다 !!!
--   V25~V31 은 "추가만 한다"는 약속(옛 서버로 되돌려도 안전)을 지켰다. V32 는 그 약속을 일부러 깬다.
--   * profile.member_id 를 지운다 → V32 이전 서버는 이 컬럼으로 이룸이를 찾고 가입 때 채우므로 부팅·가입이 실패한다.
--   * routine.created_by 를 NOT NULL 로 건다 → 이 컬럼을 모르는 옛 서버의 일과 생성이 전부 실패한다.
--   * device_link.profile_id 를 NOT NULL 로 건다.
--   Flyway 는 스키마를 되돌리지 않는다. 배포 뒤 문제가 생기면 옛 이미지가 아니라 "V32 를 아는 새 이미지"로
--   고쳐 올려야 한다. 무중단 배포(#163)가 없어 배포 중 실패하면 서비스가 멈추니 운영 DB 사본 리허설과
--   아래 점검 SQL 을 먼저 돌린다.
--
-- 순서: (1) 빈칸 메우기 → (2) 메울 수 없는 행이 있으면 원인을 적어 명확히 실패 → (3) NOT NULL → (4) 컬럼 삭제는 마지막.
-- Flyway 가 한 트랜잭션으로 돌리므로 어느 단계에서든 실패하면 전부 되돌아간다(부분 적용 없음).
-- 조용히 데이터를 버리지 않는다 — 지우는 profile.member_id 의 값은 관계 표(profile_guardian)에 모두 있다는 것을 확인한 뒤에만 지운다.
--
-- 로컬(ddl-auto: update)에서 profile.member_id 가 처음부터 없을 수 있어 그 컬럼에 기대는 단계는 있을 때만 돈다.
-- 다시 돌려도 안전하다(멱등).

-- ── 1. 빈칸 메우기 ─────────────────────────────────────────────────────────
-- V25 뒤 옛 서버로 되돌려 있던 동안 생긴 행은 관계·created_by 가 비어 있다 (명세 E38).
do $$
begin
    if exists (select 1 from information_schema.columns
               where table_schema = current_schema() and table_name = 'profile' and column_name = 'member_id') then

        -- 관계가 하나도 없는 프로필에 대표 보호자로 관계를 채운다. 합류 시각은 프로필이 생긴 때다(V25 와 같다).
        insert into profile_guardian (id, profile_id, member_id, kind, joined_at, created_at, updated_at)
        select gen_random_uuid()::text, p.id, p.member_id, 'GUARDIAN', coalesce(p.created_at, now()), now(), now()
        from profile p
        where p.member_id is not null
          and not exists (select 1 from profile_guardian g where g.profile_id = p.id);

        -- 만든 사람이 빈 일과 = 옛 서버가 만든 일과 → 그 프로필의 대표 보호자. 대표가 비었으면 가장 먼저 합류한 보호자.
        update routine r
        set created_by = coalesce(
            (select p.member_id from profile p where p.id = r.profile_id),
            (select g.member_id from profile_guardian g where g.profile_id = r.profile_id
              order by g.joined_at asc, g.id asc limit 1))
        where r.created_by is null;
    else
        update routine r
        set created_by = (select g.member_id from profile_guardian g where g.profile_id = r.profile_id
                           order by g.joined_at asc, g.id asc limit 1)
        where r.created_by is null;
    end if;

    -- 이룸이가 빈 이룸이 휴대폰 연결 = 옛 코드가 채우지 못한 행 → 그 보호자가 가장 먼저 합류한 이룸이.
    update device_link d
    set profile_id = (select g.profile_id from profile_guardian g where g.member_id = d.member_id
                       order by g.joined_at asc, g.id asc limit 1)
    where d.profile_id is null;
end
$$;

-- ── 2. 메울 수 없는 행이 남았으면 원인을 적어 멈춘다 ────────────────────────
-- 아래는 조용히 넘기면 데이터를 잃거나 NOT NULL 이 뜻 모를 오류("column contains null values")로 실패하는 경우다.
-- 여기서 멈추면 서버가 뜨지 않으니, 배포 전에 같은 조건을 읽기 전용으로 먼저 센다(이슈 #364 보고의 점검 SQL).
do $$
declare
    null_creators integer;
    null_links    integer;
    lost_owners   integer := 0;
    sample        text;
begin
    select count(*) into null_creators from routine where created_by is null;
    if null_creators > 0 then
        select string_agg(id, ', ') into sample
        from (select id from routine where created_by is null order by id limit 5) s;
        raise exception 'V32 중단: routine.created_by 를 채울 수 없는 일과가 %건 있다 (프로필에 보호자가 없다). 예: %. '
            '이 일과를 지우거나 보호자 관계(profile_guardian)를 만든 뒤 다시 배포한다.', null_creators, sample;
    end if;

    select count(*) into null_links from device_link where profile_id is null;
    if null_links > 0 then
        select string_agg(id, ', ') into sample
        from (select id from device_link where profile_id is null order by id limit 5) s;
        raise exception 'V32 중단: device_link.profile_id 를 채울 수 없는 이룸이 휴대폰 연결이 %건 있다 (그 보호자에게 이룸이가 없다). 예: %. '
            '이 연결을 지운 뒤 다시 배포한다.', null_links, sample;
    end if;

    -- 지울 컬럼의 값이 관계 표에 없으면 "누가 이 이룸이의 대표였나"가 이 컬럼에만 남아 있는 것이다. 버리지 않고 멈춘다.
    if exists (select 1 from information_schema.columns
               where table_schema = current_schema() and table_name = 'profile' and column_name = 'member_id') then
        select count(*) into lost_owners
        from profile p
        where p.member_id is not null
          and not exists (select 1 from profile_guardian g where g.profile_id = p.id and g.member_id = p.member_id);
        if lost_owners > 0 then
            select string_agg(id, ', ') into sample
            from (select p.id from profile p
                  where p.member_id is not null
                    and not exists (select 1 from profile_guardian g where g.profile_id = p.id and g.member_id = p.member_id)
                  order by p.id limit 5) s;
            raise exception 'V32 중단: profile.member_id 가 관계 표(profile_guardian)에 없는 이룸이가 %건 있다. 예: %. '
                '컬럼을 지우면 이 값이 사라진다. 관계를 만들거나 값을 바로잡은 뒤 다시 배포한다.', lost_owners, sample;
        end if;
    end if;
end
$$;

-- ── 3. 필수 값을 건다 ──────────────────────────────────────────────────────
alter table routine alter column created_by set not null;
alter table device_link alter column profile_id set not null;

-- ── 4. 옛 대표 보호자 컬럼은 마지막에 지운다 ───────────────────────────────
-- 컬럼을 지우면 이 컬럼에 걸린 외래키(member 참조)도 함께 사라진다. 인덱스는 명시해 두어 이름을 남긴다.
drop index if exists idx_profile_member;
alter table profile drop column if exists member_id;
