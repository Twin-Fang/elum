# Cloudflare Workers AI 카드 그림 시험 (#1257)

운영 설정을 바꾸지 않고 Cloudflare 무료 한도(하루 10,000 neurons, 00:00 UTC = 09:00 KST 초기화)로 카드 그림을 시험한다.

## 운영 프롬프트 (#1258 서버 반영)

- 모델: `@cf/black-forest-labs/flux-2-klein-4b`, 512x376, 참조 그림 없음, 일과마다 고정 seed
- 캐릭터: 루루·포포 대신 단순한 만화 아이 (참조 그림을 넣으면 정면 자세만 베껴 동작이 사라짐)

```
Flat vector illustration, simple picture-book style, thick dark brown outlines, flat soft pastel colors, plain light cream background, no shading. Wordless image, no letters anywhere. Only one character: a simple cartoon child with a round head, short black bowl-cut hair, dot eyes, rosy cheeks, a plain orange hoodie and gray long pants. {imagePromptEn, The character > The child}
```

- 화풍 문장은 운영 `FLUX_ROUTINE_IMAGE_PREFIX`, 생김새는 `CARD_IMAGE_SUBJECT_CHILD` (둘 다 DB 지시문, 관리자 화면에서 수정)
- 생김새는 성별 중립 후보 4개 중 바가지 머리·주황 후드티 (단발은 여자아이, 짧은 머리는 남자아이로 보임)
- 규칙 문장을 더하면 나빠짐 (정면으로 서서 물건만 드는 그림 증가)

## 실측 단가 (GraphQL `aiInferenceAdaptive`, 건별)

| 모델 / 설정 | neurons | 유료 환산 | 생성 시간 |
|---|---|---|---|
| flux-1-schnell 1024 정사각 4 steps | 172.8 | 약 2.8원 | 평균 1.7초 |
| flux-2-klein-4b 1152x848 | 104.2 | 약 1.7원 | 평균 6.1초 |
| flux-2-klein-4b 1152x848 + 참조 그림 | 104.75 | 약 1.7원 | 평균 2.8초 |

- klein-4b 는 크기와 무관하게 1장 104.2 neurons (512x376·696x512·1024x752 실측 같음)
- 한도 초과(4006), 입력 오류(5006), NSFW 거절(8007)은 0 neurons
- 유료 환산: $0.011 / 1,000 neurons, 1달러 1,450원

## 실행

```bash
cd server/tool/prompt-eval
python3 cloudflare/make_text.py      # 카드 글 (claude -p Haiku) > results/cloudflare/texts.json
python3 cloudflare/make_images.py    # 그림 + 컨택트 시트 > results/cloudflare/
python3 cloudflare/usage_query.py    # 오늘(UTC) 건별 neurons
```

- `.env.local` 에 `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`(Workers AI), `CLOUDFLARE_ANALYTICS_TOKEN`(분석 읽기). 값은 출력하지 않는다
- 그림 결과는 `results/` (커밋 안 함)
