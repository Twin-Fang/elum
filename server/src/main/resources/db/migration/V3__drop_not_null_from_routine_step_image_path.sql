-- AI 이미지 생성이 재시도까지 실패하면 buildResult()가 예외를 던져 create()가 통째로
-- 500으로 죽고, 일과가 서버에 저장조차 되지 않았다(루트 CLAUDE.md 서비스 원칙 6 위반 —
-- "AI 실패 시 fallback 필수"). image_path의 NOT NULL 제약이 그 원인이라, 이미지 없이도
-- 일과를 저장할 수 있도록 제약을 푼다. 이미지 생성에 실패한 단계는 image_path가 null로 남고,
-- 조회 시 클라이언트가 이미지 자리를 비워 렌더링한다.
--
-- V1/V2와 동일하게 to_regclass로 테이블 존재 여부를 먼저 확인한다 — 완전히 새 환경(신규 로컬
-- DB, 신규 배포 환경)에서는 이 마이그레이션이 최초 실행될 때 routine_step 테이블 자체가 아직
-- 없을 수 있다. 이 경우 엔티티 매핑(@Column(nullable = true))이 테이블을 nullable로 생성하므로
-- 별도 처리가 필요 없다.
--
-- DROP NOT NULL은 제약이 이미 없어도(신규 컬럼이거나 이전에 이미 푼 경우) 에러 없이 통과하므로
-- IF EXISTS 류의 추가 가드가 필요 없다. 다만 컬럼 자체가 없는 경우를 대비해 컬럼 존재는 확인한다.
DO $$
BEGIN
  IF to_regclass('public.routine_step') IS NOT NULL
     AND EXISTS (
       SELECT 1 FROM information_schema.columns
       WHERE table_name = 'routine_step' AND column_name = 'image_path'
     ) THEN
    ALTER TABLE routine_step ALTER COLUMN image_path DROP NOT NULL;
  END IF;
END $$;
