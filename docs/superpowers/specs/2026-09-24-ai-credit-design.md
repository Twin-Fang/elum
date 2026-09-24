# 무료 AI 크레딧 운영과 보호자 설정 표시 — 설계

- 이슈: https://github.com/Twin-Fang/elum/issues/407
- 작성: 2026-09-24
- 범위: 서버(장부·API·관리자) + 클라(설정 카드·생성 흐름)

## 0. 합의 사항

| 결정 | 값 | 출처 |
| --- | --- | --- |
| Free AI 그림 | 켠다. #247 픽토그램은 보류 | 사용자 선택 |
| 수동 카드 그림 | 서버 `POST /steps` 에 `generateImage` 명시 선택 + 크레딧. 앱 카드 추가 UI 는 만들지 않는다 | 사용자 선택 |
| 정책 시작 | 배포 즉시 켠다. 관리자에서 끌 수 있다(끄면 기존 횟수 한도로 복귀) | 사용자 선택 |
| 장부 모델 | 회원 계정 1행(잠금 지점) + 적립 묶음(grant) + 작업(job) + 원장(ledger) + 정책 버전 | 사용자 요청(확장성) |
| 재가입 | 장부를 유지한다. 소셜 신원 해시로 이어 붙인다 | 사용자 확인 |
| 관리자 보너스 만료 | 지급 때 고른다. 기본은 이번 주 말 | 기본값 |
| 장부 오류 | 막는다(fail-closed) | 기본값 |
| 잔액 0 에서 추가 질문 | 막는다 | 기본값 |
| 관리자 범위 | 개요·회원별·회원 상세·정책(영향 미리보기 포함)·작업 탐색·설정 이력 전부 1차 | 기본값 |
| 직전 안내 기준 | 사용 가능 < 1 + 최대 카드 수(10) = 11 | 기본값 |

## 1. 정책

- 회원 계정 단위 주간 지급. 기본 FREE 100 · PRO 100. 한국 시각 월요일 00:00 에 새 주기, 미사용분 이월 없음.
- 차감: 일과 글 1(`ROUTINE_TEXT`), 카드에 실제 적용된 새 AI 그림 1장당 1(`CARD_IMAGE`). 질문·재시도·대체 호출은 0.
- 잔액 ≥ 일과 글 단가(1) 일 때 시작한 AI 일과는 끝까지 만든다. 확정 차감은 `min(청구, 사용 가능)`, 모자란 부분은 초과(overage)로 기록, 잔액은 0 에서 멈춘다. 마이너스·빚 없음.
- 수동 카드 그림은 초과 허용이 없다. 사용 가능 ≥ `CARD_IMAGE` 단가여야 예약한다.
- 진행 중 작업은 시작 시점 정책 스냅샷(단가)을 쓴다. 확정된 거래는 재계산하지 않는다.
- 크레딧이 켜져 있으면 기존 하루·주간 일과 생성 횟수 한도는 검사하지 않는다. 보유 일과 최대 수·30초 쿨다운·서비스 전체 하루 비용 상한은 유지한다(비용 상한은 시작 전에만 검사, 진행 중 작업은 중단하지 않는다).

## 2. 데이터 모델 (`credit/` 도메인, Flyway `V26__create_ai_credit.sql`)

| 표 | 역할 | 주요 컬럼 |
| --- | --- | --- |
| `ai_credit_account` | 회원당 1행, 모든 증감의 잠금 지점 | id, member_id(유니크, nullable — purge 시 떼어냄), identity_key(유니크, 소셜 신원 SHA-256), status(ACTIVE/FROZEN) |
| `ai_credit_grant` | 적립 묶음 | id, account_id, source(WEEKLY/ADMIN_BONUS/PROMO/PURCHASE), amount, remaining, valid_from, expires_at(nullable=무기한), period_key(주간만, `(account_id, period_key)` 유니크), policy_version, ref_id |
| `ai_credit_job` | 생성 작업 1건 · 멱등 · 예약 | id, account_id, request_key(`(account_id, request_key)` 유니크), kind(ROUTINE_CREATE/CARD_IMAGE/IMAGE_REGENERATE), status(RESERVED/SETTLED/RELEASED/EXPIRED), reserved, charged, overage, image_count, card_count, policy_version, cost_snapshot(text JSON), routine_id, step_id, started_at, finished_at, fail_reason |
| `ai_credit_ledger` | 추가 전용 원장 | id, account_id, job_id, grant_id, type(GRANT/RESERVE/CONSUME/RELEASE/EXPIRE/ADJUST/OVERAGE), delta, balance_after, action, policy_version, actor, reason |
| `ai_credit_policy` | 정책 버전(추가 전용) | id, version(유니크), enabled, effective_from, weekly_grant(JSON `{"FREE":100,"PRO":100}`), action_costs(JSON `{"ROUTINE_TEXT":1,"CARD_IMAGE":1,"IMAGE_REGENERATE":1}`), reservation_ttl_minutes, grant_apply(NEXT_PERIOD/IMMEDIATE), created_by, reason |
| `system_config_history` | 시스템 설정 변경 이력 | id, config_key, old_value, new_value, changed_by, reason |

`ai_call_log.credit_job_id`(nullable, 인덱스) 추가 — `AiCallContext` 에 작업 id 를 실어 작업 하나의 실제 USD 를 대조한다.

### 잔액 규칙

- 사용 가능 = Σ 유효 grant.remaining − Σ RESERVED job.reserved. 유효 = `valid_from ≤ now < expires_at`(또는 무기한).
- 차감 순서: 만료 임박 grant 부터(무기한은 마지막).
- 주간 grant 는 그 주 첫 조회/요청 때 만든다(`INSERT … ON CONFLICT DO NOTHING` 대응 — JPA 에서는 존재 확인 후 저장, 계정 잠금 안이라 경쟁 없음). 지난 주 grant 에 remaining 이 남아 있으면 EXPIRE 원장을 남기고 remaining 을 0 으로.
- 모든 쓰기는 `ai_credit_account` 행 `SELECT … FOR UPDATE` 안에서.

### 재가입

- `identity_key = sha256("{provider}:{providerUserId}")`. 첫 소셜 로그인 계정 생성 시 계산해 account 를 찾고, 있으면 새 member 로 다시 연결한다.
- purge 시 account.member_id 를 null 로 뗀다(행·원장 유지). `WithdrawCoversMemberReferencesTest` 의 보관 목록에 등록.
- ⚠️ 탈퇴 뒤에도 소셜 신원 해시를 보관한다(남용 방지). 개인정보처리방침에 해당 보관이 적혀 있는지 확인 필요 — 법적 문구라 이 작업에서 고치지 않는다.

### 마이그레이션(기존 회원)

1. 표 생성(`IF NOT EXISTS`), `ai_call_log.credit_job_id` 추가.
2. 정책 v1 삽입(enabled=true, effective_from=마이그레이션 시각, 100/100, 1/1/1, TTL 15분).
3. ACTIVE·SUSPENDED 회원 전원 account 생성, identity_key 는 auth_identity 에서 첫 신원으로 계산(Postgres `sha256`), 이번 주 WEEKLY grant 100 + GRANT 원장(사유 "정책 시작 지급"). `ON CONFLICT DO NOTHING`.
4. 과거 `ai_call_log` 는 소급하지 않는다.
5. 빠진 회원·새 가입자는 첫 요청에서 자동 생성된다(같은 코드 경로).

## 3. 생성 흐름 · API

### AI 일과 생성 `POST /api/routines`

```
Idempotency-Key 헤더(없으면 서버가 UUID 생성 — 구버전 앱 호환)
1. 쿨다운 → (크레딧 꺼짐이면 기존 횟수 한도) → 비용 상한 → 보유 수 → 프로필 접근
2. reserve(ROUTINE_CREATE)  — 짧은 트랜잭션, 계정 잠금
   · 같은 키 SETTLED  → 저장된 일과를 그대로 반환(AI 재호출 없음)
   · 같은 키 RESERVED → 409 AI_CREDIT_JOB_IN_PROGRESS
   · 사용 가능 < ROUTINE_TEXT → 403 AI_CREDIT_INSUFFICIENT
   · 통과 → RESERVED, reserved=ROUTINE_TEXT, 정책 스냅샷 고정
3. AiCallContext(jobId) → 글 + 그림(기존 그대로)
4. RoutineCreationWriter.save 와 같은 트랜잭션에서 settle
   청구 = ROUTINE_TEXT + CARD_IMAGE × 붙은 그림 수, 차감 = min(청구, 사용 가능 + 이 작업 예약분), 나머지는 overage
5. 실패 → release(RELEASED, fail_reason)
```

응답 `RoutineResponse.credit = { cardCount, imageCount, charged, balanceAfter }` (크레딧 꺼짐이면 null).

### 추가 질문 `POST /api/routines/questions`

크레딧이 켜져 있고 사용 가능 < ROUTINE_TEXT 면 403 `AI_CREDIT_INSUFFICIENT`. 차감 없음.

### 수동 카드 `POST /api/routines/{id}/steps`

- 요청 `generateImage`(기본 false). false 면 그림을 만들지 않는다(자동 생성 폐지).
- true: 카드 저장 트랜잭션 안에서 reserve(CARD_IMAGE, 초과 허용 없음). 부족하면 카드는 저장하고 그림은 건너뛰며 응답 `imageSkippedReason="AI_CREDIT_INSUFFICIENT"`. 커밋 뒤 비동기 생성 → 적용 성공 settle / 실패·카드 삭제 release. 비용 상한·스로틀로 건너뛰면 release.
- 크레딧 꺼짐이면 true 일 때 예전처럼 비용 상한·스로틀만 보고 생성.

### 조회 `GET /api/credits/me`

```json
{ "enabled": true, "available": 72, "weeklyGrant": 100, "bonus": 0, "used": 28, "reserved": 0,
  "periodStart": "2026-09-21T00:00:00", "nextResetAt": "2026-09-28T00:00:00",
  "costs": { "routineText": 1, "cardImage": 1 }, "maxCardsPerRoutine": 10,
  "inProgress": [{ "jobId": "…", "kind": "ROUTINE_CREATE", "startedAt": "…" }],
  "canStartRoutine": true, "canGenerateImage": true }
```

- `bonus` = 주간이 아닌 유효 grant 의 remaining 합. `weeklyGrant` = 이번 주 WEEKLY grant amount. `used` = 이번 주기 CONSUME 합.
- 조회 시 계정·주간 grant 를 보장하고 TTL 지난 예약을 만료시킨다.

### 에러 코드 (서버 `ErrorCode` ↔ 앱 `server_error_code.dart`)

| 코드 | 상태 | 문구 |
| --- | --- | --- |
| `AI_CREDIT_INSUFFICIENT` | 403 | 이번 주 크레딧을 모두 사용했어요. 월요일 0시에 다시 채워져요. |
| `AI_CREDIT_JOB_IN_PROGRESS` | 409 | 이미 만들고 있어요. 잠시 뒤에 확인해주세요. |
| `AI_CREDIT_ACCOUNT_FROZEN` | 403 | 지금은 AI 만들기를 쓸 수 없어요. |
| `AI_CREDIT_UNAVAILABLE` | 503 | 잠시 뒤에 다시 시도해주세요. |

### 실패 경로

| 상황 | 처리 |
| --- | --- |
| 장부 DB 오류로 reserve 실패 | 503 `AI_CREDIT_UNAVAILABLE` + error 로그(fail-closed) |
| settle 실패 | 일과 저장과 같은 트랜잭션 → 둘 다 롤백, 그림 파일 삭제, release |
| release 실패 | TTL 만료가 복구, 관리자 "멈춘 예약" 경고 |
| `ai_call_log` 기록 실패 | 크레딧은 정상. SETTLED 인데 연결 로그 0건 → 관리자 "대조 불일치" |
| 주 경계를 걸친 작업 | settle 시점 유효 grant 에서 차감(만료 임박 순) |
| 동시 요청 두 개(잔액 1) | 계정 잠금으로 직렬화, 뒤 요청 403 |
| 동결 계정 | 403 `AI_CREDIT_ACCOUNT_FROZEN` |

## 4. 관리자 (`/admin/credits`, 사이드 메뉴 "AI 크레딧")

1. 개요 — 주 선택, 활성 회원·지급·사용·예약·남음·초과(건수/크레딧)·반환·소진 회원, 모델별 실제 USD, 크레딧당 평균 원가, 행동별 작업당 평균 USD·호출 수, 경고(멈춘 예약·대조 불일치·크레딧 꺼짐·비용 상한 도달).
2. 회원별 `/admin/credits/members` — 지급/보너스/사용/예약/남음/초과·마지막 사용·상태, 검색·정렬·소진/초과/동결 필터, 페이지.
3. 회원 상세 `/admin/credits/members/{memberId}` — 잔액, 유효 grant, 조정 폼(지급/차감/동결/해제, 수량, 사유 필수, 만료: 이번 주 말/날짜/무기한, 미리보기), 작업 목록(연결 USD·호출 수, 멈춘 예약 수동 반환), 원장. `/admin/members/{id}` 에서 링크.
4. 정책 `/admin/credits/policy` — 현재 버전, 새 버전 발행(플랜별 지급량·단가·TTL·켜기/끄기·적용 시점 NEXT_PERIOD/IMMEDIATE·사유 필수), 영향 미리보기(대상 회원 수, 주간 지급 총량 변화, 지난 4주 사용으로 추정한 소진 회원 수, 지난 4주 크레딧당 원가 기반 예상 주간 USD), 버전 이력. 끄기는 확인 모달.
5. 작업 탐색 `/admin/credits/jobs` — 상태·종류·기간·초과 필터, request_key/jobId 검색.
6. 시스템 설정 변경 이력 — `SystemConfigService.update` 가 이력을 남긴다(변경자·이전→새 값·사유 선택). 설정 페이지에 이력 표시.

관리자 쓰기는 계정 잠금을 거치고 actor(관리자 로그인 id)를 원장에 남긴다.

## 5. 앱

- `CreditSummary`(서버 필드 그대로), `CreditRepository.getMine()`(실패 시 AppFailure, 0 대체 금지), `creditSummaryProvider`(autoDispose, 설정 진입·생성 완료/실패 후 invalidate).
- 생성 요청 `Idempotency-Key`: `카드 만들기`를 새로 누를 때 발급, 재시도는 같은 키.
- 설정 카드 `AiCreditCard`(제목 아래, 첫 타일 위): 로딩 자리표시 / 정상 / 보너스 / 적음(<11) / 0 / 진행 중 / 조회 실패(재시도 + 코드 `E-CREDIT`) / enabled=false 숨김. 새 색 토큰, 낭독기 한 덩어리, 글꼴 2.0 대응. 구매·플랜 표시 없음.
- 홈 일과 만들기: `canStartRoutine=false` 면 공통 팝업(이번 주 크레딧을 모두 사용했어요 / {다음 초기화}부터 다시 만들 수 있어요 / 확인). 조회 실패면 통과(서버가 판정).
- 생성 실패 화면: 크레딧 오류(INSUFFICIENT/IN_PROGRESS/FROZEN)면 `다시 하기` 대신 `홈으로`.
- 직전 안내(사용 가능 < 11): 추가 질문 화면 `카드 만들기` 위, 보상 화면 버튼 위. ⚠️ 시안 밖 요소 — 디자이너 협의 대상.
- 완료 표시: 카드 확인 머리 아래 `AI 그림 N장 · M크레딧 사용 · K 남음`(생성 응답 `credit`, 없으면 안 그림). ⚠️ 시안 밖 요소.
- 공지 `하루 2개·주 10개` 는 운영 `app_notice` — 배포 후 관리자에서 이슈 문구로 교체(배포 체크리스트).

## 6. 테스트

- 서버(JUnit5 + Mockito + 고정 Clock): 정산 산식(잔액 1·그림 8 → 차감 1·초과 8·잔액 0 / 4장 → 5), 멱등(같은 키 AI 1회·차감 1회), KST 주 경계, 보너스/주간 차감 순서, 재가입 재연결, TTL 만료, 부분 그림 실패, 수동 그림 초과 불허, 관리자 조정 미리보기=반영·차감 상한, 정책 NEXT_PERIOD/IMMEDIATE, 설정 이력, 기존 계약 테스트(탈퇴 참조·마이그레이션 추가 전용·예외 핸들러·템플릿 태그 균형).
- 앱: 모델 파싱 방어, 카드 상태별 위젯·글꼴 2.0, 설정 대조 렌더 갱신(사람 승인), 홈 막기, 생성 오류 재시도 숨김, 멱등 키 재사용, 에러 코드 동기화.
- 동시성의 DB 잠금 실제 동작은 배포 후 운영 실측으로 확인(Testcontainers 없음).

## 7. 범위 밖

인앱결제·Pro 구매·사용자 거래 내역 화면·앱 카드 추가 UI·그림 다시 생성 엔드포인트·#247 픽토그램.
