# 일과 생성 프롬프트 평가 하네스

보호자 입력 38건(초단문, 장문, 오타, 정상, 모호, 감정, 준비물, 위험 입력, 복합, 짧은 행동)을 실제 Gemini 로 돌려
카드 글과 카드 그림을 같은 기준으로 비교한다. AI 모델은 바꾸지 않고 프롬프트·스키마·전처리만 바꾼다.

```bash
cd server/tool/prompt-eval
python3 run_text.py baseline                       # 현재 코드 기본값으로 38건
python3 run_text.py v3                             # variants/v3 의 프롬프트·스키마로 38건
python3 show.py v3 --cases e02,t05                 # 카드 글 보기
python3 run_image.py v3 --cases t05,l03 --max-steps 6   # 카드 그림 + 컨택트 시트 (results/v3/images/sheet_*.png)
```

- API 키는 `server/src/main/resources/application-dev.yml` 의 `gemini.api-key` 에서 읽고 출력하지 않는다.
- 서버와 같은 요청을 만든다: 사용자 메시지 JSON, 응답 스키마, 캐릭터 참조 PNG, 그림 지시문 조립.
- `variants/<이름>/` 의 `create.txt`(생성 지시문), `image.txt`(그림 지시문), `variant.json`(스키마 설명, 그림 장면 모드)이
  baseline 을 덮어쓴다. 없으면 현재 코드 기본값(`PromptDefaults`)을 쓴다.
- 자동 지표(run_text.py `measure`)는 구조 위반만 센다(제목 어절, 설명 길이, 행동 연결, 금지어, 개인정보). 의미와 그림 품질은 사람이 시트로 본다.
- 결과 폴더 `results/` 는 커밋하지 않는다.
