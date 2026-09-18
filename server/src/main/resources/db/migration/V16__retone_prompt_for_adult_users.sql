-- AI 프롬프트에서 사용자를 `아이/아동`이라 부르던 문구를 걷어낸다 (이슈 #197).
--
-- ⚠️ PromptDefaults.java만 고치면 운영에 반영되지 않는다.
-- PromptTemplateInitializer는 **행이 없을 때만** 기본값을 심는다
-- (`if (findByPromptKey(key).isPresent()) return;`). 이미 옛 문구가 들어간 DB는
-- 코드를 아무리 고쳐도 그대로다. 그래서 여기서 직접 갱신한다.
--
-- 행을 지우고 다시 심지 않는 이유 — 관리자 프롬프트 페이지에서 손으로 다듬은 내용이
-- 함께 날아간다. 문제가 되는 표현만 골라 바꾼다. 이미 다르게 고쳐 둔 문장은
-- replace 대상이 없어 그대로 남는다(멱등).

-- 1) 바뀌기 직전 내용을 이력에 남긴다 (prompt_template_history는 append-only 계약이다)
insert into prompt_template_history (id, prompt_key, content, created_at, updated_at)
select gen_random_uuid()::text, t.prompt_key, t.content, now(), now()
  from prompt_template t
 where t.content like '%아이에게 말하듯%'
    or t.content like '%아동이 스스로%'
    or t.content like '%발달장애 아동%'
    or t.content like '%아동이 그림만 보고%'
    or t.content like '%일반적인 아동으로 그립니다%';

-- 2) 표현을 바꾼다. `아이/아동`이 들어간 문장을 통째로 지우지 않고,
--    나이를 짐작하게 하는 부분만 교체한다.
update prompt_template
   set content = replace(
                   replace(
                     replace(
                       replace(
                         replace(
                           content,
                           '"~해요" 체를 사용하고, 아이에게 말하듯 다정하고 친근하게 씁니다.',
                           '"~해요" 체로 다정하고 친근하게 씁니다. 나이를 짐작하게 하는 말투를 쓰지 않습니다.'),
                         'INDEPENDENT: 아동이 스스로 수행하는 행동',
                         'INDEPENDENT: 당사자가 스스로 수행하는 행동'),
                       '발달장애 아동을 위한',
                       '발달장애 당사자를 위한'),
                     '아동이 그림만 보고',
                     '보는 사람이 그림만 보고'),
                   '일반적인 아동으로 그립니다',
                   '나이를 짐작하기 어려운 단순한 인물로 그립니다')
 where content like '%아이에게 말하듯%'
    or content like '%아동이 스스로%'
    or content like '%발달장애 아동%'
    or content like '%아동이 그림만 보고%'
    or content like '%일반적인 아동으로 그립니다%';

-- 🔴 DLP 마스킹 판별 규칙은 건드리지 않는다.
--    `"아이", "아동", "선생님", "학교", "병원", "우리 집"은 이름이 아닙니다.`
--    보호자는 실제로 "우리 아이가…"라고 입력한다. 이 목록을 지우면 그 단어를
--    사람 이름으로 오인해 마스킹이 오작동한다. 위 replace 어느 것도 이 문장과
--    겹치지 않는다 — `"아이",` 와 `"아동",` 은 패턴에 포함되지 않았다.
