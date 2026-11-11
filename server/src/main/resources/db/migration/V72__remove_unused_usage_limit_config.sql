-- 쓰지 않는 사용 제한 설정(이룸이 명수, 기록 보관 일수, 고품질 그림) 행 정리 (변경 이력 system_config_history 는 남김)
-- 표·컬럼은 지우지 않는다: 옛 서버 이미지로 되돌려도 기동할 수 있어야 하고, 옛 서버는 빠진 행을 기본값으로 읽는다
delete from system_config where config_key in (
  'FREE_PROFILE_MAX_COUNT', 'PRO_PROFILE_MAX_COUNT',
  'FREE_HISTORY_RETENTION_DAYS', 'PRO_HISTORY_RETENTION_DAYS',
  'FREE_IMAGE_HIGH_QUALITY', 'PRO_IMAGE_HIGH_QUALITY', 'OPENAI_IMAGE_QUALITY_PRO'
);
