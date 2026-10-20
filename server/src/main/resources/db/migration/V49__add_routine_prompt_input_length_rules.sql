-- 일과 생성 지시문에 입력 품질 규칙 3개를 더한다 (이슈 #888).
--   1) [입력 길이별 처리]: 초단문 보강, 장문 걸러내기, 오타 보정, 개인정보 미사용
--   2) 제목 작성 규칙: 의성어·유아어 금지
--   3) 감정 일과: 첫 단계가 문제 상황 재현이 되지 않게
--
-- 운영 DB 지시문은 관리자가 손으로 고친 변형이라 코드 기본값과 문장이 다르다(V17 교훈).
-- 그래서 통째로 덮어쓰지 않고, 아래 기준 문장이 **그대로 있는 행에서만** 그 자리에 규칙을 끼워 넣는다.
-- 기준 문장이 없는 행(관리자가 지운 것)은 건드리지 않고, 이미 적용된 행은 건너뛴다(멱등).
-- 그림 지시문은 건드리지 않는다: 화면 규격은 코드(ImageCardLayoutRules)가 그림 요청마다 붙인다.

-- 1) 바뀌기 직전 내용을 이력에 남긴다 (append-only 계약)
insert into prompt_template_history (id, prompt_key, content, created_at, updated_at)
select gen_random_uuid()::text, t.prompt_key, t.content, now(), now()
  from prompt_template t
 where t.prompt_key = 'GEMINI_ROUTINE_CREATE_PREFIX'
   and t.locale = 'ko'
   and t.content not like '%[입력 길이별 처리]%'
   and t.content like '%[판단 순서]%';

-- 2) 입력 길이별 처리 절: [판단 순서] 앞에
update prompt_template
   set content = replace(
                   content,
                   '[판단 순서]',
                   '[입력 길이별 처리]
- 한두 단어로 짧은 입력(예: "양치", "병원")은 그 일과를 처음 하는 사람이 따라 할 수 있는 흔한 순서로 4~6단계를 만듭니다. 입력에 없는 특별한 물건·사람·장소는 넣지 않습니다.
- 줄글로 긴 입력은 하소연·배경 설명·걱정을 걸러 내고 실제 행동만 순서대로 뽑습니다.
- 오타·띄어쓰기 오류·줄임말이 있어도 뜻을 짐작해 바른 말로 씁니다. 글자 그대로 옮기지 않습니다.
- 입력에 이름, 전화번호, 진단명이 있어도 결과에 쓰지 않고 일과 행동만 만듭니다.

[판단 순서]')
 where prompt_key = 'GEMINI_ROUTINE_CREATE_PREFIX'
   and locale = 'ko'
   and content not like '%[입력 길이별 처리]%'
   and content like '%[판단 순서]%';

-- 3) 제목: 의성어·유아어 금지 (제목 예시 줄 앞에)
update prompt_template
   set content = replace(
                   content,
                   '- 예: "비오는 날 학교에 가요", "이 닦고 자러 가요"',
                   '- "치카치카", "쓱싹쓱싹" 같은 의성어·의태어, "맘마", "쉬야" 같은 유아어를 쓰지 않습니다.
- 예: "비오는 날 학교에 가요", "이 닦고 자러 가요"')
 where prompt_key = 'GEMINI_ROUTINE_CREATE_PREFIX'
   and locale = 'ko'
   and content not like '%유아어를 쓰지 않습니다%';

-- 4) 감정 일과: 마지막 예시 줄 뒤에
update prompt_template
   set content = replace(
                   content,
                   '"숨을 크게 다섯 번 쉬어요".',
                   '"숨을 크게 다섯 번 쉬어요".
- 감정 일과의 첫 단계는 그 감정이 생긴 상황을 다시 하는 행동(장난감으로 놀기 등)이 아니라, 감정이 올라왔을 때 가장 먼저 할 수 있는 행동으로 시작합니다.')
 where prompt_key = 'GEMINI_ROUTINE_CREATE_PREFIX'
   and locale = 'ko'
   and content not like '%감정 일과의 첫 단계는%';
