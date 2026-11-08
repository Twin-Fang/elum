-- 폐기한 AI DLP(민감정보 검사) 지시문·설정 행 정리
-- prompt_key 는 문자열 enum: 모르는 값이 남으면 지시문 목록 읽기 실패
delete from prompt_template_history where prompt_key = 'LOCAL_LLM_SENSITIVE_INFO_CHECK';
delete from prompt_template where prompt_key = 'LOCAL_LLM_SENSITIVE_INFO_CHECK';
delete from system_config where config_key = 'LOCAL_LLM_MODEL';
