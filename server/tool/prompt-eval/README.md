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
