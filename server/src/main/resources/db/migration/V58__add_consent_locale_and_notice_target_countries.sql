-- 약관·동의 기록에 언어, 공지에 대상 국가를 더한다 (이슈 #531).
--
-- 약관: 키 하나에 언어마다 한 행이 된다. 유니크 (consent_key) -> (consent_key, locale).
-- 기존 약관·이력은 DEFAULT 'ko' 로 모두 한국어 행이 되고 내용은 바뀌지 않는다.
-- 동의 기록: member.consent_locale. 이미 동의한 회원은 그때 한국어 약관밖에 없었으므로 'ko' 로 채운다.
-- 공지: app_notice.target_countries (쉼표 구분 ISO 두 글자, NULL = 전체).
--
-- 더하고 푸는 것만 한다(NOT NULL 은 DEFAULT 와 함께). 옛 서버 이미지로 되돌려도 새 열을 모른 채 ko 행을 읽고 쓴다.
-- 되돌리기 전 확인 2개:
--   1) ko 가 아닌 약관 행이 있으면 옛 findByConsentKey 가 한 키에 여러 행을 만나 터진다
--      -> delete from consent_document where locale <> 'ko'
--   2) 대상 국가가 지정된 공지는 옛 서버가 모두에게 보인다 -> 먼저 끈다
--
-- 옛 유니크 이름은 V21 이 uk_consent_document_key 로 지었지만 로컬(ddl-auto: update)은 Hibernate 가 지은 이름일 수 있다.
-- V36 과 같이 이름이 아니라 모양(consent_key 한 칸짜리 유니크)으로 찾아 지운다. 표가 없는 새 환경도 실패하지 않게 to_regclass 로 먼저 본다.
DO $$
DECLARE
  old_unique RECORD;
BEGIN
  IF to_regclass('public.consent_document') IS NOT NULL THEN
    ALTER TABLE consent_document ADD COLUMN IF NOT EXISTS locale VARCHAR(8) NOT NULL DEFAULT 'ko';

    FOR old_unique IN
      SELECT con.conname
        FROM pg_constraint con
       WHERE con.conrelid = 'public.consent_document'::regclass
         AND con.contype = 'u'
         AND con.conkey = ARRAY[(
               SELECT att.attnum FROM pg_attribute att
                WHERE att.attrelid = con.conrelid AND att.attname = 'consent_key')]
    LOOP
      EXECUTE format('ALTER TABLE consent_document DROP CONSTRAINT %I', old_unique.conname);
    END LOOP;

    CREATE UNIQUE INDEX IF NOT EXISTS ux_consent_document_key_locale ON consent_document (consent_key, locale);
  END IF;

  IF to_regclass('public.consent_document_history') IS NOT NULL THEN
    ALTER TABLE consent_document_history ADD COLUMN IF NOT EXISTS locale VARCHAR(8) NOT NULL DEFAULT 'ko';
    CREATE INDEX IF NOT EXISTS idx_consent_document_history_key_locale_created
      ON consent_document_history (consent_key, locale, created_at);
  END IF;

  IF to_regclass('public.member') IS NOT NULL THEN
    ALTER TABLE member ADD COLUMN IF NOT EXISTS consent_locale VARCHAR(8);
    UPDATE member SET consent_locale = 'ko' WHERE consented_at IS NOT NULL AND consent_locale IS NULL;
  END IF;

  IF to_regclass('public.app_notice') IS NOT NULL THEN
    ALTER TABLE app_notice ADD COLUMN IF NOT EXISTS target_countries VARCHAR(255);
  END IF;
END $$;
