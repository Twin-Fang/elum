-- 홈 목록에서 보이는 순서 (이슈 #258).
--
-- 지금까지는 예정 시각으로만 줄을 세워 보호자가 순서를 바꿀 수 없었다. 예정 시각을
-- 바꿔 순서를 표현하면 "몇 시에 하는 일과인가"라는 뜻이 망가지므로 보이는 순서를
-- 따로 둔다.
--
-- 기본값 0으로 넣고, 기존 일과에는 지금 보이는 차례 그대로 번호를 매긴다. 순서를 한 번도
-- 바꾸지 않은 계정은 조회 정렬이 "보이는 순서 → 예정 시각"이라 **지금과 똑같은 차례**로
-- 보인다.
alter table routine add column if not exists display_order integer not null default 0;

-- 프로필별로 예정 시각 차례대로 1번부터. created_at은 예정 시각이 같을 때의 결정자다.
with ordered as (
  select id,
         row_number() over (
           partition by profile_id
           order by scheduled_at asc, created_at asc, id asc
         ) as position
  from routine
)
update routine r
set display_order = o.position
from ordered o
where o.id = r.id
  and r.display_order = 0;
