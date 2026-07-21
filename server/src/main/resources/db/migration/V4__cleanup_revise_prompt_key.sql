-- GEMINI_ROUTINE_REVISE_PREFIX가 PromptKey enum에서 제거되면서 남는 기존 행을 정리한다.
-- 이 행이 남아있으면 PromptTemplateService.getAll()이 알 수 없는 enum 문자열을 매핑하지
-- 못해 관리자 프롬프트 페이지가 500으로 깨진다(V1__cleanup_legacy_prompt_key.sql과 동일한
-- 장애 유형 — fable5 최종 리뷰에서 발견).
--
-- to_regclass로 테이블 존재 여부를 먼저 확인한다 — 완전히 새 환경(신규 로컬 DB, 신규 배포
-- 환경)에서는 이 마이그레이션이 최초 실행될 때 prompt_template 테이블 자체가 없어 DELETE가
-- "relation does not exist"로 실패하고 앱 기동이 죽는다(V1과 동일한 이유).
DO $$
BEGIN
  IF to_regclass('public.prompt_template') IS NOT NULL THEN
    DELETE FROM prompt_template WHERE prompt_key = 'GEMINI_ROUTINE_REVISE_PREFIX';
  END IF;
END $$;
