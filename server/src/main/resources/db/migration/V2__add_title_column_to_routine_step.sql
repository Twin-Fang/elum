-- RoutineStep 엔티티에 title(카드 제목) 필드가 추가됐지만(4ddb556) 기존 routine_step
-- 테이블에는 반영되지 않아, Hibernate 스키마 검증(ddl-auto: validate)이
-- "missing column [title] in table [routine_step]"로 기동을 실패시킨다.
--
-- V1과 동일하게 to_regclass로 테이블 존재 여부를 먼저 확인한다 — 완전히 새 환경(신규 로컬 DB,
-- 신규 배포 환경)에서는 이 마이그레이션이 최초 실행될 때 routine_step 테이블 자체가 아직
-- 없을 수 있다.
DO $$
BEGIN
  IF to_regclass('public.routine_step') IS NOT NULL THEN
    ALTER TABLE routine_step ADD COLUMN IF NOT EXISTS title TEXT;
  END IF;
END $$;
