-- V16 후속 — 운영 DB에만 있는 **손으로 다듬은 변형**을 마저 바꾼다 (이슈 #197).
--
-- ⚠️ 배포 후 관리자 프롬프트 페이지를 열어 보고 알았다.
-- 운영 DB의 프롬프트는 `PromptDefaults.java`와 **문장 자체가 다르다.**
-- 관리자 페이지에서 손으로 고친 내용이 쌓여 있어서, 코드 기본값을 기준으로 만든
-- V16의 치환 패턴이 아래 네 군데를 비켜 갔다.
--
-- | 코드 기본값 | 운영 DB (손으로 고친 것) |
-- | --- | --- |
-- | 특정 캐릭터를 지정하지 않은 일반적인 아동으로 그립니다 | 일반적인 아동 **캐릭터로** 그립니다 |
--
-- 교훈: 프롬프트는 코드가 아니라 **DB가 진짜**다. 코드만 고치고 끝내면 안 되고,
-- 배포 뒤 관리자 페이지에서 실제 값을 확인해야 한다.

-- 1) 바뀌기 직전 내용을 이력에 남긴다 (append-only 계약)
insert into prompt_template_history (id, prompt_key, content, created_at, updated_at)
select gen_random_uuid()::text, t.prompt_key, t.content, now(), now()
  from prompt_template t
 where t.prompt_key <> 'LOCAL_LLM_SENSITIVE_INFO_CHECK'
   and (t.content like '%아동 호칭%'
     or t.content like '%아동에게 소리 내어%'
     or t.content like '%아동에게 직접 말하듯%'
     or t.content like '%일반적인 아동 캐릭터%');

-- 2) 치환. 🔴 DLP 판별 프롬프트는 키로 제외한다 — 그 안의
--    `아이 / 아동 / 선생님 / 학교 / 병원 / 우리 집` 목록은 이름이 아님을 알리는
--    규칙이라 지우면 마스킹이 오작동한다.
update prompt_template
   set content = replace(
                   replace(
                     replace(
                       replace(
                         content,
                         '아동 호칭',
                         '이룸이 호칭'),
                       '아동에게 소리 내어 읽어주는 문장입니다.',
                       '소리 내어 읽어주는 문장입니다.'),
                     'title과 description 모두 아동에게 직접 말하듯 "~해요" 체를 사용합니다.',
                     'title과 description 모두 "~해요" 체를 사용합니다. 나이를 짐작하게 하는 말투를 쓰지 않습니다.'),
                   '일반적인 아동 캐릭터로 그립니다',
                   '나이를 짐작하기 어려운 단순한 캐릭터로 그립니다')
 where prompt_key <> 'LOCAL_LLM_SENSITIVE_INFO_CHECK'
   and (content like '%아동 호칭%'
     or content like '%아동에게 소리 내어%'
     or content like '%아동에게 직접 말하듯%'
     or content like '%일반적인 아동 캐릭터%');
