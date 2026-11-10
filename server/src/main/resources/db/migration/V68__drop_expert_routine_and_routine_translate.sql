-- 지운 기능(전문가 일과, 일과 다른 언어로 만들기)의 표와 설정 행 정리
-- 가져간 일과·만든 사본은 보통 일과라 그대로 남는다 (expert_routine 과 외래키 없음)
drop table if exists expert_routine_step;
drop table if exists expert_routine;
-- 코드에서 지운 설정 키의 행 (변경 이력 system_config_history 는 남김)
delete from system_config where config_key in (
  'FREE_ROUTINE_TEMPLATES', 'PRO_ROUTINE_TEMPLATES', 'FREE_ROUTINE_TRANSLATE', 'PRO_ROUTINE_TRANSLATE'
);
