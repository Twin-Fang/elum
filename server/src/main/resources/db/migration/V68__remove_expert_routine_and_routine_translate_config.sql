-- 지운 기능(전문가 일과, 일과 다른 언어로 만들기)의 설정 행 정리 (변경 이력 system_config_history 는 남김)
-- expert_routine · expert_routine_step 표는 지우지 않는다: 옛 서버 이미지로 되돌려도 그 표로 기동할 수 있어야 한다
delete from system_config where config_key in (
  'FREE_ROUTINE_TEMPLATES', 'PRO_ROUTINE_TEMPLATES', 'FREE_ROUTINE_TRANSLATE', 'PRO_ROUTINE_TRANSLATE'
);
