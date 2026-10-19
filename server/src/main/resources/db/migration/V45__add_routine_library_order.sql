-- 일과관리 칸 순서 (이슈 #844). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- routine.library_order: 묶음 밖 낱개 원본의 칸 자리(0부터). routine_group.display_order 와 같은 번호 공간이다.
--   NULL 이면 순서를 정한 적 없는 일과 — 앱이 정한 칸 뒤에 기본 순서(최신순)로 놓는다. 기존 행은 채우지 않는다.
--
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE routine ADD COLUMN IF NOT EXISTS library_order INTEGER;
