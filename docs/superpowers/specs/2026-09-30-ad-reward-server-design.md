# 보상형 광고 크레딧 지급 — 서버 설계 (#463)

2026-09-30 · 관련: #281(광고 기반) · #464(클라 화면) · #368(비용 상한) · #407(주간 크레딧)
상위 설계: `2026-09-30-admob-ads-design.md` §7

**이 기능은 크레딧(= AI 비용)을 만들어 낸다. 잘못되면 비용이 새거나 사용자가 보상을 못 받는다.
그래서 안정성을 기능보다 위에 둔다.**

## 1. 목표

- 보호자가 보상형 광고를 끝까지 보면 **서버가 Google 서명으로 확인한 뒤에만** AI 생성 크레딧을 준다.
- 클라이언트가 "봤다"고 알리는 방식은 쓰지 않는다(조작 가능).

비목표: 클라 화면(#464), 미디에이션, 광고 노출 통계, Pro 요금제 연동.

## 2. 불변식 (어떤 경로로도 깨지면 안 되는 것)

| # | 불변식 | 지키는 장치 |
|---|---|---|
| I1 | Google이 서명한 콜백만 지급한다 | ECDSA 서명 검증. 검증 실패·키를 못 구함은 지급 안 함 |
| I2 | 한 번의 시청은 **최대 한 번** 지급된다 | 세션 상태 전이 `PENDING → GRANTED`를 계정 행 잠금 안에서 1회만 + `transaction_id` 유니크 + 지급 묶음 `ref_id` |
| I3 | 지급량은 서버가 정한다 | Google이 보낸 `reward_amount`·`reward_item`은 무시한다 |
| I4 | 지급은 상한 안에서만 | **계정별** 하루 지급 상한(재가입해도 이어진다), 세션 만료, 열린 세션 재사용, 동결 계정 차단 |
| I5 | **꺼져 있으면 아무 일도 없다** | `AD_REWARD_ENABLED` 기본 꺼짐. 배포만으로는 동작이 바뀌지 않는다 |
| I6 | 실패는 조용히 지급 안 함으로 끝나고 다른 API에 번지지 않는다 | 콜백은 독립 엔드포인트. 예외는 응답 코드로만 나간다 |
| I7 | 모든 지급은 추적할 수 있다 | 세션 행 + 지급 묶음 + 원장 한 줄. 비밀(nonce·서명)은 로그에 남기지 않는다 |
| I8 | 원장 합계가 항상 맞는다 | 지급은 기존 관리자 보너스와 같은 방식(계정 잠금 → 묶음 저장 → 원장 저장) |

## 3. 흐름

```
앱                                서버                               Google AdMob
│ ① POST /api/credits/ad-rewards/sessions
│ ─────────────────────────────▶ 켜짐·상한·동결 확인 → 세션(nonce) 저장
│ ◀───────── {nonce, expiresAt, creditsPerView, remainingToday}
│ ② 광고 요청 시 ServerSideVerificationOptions(customData = nonce)
│ ③ 광고 시청 완료 ─────────────────────────────────────────────▶ 시청 기록
│                                   ④ GET /api/ads/ssv?…&signature=… ◀── 서명한 콜백
│                                   서명 검증 → 세션 잠금 → 한 번만 지급
│ ⑤ GET /api/credits/ad-rewards/sessions/{nonce} (폴링)
│ ◀───────── {status: PENDING | GRANTED | REJECTED | EXPIRED, credits}
```

- nonce는 서버가 만든 32바이트 난수(URL-safe Base64)다. **콜백이 어느 회원의 시청인지는 nonce로만 안다** — 앱이 보내는
  `user_id`는 신뢰하지 않는다.
- 세션은 회원당 **열린 것 하나를 재사용**한다(같은 회원이 세션을 계속 만들어 표를 키우지 못하게).
- 지급된 묶음은 **이번 주 끝(다음 월요일 0시)에 만료**된다. 광고 크레딧이 무기한으로 쌓이는 것을 막는다.

## 4. API

| 메서드·경로 | 누가 | 하는 일 |
|---|---|---|
| `GET /api/credits/ad-rewards/offer` | 보호자(JWT) | `{enabled, creditsPerView, remainingToday}` — 앱이 "광고 보고 더 만들기"를 보일지 정한다 |
| `POST /api/credits/ad-rewards/sessions` | 보호자 | 세션을 만든다. 꺼짐·상한 도달·동결이면 거절 |
| `GET /api/credits/ad-rewards/sessions/{nonce}` | 보호자(본인 세션만) | 상태 확인 |
| `GET /api/ads/ssv` | **공개**(서명이 인증) | Google 서버 콜백 |

- 이룸이(ELUMI) 권한으로는 앞의 세 개를 못 쓴다(`/api/**` 기본 규칙이 GUARDIAN이다). 광고는 보호자 화면에만 있다.

## 5. 서명 검증 (Google SSV)

- 콜백은 `?ad_network=…&ad_unit=…&custom_data=…&reward_amount=…&reward_item=…&timestamp=…&transaction_id=…&user_id=…&signature=…&key_id=…`.
- `signature`와 `key_id`는 **항상 마지막 두 파라미터**다. 검증 대상은 `&signature=` 앞까지의 **원문 쿼리 문자열**(디코딩하지 않는다).
- 서명은 URL-safe Base64(패딩 없음)의 DER ECDSA, 알고리즘 `SHA256withECDSA`.
- 공개키: `https://www.gstatic.com/admob/reward/verifier-keys.json` 의 `keys[].keyId` / `base64`(X.509 DER).
  - 메모리에 24시간 캐시하고, **모르는 `key_id`가 오면** 5분에 한 번만 다시 받는다.
  - 키를 받지 못하면 **503**(지급 안 함). 이전 캐시가 있으면 그것으로 검증한다.
- 서명이 없거나 형식이 틀리거나 검증에 실패하면 **400**. 로그에는 사유만 남긴다.
- 추가 확인: `ad_unit`이 허용 목록(설정)에 있어야 한다. `ad_unit`은 광고 단위 ID의 슬래시 뒤 숫자다.

## 6. 콜백 처리 순서와 응답 코드

서명 검증을 통과한 뒤에는 **비즈니스 거절도 200으로 답한다**(Google이 의미 없이 다시 보내지 않게). 실패 사유는 세션에 남긴다.

| 순서 | 검사 | 통과하지 못하면 | 응답 |
|---|---|---|---|
| 1 | 서명 | 지급 안 함 | 400 |
| 2 | 공개키 확보 | 지급 안 함 | 503 |
| 3 | `AD_REWARD_ENABLED` | 세션 `REJECTED(DISABLED)` | 200 |
| 4 | `ad_unit` 허용 | 세션 `REJECTED(AD_UNIT)` | 200 |
| 5 | nonce로 세션 조회 | 없음 → 아무것도 안 함(로그만) | 200 |
| 6 | 계정 잠금 후 세션 상태 | 이미 `GRANTED`·같은 `transaction_id` → 그대로 성공(멱등) | 200 |
| 7 | 세션 `PENDING`·미만료 | `EXPIRED`/`REJECTED(NOT_PENDING)` | 200 |
| 8 | 계정 동결 아님 | `REJECTED(FROZEN)` | 200 |
| 9 | 오늘 지급 횟수 < 상한(권위 있는 검사). **계정의 `AD_REWARD` 묶음 수**로 센다 | `REJECTED(DAILY_LIMIT)` | 200 |
| 10 | 지급: 묶음 + 원장 + 세션 `GRANTED` | DB 오류는 롤백, 세션은 그대로 `PENDING` | 500(재시도) |

- 6~10은 **한 트랜잭션**이고 계정 행을 `FOR UPDATE`로 잡은 안에서 일어난다. 같은 회원의 동시 콜백 둘은 한 줄로 선다.
- 서로 다른 회원이 같은 `transaction_id`를 동시에 쓰는 경우는 유니크 제약이 막는다(한쪽 500 → 재시도 시 중복으로 처리).

## 7. 데이터 (`V30__create_ad_reward_session.sql`)

`ad_reward_session`: `id`, `member_id`(외래키 없음), `nonce`(유니크), `status`, `expires_at`, `granted_at`,
`granted_credits`, `reject_reason`, `transaction_id`(유니크, null 허용), `grant_id`, `created_at`, `updated_at`.
인덱스: `(member_id, status, expires_at)`.

- **하루 상한은 세션이 아니라 크레딧 계정의 `AD_REWARD` 지급 묶음(`valid_from` ≥ 오늘 0시) 수로 센다.** 크레딧 계정은 소셜
  신원으로 재가입 뒤에도 이어지지만 회원 ID는 새로 생긴다. 회원 ID로 세면 탈퇴·재가입만으로 오늘 상한이 리셋된다
  (독립 검토 전 자체 점검에서 발견해 고쳤다).
- **탈퇴하면 세션을 지운다**(`MemberService.withdraw`, 완전 삭제에서도 정리). 세션은 회원을 가리키는 운영 기록이라 남길
  이유가 없고, 받은 크레딧은 묶음·원장에 남는다. 안전장치 테스트(`WithdrawCoversMemberReferencesTest`)가 요구한다.

- 기존 표는 건드리지 않는다(추가만). 옛 서버 이미지로 되돌려도 문제없다(V26·V27과 같은 약속).
- `CreditGrantSource`에 `AD_REWARD`를 더한다(문자열 저장이라 마이그레이션 없음).

## 8. 설정 (관리자 화면 그룹 "광고 보상")

| 키 | 기본값 | 뜻 |
|---|---|---|
| `AD_REWARD_ENABLED` | `false` | **꺼짐이 기본.** 켜야 세션이 만들어지고 콜백이 지급된다 |
| `AD_REWARD_CREDITS_PER_VIEW` | `2` | 시청 1회당 지급 크레딧(정수). 비용 대비 수익을 보고 조절 |
| `AD_REWARD_DAILY_LIMIT` | `5` | 회원별 하루(한국 시각 0시 시작) 지급 상한 |
| `AD_REWARD_SESSION_TTL_MINUTES` | `30` | 세션 유효 시간 |
| `AD_REWARD_ALLOWED_AD_UNITS` | 이룸 보상형 단위 2개의 숫자 ID | 쉼표 목록. 전체 ID(`ca-app-pub-…/…`)도 받는다 |

- 값이 이상하면(음수·비정수) 안전한 쪽으로 읽는다: 지급량·상한이 0 이하면 지급하지 않는다.
- 서비스 전체 하루 AI 비용 상한(#368)은 **생성 시점**에 그대로 걸린다. 광고로 받은 크레딧도 그 상한을 넘겨 쓰지 못한다.

## 9. 실패 경로 (화면이 아니라 서버 동작)

| 상황 | 동작 |
|---|---|
| Google 키를 못 받음 | 503, 지급 없음. 캐시가 있으면 캐시로 검증 |
| 콜백이 두 번 옴(재시도) | 두 번째는 멱등 성공, 지급 한 번 |
| 콜백이 nonce 없이 옴 | 200, 지급 없음, 로그 |
| 세션 만료 뒤 콜백 | 200, `EXPIRED`, 지급 없음 |
| 하루 상한 도달 | 세션 생성 단계에서 거절, 콜백 단계에서도 거절 |
| DB 오류 | 500, 세션은 `PENDING`으로 남아 Google 재시도 때 다시 처리 |
| 기능을 끔 | 새 세션 불가. 이미 열린 세션의 콜백은 `DISABLED`로 거절 |
| 서버 재시작 | 세션은 DB에 있어 그대로 이어진다 |

## 10. 롤아웃 (사고 방지 순서)

1. **꺼진 채로 배포**한다. 운영 동작이 바뀌지 않는다.
2. AdMob 콘솔에서 이룸 보상형 광고 단위 2개에 SSV 콜백 URL `https://api.elum.chuseok22.com/api/ads/ssv`를 등록한다
   (앱 인증·계정 승인 뒤 가능).
3. 콘솔의 SSV 콜백 시험 도구로 검증 통과 여부를 본다.
4. 관리자 화면에서 소수 값(`CREDITS_PER_VIEW=1`, `DAILY_LIMIT=1`)으로 켜고 QA 계정으로 한 번 확인한다.
5. 원장·세션 표를 보고 정상이면 값을 올린다. 이상하면 **끄기 한 번으로 멈춘다.**

## 11. 테스트

- 서명 검증: 올바른 서명 / 한 글자 바꾼 쿼리 / 다른 키 / 서명 없음 / `key_id` 모름 / 키 못 구함
- 지급: 정상 1회, **같은 콜백 두 번 → 1회**, 같은 `transaction_id`·다른 nonce → 1회, 만료, 동결, 꺼짐, 하루 상한, `ad_unit` 불일치, 알 수 없는 nonce
- 세션: 열린 세션 재사용, 상한 도달 시 생성 거절, 본인 세션만 조회
- 원장: 지급 뒤 사용 가능량이 `creditsPerView`만큼 늘고 원장 합계가 맞는다
- 설정 기본값: 꺼짐, 이상한 값 처리
- 기존 서버 테스트 전체가 그대로 통과해야 한다

## 12. 열린 것

- 세션 표는 정리하는 배치가 없다(회원당 하루 최대 상한 수만큼 쌓인다). 규모가 커지면 오래된 `EXPIRED`·`REJECTED` 행을 지운다.
- 역방향 프록시가 쿼리의 퍼센트 인코딩을 바꿔 전달하면 서명이 어긋난다. 롤아웃 3단계의 콘솔 시험 도구로 확인한다.
- 교환 비율(`CREDITS_PER_VIEW`)의 실제 값은 운영 eCPM을 보고 정한다(기본 2는 보수적인 시작값).
- 클라 화면 시안(#468)이 나오기 전에는 앱이 이 API를 부르지 않는다. 서버는 꺼진 채로 먼저 나간다.
