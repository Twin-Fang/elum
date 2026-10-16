-- 프롬프트 행에 언어를 더한다.
--
-- 키 하나에 언어마다 한 행이 된다: 유니크가 (prompt_key) -> (prompt_key, locale). 기존 행은 DEFAULT 'ko' 로
-- 모두 한국어 행이 되고 내용은 바뀌지 않는다.
--
-- 더하고 푸는 것만 한다(NOT NULL 은 DEFAULT 와 함께 더한다). 옛 서버 이미지로 되돌려도 locale 컬럼을 모른 채
-- ko 행을 읽고 쓴다. 단 en/ja/zh/es 행이 생긴 뒤에는 옛 서버의 findByPromptKey 가 한 키에 여러 행을 만나
-- 터진다. 되돌리기 전에 `delete from prompt_template where locale <> 'ko'` 로 ko 가 아닌 행을 지운다.
--
-- prompt_template 은 처음에 ddl-auto 가 만들어 옛 유니크 제약의 이름을 모른다.
-- 이름을 박지 않고 pg_constraint 에서 prompt_key 한 칸짜리 유니크 제약을 찾아 지운다. 표가 아직 없는
-- 완전히 새 환경에서도 실패하지 않게 to_regclass 로 먼저 본다. 로컬(ddl-auto: update)에서 이미 만들어졌을 수
-- 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
DO $$
DECLARE
  old_unique RECORD;
BEGIN
  IF to_regclass('public.prompt_template') IS NOT NULL THEN
    ALTER TABLE prompt_template ADD COLUMN IF NOT EXISTS locale VARCHAR(8) NOT NULL DEFAULT 'ko';

    FOR old_unique IN
      SELECT con.conname
        FROM pg_constraint con
       WHERE con.conrelid = 'public.prompt_template'::regclass
         AND con.contype = 'u'
         AND con.conkey = ARRAY[(
               SELECT att.attnum FROM pg_attribute att
                WHERE att.attrelid = con.conrelid AND att.attname = 'prompt_key')]
    LOOP
      EXECUTE format('ALTER TABLE prompt_template DROP CONSTRAINT %I', old_unique.conname);
    END LOOP;

    CREATE UNIQUE INDEX IF NOT EXISTS ux_prompt_template_key_locale ON prompt_template (prompt_key, locale);
  END IF;

  IF to_regclass('public.prompt_template_history') IS NOT NULL THEN
    ALTER TABLE prompt_template_history ADD COLUMN IF NOT EXISTS locale VARCHAR(8) NOT NULL DEFAULT 'ko';
    CREATE INDEX IF NOT EXISTS idx_prompt_template_history_key_locale_created
      ON prompt_template_history (prompt_key, locale, created_at);
  END IF;
END $$;
