# 카드 그림을 Cloudflare klein-4b 로: 캐릭터 대신 만화 아이 (설계)

- 근거 시험: #1257 (Cloudflare Workers AI 비교, 실측 단가·품질)
- 범위: 서버 + 명세 문서. 앱 화면은 바꾸지 않는다

## 왜

운영 카드 그림은 OpenAI `gpt-image-1-mini` low 로 1장 약 8.7원(추정)이다. #1257 에서 Cloudflare Workers AI `@cf/black-forest-labs/flux-2-klein-4b` 가

- 1장 104.2 neurons = $0.0011462 (약 1.66원), 크기와 무관 (실측 106장)
- 매일 첫 10,000 neurons (약 95장) 무료
- 품질은 약점 카드 8장 기준 ○7 △1 ×0 으로 schnell(○4)보다 낫다

로 나왔다. 루루·포포 캐릭터를 카드마다 같게 그리려면 참조 그림이 필요한데, 참조 그림을 넣으면 klein-4b 는 정면 자세만 베껴 동작이 사라졌다. 그래서 **카드 그림에서는 캐릭터를 빼고 성별이 드러나지 않는 만화 아이 한 명**으로 그린다 (사용자 결정).

## 목표

1. 그림 제공자에 `CLOUDFLARE` 를 더하고 운영 기본 제공자로 쓴다
2. Cloudflare 만화 그림은 캐릭터(루루·포포) 대신 만화 아이로 그린다. 프로필에 저장된 캐릭터는 그림에 쓰지 않는다
3. Cloudflare 실사 그림은 운영 실사 지시문을 그대로 쓴다
4. Cloudflare 가 실패하면 그 카드만 OpenAI 로 그린다 (기존 FLUX 규칙과 같다)
5. 관리자 화면에서 Cloudflare 호출 수·비용을 다른 제공자처럼 본다
6. 명세 문서의 "카드 그림에 캐릭터가 나온다" 를 "카드 그림은 만화 아이, 캐릭터는 앱 화면에만" 으로 고친다
7. 배포 후 보호자에게 "그림 품질을 높였어요" 공지를 관리자 화면으로 올린다 (문구는 사용자 확인 후)

## 하지 않는 것

- 앱 화면 변경: 캐릭터 고르기, 홈·보상 화면의 루루·포포는 그대로 둔다
- 성별 선택 옵션 (나중에 별도 이슈)
- 이미 만든 카드 그림 다시 그리기
- 기존 FLUX(fal) 제공자 삭제 (선택지로 남긴다)
- Cloudflare 계정 다중화, Workers Paid 상시 구독 (무료 한도 넘는 날은 OpenAI 로 넘어간다)

## 하면 실패인 것

- 무료 한도 초과·장애·NSFW 거절 때 카드가 그림 없이 남거나 화면이 깨지는 것
- 루루·포포를 고른 보호자의 앱 화면에서 캐릭터가 사라지는 것
- 운영 DB 의 기존 설정·지시문이 배포로 덮이는 것
- 토큰이 로그·응답·화면에 노출되는 것

## 정한 것 (사용자 결정)

| 항목 | 값 |
|---|---|
| 모델 | `@cf/black-forest-labs/flux-2-klein-4b`, 참조 그림 없음 |
| 그림 크기 | 512x376 (카드 칸 비율 1.36, 단가는 크기와 무관하고 앱이 WebP 로 다시 압축) |
| 캐릭터 | 카드 그림에서만 뺀다. 앱 화면은 그대로 |
| 성별 | 드러나지 않게. 선택 옵션은 나중 |
| 예비 | 실패하면 OpenAI |

## 만화 아이 지시문

화풍은 운영 `FLUX_ROUTINE_IMAGE_PREFIX` 그대로 쓰고 캐릭터 생김새 자리만 바꾼다.

```
{FLUX_ROUTINE_IMAGE_PREFIX} Only one character: {아이 생김새}. {영어 장면, The character > The child}
```

성별 중립 후보 3개를 약점 카드 8장으로 시험했다 (#1257, 품질은 모두 ○6 △2 로 비슷). 단발머리(v1)는 여자아이로, 짧은 머리 두 안은 남자아이로 보여 **바가지 머리 + 주황 후드티(n2)** 로 정했다 (내 판단, 관리자 화면에서 바꿀 수 있음).

```
a simple cartoon child with a round head, short black bowl-cut hair, dot eyes, rosy cheeks, a plain orange hoodie and gray long pants
```

이 생김새는 새 지시문 키로 DB 에 시딩해 관리자 화면에서 바꿀 수 있게 한다.

## 확장성: 나중에 캐릭터별 생김새를 더할 수 있게 (사용자 요청)

카드 그림에 "누구를 그릴지"를 코드에 박지 않고 **그림 인물(card image subject)** 이라는 한 지점으로 모은다.

- 그림 인물마다 영어 생김새 지시문 키를 둔다. 지금은 `CHILD`(만화 아이) 하나이고, 기본값은 코드에 두되 DB `prompt_template` 에 시딩해 관리자 화면에서 고친다
- 지금은 모든 카드가 `CHILD` 를 쓴다. 나중에 캐릭터별 그림을 다시 열 때는 그림 인물을 하나 더하고(예: 루루용 생김새 키) 프로필 캐릭터 > 그림 인물 매핑만 바꾸면 된다. 제공자 클라이언트와 생성 흐름은 고치지 않는다
- 장면 주어 치환(`The character` > `The child`)도 그림 인물이 가진 짧은 이름으로 한다
- 성별 옵션도 같은 자리에 그림 인물을 더하는 방식으로 넣을 수 있다

## 지시문 관리

- 화풍(`FLUX_ROUTINE_IMAGE_PREFIX`), 그림 인물 생김새(새 키), 실사 지시문·번역 지시문은 모두 DB `prompt_template` 에서 관리한다. 새 키만 첫 기동에 시딩되고 기존 운영 값은 덮지 않는다
- 관리자 지시문 화면에서 Cloudflare 로 바로 시험해 볼 수 있게 한다 (기존 FLUX 시험과 같은 방식)

## 동작 구조 (기존 구조 위에)

- `ImageProvider` 에 `CLOUDFLARE("Cloudflare (klein-4b)", PRICE_CLOUDFLARE_IMAGE_PER_IMAGE)`. 시스템 설정 `IMAGE_PROVIDER_SELECTED` 허용값에 `CLOUDFLARE`
- 지금 `CardImageGenerator` 는 "FLUX 면 영어 장면 경로, 아니면 장면 정보 경로" 로 나뉜다. 이 분기를 "영어 장면을 쓰는 제공자(FLUX, CLOUDFLARE)" 로 넓힌다. 영어 장면 획득(글 AI 의 `imagePromptEn` > 없으면 번역), 실사 번역, 실패 시 OpenAI 로 넘기기는 그대로 재사용한다
- `CloudflareImageClient`: `POST /client/v4/accounts/{accountId}/ai/run/{model}`, multipart (`prompt`, `width`, `height`, `seed`), 응답 `result.image` base64. HTTP 클라이언트는 `AiRestClientFactory` 를 쓴다. 호출 기록은 새 `AiCallType.CLOUDFLARE_IMAGE` / `AiProvider.CLOUDFLARE` 로 남긴다
- seed 는 기존 `FluxSeed` 규칙(이룸이 + 일과 제목)을 그대로 쓴다
- Cloudflare 경로에서 OpenAI 로 넘어간 카드도 캐릭터 없이 그린다 (characterType 을 넘기지 않아 기존 "캐릭터 없음" 인물로 그린다). 카드 그림에서 캐릭터를 뺀다는 결정을 예비 경로에도 지킨다

### 설정 (DB `system_config`, `ConfigKey` 로 시딩. yml·.env 변경 없음)

| 키 | 형식 | 기본값 |
|---|---|---|
| `CLOUDFLARE_ACCOUNT_ID` | STRING | 빈 값 |
| `CLOUDFLARE_API_TOKEN` | SECRET (암호화 저장) | 빈 값 |
| `CLOUDFLARE_IMAGE_MODEL` | STRING | `@cf/black-forest-labs/flux-2-klein-4b` |
| `PRICE_CLOUDFLARE_IMAGE_PER_IMAGE` | 단가 (USD/장) | `0.0011462` (무료 한도 안은 실제 0 이지만 보수적으로 유료 단가로 추정) |

- 키가 없으면 그 제공자를 고를 수 없게 막는 기존 규칙을 Cloudflare 에도 적용한다
- 운영 토큰은 Workers AI 권한만 있고 만료 없는 토큰을 새로 만들어 관리자 화면에 입력한다 (시험 토큰은 11/18 만료)

## 실패 경로

| 상황 | Cloudflare 응답 | 처리 |
|---|---|---|
| 하루 무료 한도 초과 (무료 플랜) | 429, code 4006 | 그 카드만 OpenAI |
| NSFW 오탐 | 400, code 8007 | 그 카드만 OpenAI |
| 입력 오류·장애·타임아웃 | 4xx/5xx/timeout | 그 카드만 OpenAI |
| 토큰·계정 ID 없음 | 호출 전 | 그 카드만 OpenAI, 관리자 화면에서 선택 불가 |
| OpenAI 도 실패 | - | 기존대로 부르는 쪽이 기본 그림으로 덮는다 |

품질 실패(동작을 못 그림)는 API 가 성공으로 끝나 잡지 못한다 (기존 FLUX 와 같다).

## 검증

- 서버 테스트: 제공자 분기(CLOUDFLARE 면 영어 장면 경로), 요청 본문(모델·크기·seed·prompt 모양, 캐릭터 생김새 없음), 실패 코드별 OpenAI 로 넘기기, 키 없을 때 선택 막기, 단가 계산. 관련 테스트만 골라 돌린다
- 로컬 DB 리허설: 새 설정 키·지시문 키 시딩, 기존 값 보존
- 실제 호출: 로컬 서버에서 Cloudflare 로 일과 1개 생성 (무료 한도 안)
- 배포 후: 운영에서 일과 1개 생성, 서버 로그와 관리자 비용 화면 확인

## 문서

- `docs/03-screens.md`, `docs/01-overview.md`, `docs/08-design-principles.md`, `docs/00-one-pager.md` 에서 카드 그림과 캐릭터를 설명한 문장을 고친다 (해커톤 자료는 그대로)
- `server/tool/prompt-eval/cloudflare/README.md` 를 최종 지시문으로 맞춘다

## 내 판단으로 정한 것 (검토 질문 반영)

1. **운영 전환 방법:** 코드 기본값 `IMAGE_PROVIDER_SELECTED` 는 새 DB 에서만 쓰이므로 `CLOUDFLARE` 로 바꾼다. 운영은 배포 후 관리자 화면에서 Account ID·토큰을 넣고 제공자를 `CLOUDFLARE` 로 바꾼다 (기존 값을 덮지 않는 원칙 유지)
2. **한도 초과가 반복되는 날:** 4006(하루 무료 한도 초과)을 한 번 받으면 다음 00:00 UTC 까지 Cloudflare 호출을 건너뛰고 바로 OpenAI 로 간다 (서버 메모리에만 기억, 재시작하면 다시 한 번 시도). 다른 실패는 카드마다 다시 시도한다
3. **캐릭터를 빼는 범위:** Cloudflare 로 그리는 카드와 그 카드가 OpenAI 로 넘어간 경우에 뺀다. 관리자가 제공자를 OpenAI·Gemini·FLUX 로 직접 되돌리면 지금 동작(캐릭터 포함)을 그대로 쓴다. 문제가 생겼을 때 예전 상태로 돌아갈 길로 남긴다

## 빌더 몫

- `CardImageGenerator` 분기를 넓히는 구체 방식 (공통 인터페이스, 라우터 메서드 등)
- 관리자 지시문 시험 화면(`AdminPromptService`)에서 Cloudflare 시험 지원 범위
- 성별 중립 생김새 최종안 (시험으로 고름)
