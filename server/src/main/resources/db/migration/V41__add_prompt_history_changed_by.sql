-- 프롬프트 이력 수정자 (이슈 #758). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- changed_by: 이 이력을 만든 저장(= 현재 적용본으로 교체한 저장)을 한 관리자 이름. 기존 행은 NULL(화면에서 '-').
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE prompt_template_history ADD COLUMN IF NOT EXISTS changed_by VARCHAR(255);
