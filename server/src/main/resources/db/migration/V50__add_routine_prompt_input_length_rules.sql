-- 일과 생성 지시문에 입력 품질 규칙 3개, 되묻기 질문 지시문에 선택지 품질 규칙 1절을 더한다 (이슈 #888).
--   1) [입력 길이별 처리]: 초단문 보강, 장문 걸러내기, 오타 보정, 개인정보 미사용
--   2) 제목 작성 규칙: 의성어·유아어 금지
--   3) 감정 일과: 첫 단계가 문제 상황 재현이 되지 않게
--   4) 되묻기 질문: [좋은 질문과 선택지 기준] (짧은 선택지, 입력 중복 금지, 글자 카드·유아용·위험 물건 금지)
--
-- 운영 DB 지시문은 관리자가 손으로 고친 변형이라 코드 기본값과 문장이 다르다(V17 교훈).
-- 그래서 통째로 덮어쓰지 않고, 아래 기준 문장이 **그대로 있는 행에서만** 그 자리에 규칙을 끼워 넣는다.
-- 기준 문장이 없는 행(관리자가 지운 것)은 건드리지 않고, 이미 적용된 행은 건너뛴다(멱등).
-- 그림 지시문은 건드리지 않는다: 화면 규격은 코드(ImageCardLayoutRules)가 그림 요청마다 붙인다.

-- 1) 바뀌기 직전 내용을 이력에 남긴다 (append-only 계약)
insert into prompt_template_history (id, prompt_key, content, created_at, updated_at)
select gen_random_uuid()::text, t.prompt_key, t.content, now(), now()
  from prompt_template t
 where t.locale = 'ko'
   and ((t.prompt_key = 'GEMINI_ROUTINE_CREATE_PREFIX'
         and t.content not like '%[입력 길이별 처리]%'
         and t.content like '%[판단 순서]%')
     or (t.prompt_key = 'GEMINI_ROUTINE_QUESTION_PREFIX'
         and t.content not like '%[좋은 질문과 선택지 기준]%'
         and t.content like '%[출력 계약]%'));

-- 2) 입력 길이별 처리 절: [판단 순서] 앞에
update prompt_template
   set content = replace(
                   content,
                   '[판단 순서]',
                   '[입력 길이별 처리]
- 한두 단어로 짧은 입력(예: "양치", "병원")은 그 일과를 처음 하는 사람이 따라 할 수 있는 흔한 순서로 단계를 만듭니다. 입력에 없는 특별한 물건·사람·장소는 넣지 않습니다.
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

-- 5) 되묻기 질문 지시문: [출력 계약] 앞에
update prompt_template
   set content = replace(
                   content,
                   '[출력 계약]',
                   '[좋은 질문과 선택지 기준]
- 질문은 20자 안팎의 짧은 한 문장이며 이름을 넣지 않습니다. 보호자가 한눈에 답을 고를 수 있어야 합니다.
- 선택지 label은 10자 이내의 짧은 말입니다. 문장으로 길게 쓰지 않습니다. 예: "우산", "처음 가는 곳이에요", "버스를 타요".
- 선택지는 서로 겹치지 않는 구체적인 답이어야 합니다. "시간", "장소", "사람"처럼 분류 이름만 적지 않습니다.
- routineText에 이미 적힌 물건·상황은 선택지에 다시 넣지 않습니다. 적히지 않아서 물어볼 가치가 있는 것만 넣습니다.
- PREPARE_ITEMS 선택지는 그 일과에서 실제로 손에 쥐거나 가방에 넣는 눈에 보이는 물건입니다. 글자가 적힌 카드, 타이머, 말풍선 카드는 넣지 않습니다.
- PREPARE_NEW 선택지는 카드 단계가 달라지는 변화입니다(처음 가는 곳, 이동 수단, 날씨, 함께 가는 사람, 사람이 많은 곳 등). 평소와 같은 일상은 넣지 않습니다.
- 나이를 짐작하게 하는 물건(유아용, 어린이용, 턱받이, 아기 의자)은 넣지 않습니다.
- 칼, 불, 뜨거운 물처럼 위험한 물건은 선택지에 넣지 않고, 같은 일과에서 안전한 준비물(수저, 도마, 행주 등)을 고릅니다.
- routineText가 감정이나 기분에 관한 것이면 PREPARE_ITEMS는 마음을 달래는 눈에 보이는 물건(물, 쿠션, 헤드폰)으로, PREPARE_NEW는 그 감정이 자주 생기는 상황(시끄러운 곳, 사람이 많은 곳, 계획이 바뀔 때)으로 묻습니다.
- routineText가 "준비", "오늘 하루"처럼 너무 막연하면 가장 흔한 외출·등교 상황을 기준으로 구체적인 답을 줍니다.

[출력 계약]')
 where prompt_key = 'GEMINI_ROUTINE_QUESTION_PREFIX'
   and locale = 'ko'
   and content not like '%[좋은 질문과 선택지 기준]%'
   and content like '%[출력 계약]%';
