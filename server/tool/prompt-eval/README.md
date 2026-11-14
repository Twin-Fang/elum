# 일과 생성 프롬프트 평가 하네스

보호자 입력 40건(초단문, 장문, 오타, 정상, 모호, 감정, 준비물, 위험 입력, 복합, 짧은 행동, 안전 교육)을 운영과 같은 조건으로
호출해 카드 글, 카드 그림, 되묻기 질문을 같은 기준으로 비교한다. AI 모델은 바꾸지 않고 프롬프트·스키마·전처리만 바꾼다.

## 운영 조건은 한 곳에 둔다: `prod-config.json`
텍스트 제공자와 모델, thinking budget, 그림 제공자(OPENAI/GEMINI)와 모델·품질, 그림 지시문 언어(KO/EN), 운영 DB 프롬프트 폴더.
`verified: false` 인 항목은 코드 기본값 추정이라 실행 첫 줄에 `미확인`으로 찍힌다. 운영 관리자 화면 값으로 채우고 `verified` 를 true 로 바꾼다.
운영 DB 프롬프트 본문은 `prod-prompts/` 에 `create.txt`, `question.txt`, `image_ko.txt`, `image_en.txt` 로 두고 `prompts.dir` 에 폴더를 적는다.

## 변형
- `before`: 변경 전 코드 기본값(`origin/develop`)과 변경 전 그림 방식(카드 설명 12자만, 화면 규격 없음)
- `after`: 현재 코드 기본값 + 영어 장면 필드 + 화면 규격

```bash
cd server/tool/prompt-eval
python3 run_text.py before && python3 run_text.py after          # 글 40건씩 (Gemini 텍스트, 호출당 약 8원 추정)
python3 run_question.py before && python3 run_question.py after   # 되묻기 질문
python3 show.py after --cases e02,t05                              # 카드 글 보기
python3 run_image.py after --cases t05,l03 --max-steps 5           # 그림: 장수와 추정 비용만 보여 주고 멈춘다
python3 run_image.py after --cases t05,l03 --max-steps 5 --yes     # 확인 후 실행 (기본 한도 40장, --max-images 로 조정)
python3 image_metrics.py before after                               # 흰 배경 비율, 검은 덩어리, 생성 실패
```

- 그림 제공자는 `prod-config.json` 을 따른다. OpenAI 는 `OPENAI_API_KEY` 환경변수 또는 `.env.local` (커밋 안 됨)에서 읽는다.
- Gemini 키는 `application-dev.yml` 의 `gemini.api-key` 에서 읽는다. 값은 출력하지 않는다.
- `variant.json` 의 `description_hint`, `imagePromptEn` 스키마 설명은 서버 코드(`ContentLanguageSpec`, `GeminiRoutineSchemas`)의 사본이다. 서버에서 바꾸면 같이 바꾼다.
- 자동 지표는 구조 위반만 센다. 의미와 그림 품질은 컨택트 시트로 사람이 본다. 결과 폴더 `results/` 는 커밋하지 않는다.

## 행동카드 평가 (Claude Haiku 5.5)

보호자 입력을 `claude -p`로 호출해 카드와 그림 가이드를 채점한다. 운영 지시문과 설정은 관리자 화면에서 읽고(저장하지 않음), 보강 규칙과 스키마는 `origin/develop` 자바 소스에서 읽는다.
`.env.local`에 `ELUM_ADMIN_USERNAME`, `ELUM_ADMIN_PASSWORD`가 있어야 한다. 값은 보고와 커밋에 옮기지 않는다.

| 파일 | 역할 |
|---|---|
| `card_cases.json` | 튜닝 입력 68건 (프롬프트를 고칠 때 본다) |
| `card_cases_holdout.json` | 입력 180건. v5 검증에 썼고, 여기서 찾은 안전 결함으로 v6을 고쳐 지금은 회귀 확인용 |
| `card_cases_holdout2.json` | 처음 보는 입력 110건 (프롬프트를 보지 않은 모델이 작성. 이 입력으로는 프롬프트를 고치지 않는다) |
| `--case-file chips` | 일과 입력 화면 예시 칩 전체를 `routine-phrases_ko.properties` 에서 바로 읽음. 칩이나 지시문을 바꾸면 3회씩 돌려 카드 0장이 0건인지 본다 (#1226) |
| `variants/cards/` | 변형. `이름.txt`는 운영 지시문 뒤에 덧붙이고, `이름.full.txt`는 전체를 교체한다. 최종안은 `v7_try_make.full.txt` (v6 + 일과 관련 입력은 꼭 카드를 만듦, #1226) |
| `run_cards.py` | 호출, 채점, 보고서 |
| `card_rules.py` | 채점 규칙 |
| `card_report.py` | 두 실행 비교, 호출 없는 재채점 |
| `card_verification.py` | 항목별 검증표 (N회 중 M회) |

```bash
cd server/tool/prompt-eval
python3 run_cards.py --variant v6_final --repeat 2                        # 호출 수만 보여 주고 멈춘다
python3 run_cards.py --variant v6_final --repeat 2 --workers 4 --yes      # 튜닝 입력 실행
python3 run_cards.py --variant v6_final --case-file card_cases_holdout2.json --repeat 5 --workers 4 --yes
python3 run_cards.py --variant v6_final --repeat 2 --workers 4 --resume 폴더이름 --yes  # 중단 뒤 남은 호출만
python3 card_report.py 기준폴더 변형폴더                                     # 비교
python3 card_report.py --regrade 폴더                                       # 호출 없이 재채점
python3 card_verification.py 튜닝폴더 처음보는입력폴더                         # 항목별 검증표
python3 run_cards.py --variant v7_try_make --case-file chips --repeat 3 --workers 4 --yes  # 예시 칩 전체
```

- 호출 방식이 서버의 `output_config`와 다를 수 있어, 최종안은 운영 경로로 다시 확인한다.
- `--resume`은 프롬프트를 고치지 않았을 때만 쓴다. 고쳤으면 새 실행으로 돌린다.
- 동시 호출이 많으면 컴퓨터 메모리가 부족해진다. `--workers`는 4 이하로 둔다.

## 다국어 행동카드 평가 (#1375)

영어 지시문 하나로 ko·ja·zh·es 카드를 만들 수 있는지 본다. 카드 글은 보호자가 쓴 언어(입력 `lang`)로 나와야 한다.

| 파일 | 역할 |
|---|---|
| `card_cases_multilang.json` | 16개 입력 x 4개 언어 (id 끝 `_ko/_ja/_zh/_es`, `base_id` 로 묶음). 기대 낱말은 언어마다 옮김, `safety_must` 는 꼭 들어갈 안전 낱말 |
| `card_language.py` | 출력 언어 판정(한글 > ko, 가나 > ja, 한자만 > zh, 라틴 + 스페인어 표지 > es), ja·zh·es 길이·어미·금지어·호칭, 안전 위반 수 |
| `card_multilang_report.py` | 실행 폴더 여러 개 > 언어 x 변형 표(언어 일치, 규칙 위반, 빈 카드, 안전 위반, 평균 토큰) + 나쁜 출력 목록 |
| `variants/cards/_supplement_en.txt` | 영어 틀에 붙이는 보강 (서버 한국어 보강 `ROUTINE_CREATE_SUPPLEMENT` 를 영어로, `{outputLanguage}` 자리) |
| `variants/cards/en_harness_v1.full.txt` | 운영 ko 지시문을 영어로 옮기고 언어 자리를 둔 안 |

변형:
- `prod`: 오늘 하네스 그대로 (운영 ko 지시문 + 한국어 보강 + ko 스키마). 입력 언어와 상관없이 같은 요청
- `en_template`: 서버 영어 틀 `MultilingualPromptDefaults.CREATE_TEMPLATE` 을 입력 언어의 `ContentLanguageSpec` 으로 채움 + 영어 보강 + 그 언어 스키마·호칭(ko `이룸이`, 그 밖 `Elumi`)
- `{outputLanguage}` 자리가 있는 `이름.full.txt`: `en_template` 과 같은 방식으로 언어마다 채움
- 서버 `ContentLanguageSpec` KO 는 어조·예시 칸이 비어 있어, 영어 틀을 ko 에 쓸 때는 `card_request.KO_TEMPLATE_FILL` 임시값을 쓴다

```bash
python3 run_cards.py --variant prod --case-file card_cases_multilang.json --repeat 2 --workers 3          # 호출 수만
python3 run_cards.py --variant prod --case-file card_cases_multilang.json --repeat 2 --workers 3 --yes
python3 run_cards.py --variant en_template --case-file card_cases_multilang.json --repeat 2 --workers 3 --yes
python3 card_multilang_report.py results/cards/prod__medium__multilang/<실행> results/cards/en_template__medium__multilang/<실행>
```

- 토큰은 `claude -p --output-format json` 의 `usage` (입력 = 새 입력 + 캐시 쓰기 + 캐시 읽기, 출력은 thinking 포함). 입력의 대부분은 픽토그램 목록이라 지시문 차이는 `지시문 글자` 칸으로 본다.
- `claude -p` 는 temperature 를 지정할 수 없다 (운영은 0). 반복 호출로 흔들림을 본다.
- 서버 반영 뒤(#1375): `MultilingualPromptDefaults.CREATE_TEMPLATE` 이 `en_harness_v1` 과 같은 글이고(원본은 서버), Claude 보강도 `{outputLanguage}` 자리가 있는 영어다.
  `--java-ref ""` 로 작업 폴더 자바를 읽으면 `en_template` = v1, 보강도 서버 문구를 읽는다. 옛 ref(origin/develop)에서는 `_supplement_en.txt`(서버 문구 사본)를 쓴다.
- `card_multilang_report.py` 는 lang 없는 옛 입력 세트(holdout2 등) 실행 폴더도 받는다 (언어는 ko 로 판정).
