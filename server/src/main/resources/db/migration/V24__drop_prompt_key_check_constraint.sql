-- prompt_template 은 처음에 ddl-auto 로 만들어졌다. Hibernate 는 @Enumerated(STRING) 컬럼에
-- 그때의 enum 값 목록으로 CHECK 제약(prompt_template_prompt_key_check)을 건다 — 로컬 DB 에서
-- 확인했다. ddl-auto: update 는 이 제약을 새 값으로 고치지 않는다. 그래서 PromptKey 에 새 키를
-- 더하면 기본값 시딩이 제약에 걸려 거절된다 (#375 영어 그림 지시문, #373 FLUX 지시문).
--
-- 값의 유효성은 코드(enum)가 지킨다. 목록을 박아 둔 제약은 키를 더할 때마다 마이그레이션을
-- 요구할 뿐이라 걷어낸다. 운영에 제약이 없으면 아무 일도 하지 않는다(IF EXISTS).
-- 테이블이 아직 없는 완전히 새 환경에서도 실패하지 않게 to_regclass 로 먼저 본다(V1 과 같은 이유).
DO $$
BEGIN
  IF to_regclass('public.prompt_template') IS NOT NULL THEN
    ALTER TABLE prompt_template DROP CONSTRAINT IF EXISTS prompt_template_prompt_key_check;
  END IF;
END $$;
