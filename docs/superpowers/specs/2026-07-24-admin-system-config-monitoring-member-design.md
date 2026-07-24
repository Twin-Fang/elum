# 관리자 고도화 설계 — SystemConfig 동적 설정 · AI 호출 모니터링 · 회원 활동 추적 · 회원 관리 화면

- 작성일: 2026-07-24
- 대상 모듈: `server/` (Spring Boot)
- 배경: Gemini 모델명·이미지 파라미터 등이 yml/코드에 고정되어 변경 시 재배포가 필요하고,
  회원별 AI 사용량(토큰·비용)을 알 수 없어 향후 구독제 전환 준비가 불가능하다.
  회원 관리 화면도 단순 목록 수준이라 운영 조치(정지·강제 로그아웃)가 불가능하다.

## 전체 구성 (기능 4개, 이슈 4건으로 분리)

| # | 기능 | 핵심 산출물 |
|---|---|---|
| 1 | SystemConfig 동적 설정 관리 | `system_config` 테이블 + 메모리 캐시 + `/admin/settings` 화면 |
| 2 | AI 호출 모니터링·토큰/비용 추적 | `ai_call_log` 테이블 + usageMetadata 파싱 + `/admin/monitoring` 화면 |
| 3 | 회원 활동 추적·정지·강제 로그아웃 | Member 상태/활동 컬럼 + 로그인·JWT 필터 연동 + 관리자 조치 API |
| 4 | 회원 관리 화면 고도화 | 검색·필터·페이지네이션 + 사용량 통계 + 상세 화면 개편 + 대시보드 보강 |

## 공통 전제

- **prod는 `ddl-auto: validate`** — 모든 스키마 변경은 Flyway 마이그레이션으로 작성한다
  (V6 system_config, V7 ai_call_log, V8 member 활동 컬럼). `IF NOT EXISTS`로 로컬(update)과 양립.
- 기존 패턴 준수: `PromptTemplate`(엔티티 + Initializer 시딩 + 서비스 + 관리자 MVC 화면),
  관리자 컨트롤러는 `@Controller` + RedirectAttributes flash, UI는 Tailwind CDN + daisyUI 4.
- 다중 세션 동시 작업 전제: 내가 만든 파일만 명시 스테이징, 기능별 커밋 분리.

---

## 기능 1 — SystemConfig 동적 설정 관리

### 데이터 모델

새 도메인 `systemconfig/`(core·application·infrastructure)를 만든다.

- `ConfigKey` enum (core): `group`(ConfigGroup), `label`, `description`, `valueType`(STRING/INTEGER/DECIMAL/SELECT),
  `allowedValues`(SELECT용), `defaultValue`를 가진다.

| 키 | 그룹 | 타입 | 기본값 | 적용 지점 |
|---|---|---|---|---|
| GEMINI_TEXT_MODEL | Gemini 텍스트 | STRING | yml 값으로 시딩 | GeminiTextClient |
| GEMINI_TEXT_TEMPERATURE | Gemini 텍스트 | DECIMAL | 0 | GeminiTextClient generationConfig |
| GEMINI_IMAGE_MODEL | Gemini 이미지 | STRING | yml 값으로 시딩 | GeminiImageClient |
| GEMINI_IMAGE_ASPECT_RATIO | Gemini 이미지 | SELECT(1:1, 4:3, 3:4, 16:9, 9:16) | 4:3 | GeminiImageClient imageConfig |
| LOCAL_LLM_MODEL | 로컬 LLM | STRING | yml 값으로 시딩 | SensitiveInfoGuardService |
| PRICE_GEMINI_TEXT_INPUT_PER_1M | 요금 | DECIMAL | 0.30 | 비용 계산(기능 2) |
| PRICE_GEMINI_TEXT_OUTPUT_PER_1M | 요금 | DECIMAL | 2.50 | 비용 계산(기능 2) |
| PRICE_GEMINI_IMAGE_PER_IMAGE | 요금 | DECIMAL | 0.039 | 비용 계산(기능 2) |

- `SystemConfig` 엔티티: id(UUID), configKey(unique), value(TEXT). BaseEntity 상속.
- `SystemConfigInitializer`(ApplicationRunner): 키가 없으면 기본값으로 시딩.
  모델명 3종은 GeminiProperties/LocalLlmProperties에 값이 있으면 그 값을 기본값으로 사용
  (yml을 읽지 않고 이미 바인딩된 properties 빈을 주입받아 사용).

### 캐시 전략 (다중 레플리카 대응)

`SystemConfigService`가 전체 키를 `ConcurrentHashMap`에 올려두고,
마지막 로드로부터 **30초가 지나면 다음 조회 때 전체 리로드**한다(TTL 캐시).
`update()`는 저장 직후 해당 인스턴스 캐시를 즉시 갱신하고, 다른 레플리카는 TTL로 30초 내 수렴한다.
DB가 단일 진실 공급원이므로 재시작해도 값이 유지된다.

- 타입별 getter: `getString(key)` / `getInt(key)` / `getDouble(key)`.
- `update(key, value)`: valueType별 파싱 검증 + SELECT는 allowedValues 검증.
  실패 시 `SYSTEM_CONFIG_INVALID_VALUE`(400). 성공 시 저장 + 캐시 즉시 갱신.
- `resetToDefault(key)`: 기본값(시딩 규칙과 동일)으로 되돌린다.
- **실패 경로**: 캐시 리로드 중 DB 예외가 나면 기존 캐시를 유지한 채 경고 로그만 남긴다
  (설정 조회 실패가 AI 호출 전체를 죽이면 안 된다). 키가 캐시에 없으면 enum 기본값으로 동작.

### 클라이언트 연동

- `GeminiTextClient`: `geminiProperties.textModel()` → `systemConfigService.getString(GEMINI_TEXT_MODEL)`,
  temperature도 config에서 읽는다.
- `GeminiImageClient`: 모델명·aspectRatio를 config에서 읽는다.
- `SensitiveInfoGuardService`: `localLlmProperties.model()` → config.
- timeout·baseUrl은 RestClient 빈 생성 시점에 고정되므로 **동적 대상에서 제외**한다(재배포 필요 항목).

### 관리자 화면

- `GET /admin/settings`: 그룹별 카드로 표시. SELECT는 셀렉트박스, 나머지는 인풋.
  현재값이 기본값과 다르면 "변경됨" 배지. 각 키에 저장/기본값 복원 버튼.
- `POST /admin/settings/{key}` 저장, `POST /admin/settings/{key}/reset` 복원. flash 메시지로 결과 안내.
- 사이드바에 "시스템 설정" 메뉴 추가.

---

## 기능 2 — AI 호출 모니터링 · 토큰/비용 추적

### 데이터 모델

- `AiCallLog` 엔티티(ai/infrastructure/entity): id, memberId(nullable — 관리자 테스트 호출),
  callType(`AiCallType` enum: GEMINI_TEXT_CREATE / GEMINI_TEXT_QUESTION / GEMINI_IMAGE / LOCAL_LLM_DLP /
  ADMIN_TEST_*), model, success, errorMessage(500자 절단), latencyMs,
  promptTokens, outputTokens, totalTokens, estimatedCostUsd(double). BaseEntity 상속.
- 인덱스: (member_id, created_at), (created_at), (call_type).
- `GeminiGenerateContentResponse`에 `UsageMetadata`(promptTokenCount, candidatesTokenCount,
  totalTokenCount) record 추가 — Gemini 응답의 usageMetadata를 파싱한다.

### 기록 방식

- `AiCallContext`: `InheritableThreadLocal<String>`에 memberId를 담는 컨텍스트 홀더.
  `RoutineService`가 AI 파이프라인 진입 전 set, finally에서 clear.
  (RoutineAiPipeline의 가상 스레드 이미지 병렬 생성에도 InheritableThreadLocal이 전파된다.)
- 각 클라이언트(GeminiTextClient/GeminiImageClient/LocalLlmClient)가 호출 완료/실패 시
  `AiCallLogService.record(...)`를 호출한다. 성공 시 usageMetadata에서 토큰을 뽑고,
  기능 1의 요금 설정으로 비용을 계산해 함께 저장한다.
  - 텍스트: promptTokens/1M×입력단가 + outputTokens/1M×출력단가
  - 이미지: 건당 고정 단가
  - 로컬 LLM: 자체 호스팅이므로 0
- **실패 경로**: 로그 저장 실패는 원 호출을 실패시키지 않는다 — `log.warn`으로 남기고 계속 진행.
  기록은 `REQUIRES_NEW` 트랜잭션으로 분리해 본 트랜잭션 롤백에 휩쓸리지 않게 한다.

### 관리자 화면

- `GET /admin/monitoring`: 상단 stat 카드(오늘 호출수·성공률·평균 지연·오늘 토큰·오늘 추정비용,
  전체 누적 호출수·누적 비용) + 최근 호출 테이블(시각·유형·모델·회원·성공·지연·토큰·비용).
- 필터: callType, 성공/실패. 페이지네이션(50건 단위). 회원 컬럼은 회원 상세로 링크.
- 사이드바에 "AI 모니터링" 메뉴 추가. 대시보드에도 요약 카드 노출(기능 4에서).

---

## 기능 3 — 회원 활동 추적 · 계정 정지 · 강제 로그아웃

### 데이터 모델 (Member 컬럼 추가)

- `status`: `MemberStatus`(ACTIVE/SUSPENDED), 기본 ACTIVE
- `lastLoginAt`, `lastActivityAt`: nullable
- `loginCount`: int, 기본 0
- `tokenInvalidBefore`: nullable — 이 시각 이전에 발급된 JWT는 거부(강제 로그아웃)

### 동작

- **로그인(AuthService)**: 인증 성공 후 status가 SUSPENDED면 `MEMBER_SUSPENDED`(403).
  성공 시 lastLoginAt·lastActivityAt 갱신, loginCount 증가.
- **JWT 필터**: 토큰이 유효하면 `MemberAccessGuard`(신규, member 도메인)로
  ① 회원 존재+ACTIVE 확인 ② 토큰 iat < tokenInvalidBefore면 거부 ③ lastActivityAt을
  **60초에 1회로 스로틀**해 갱신(요청마다 UPDATE가 나가지 않게). 거부되면 인증을 세팅하지
  않아 기존 EntryPoint가 401을 반환한다. 가드 내부 DB 예외는 요청을 죽이지 않고
  인증만 통과시키되 경고 로그를 남긴다(가용성 우선).
- **관리자 조치**: `POST /admin/members/{id}/suspend | /unsuspend | /force-logout`.
  force-logout은 tokenInvalidBefore=now로 설정 — 이후 기존 토큰 전부 401.
  suspend는 로그인+API 사용 모두 차단, unsuspend로 복구.

---

## 기능 4 — 회원 관리 화면 고도화

### 목록 (`/admin/members`)

- 검색(아이디/닉네임 부분일치), 상태 필터(전체/활성/정지), 페이지네이션(20건, Pageable).
- 컬럼: 닉네임·아이디·캐릭터·상태 배지·도움방식·별·루틴수·AI 호출수·총 토큰·추정 비용·
  최근 활동·가입일·조치(정지/해제 버튼).
- 루틴수·AI 사용량은 **회원 ID 목록 기반 group-by 집계 쿼리 2번**으로 조회해 N+1을 피한다.

### 상세 (`/admin/members/{id}`)

- 프로필 카드: 캐릭터·상태·가입일·마지막 로그인·마지막 활동·로그인 횟수.
- 통계 카드: 루틴 상태별 개수, AI 호출수, 총 토큰, 추정 비용(USD).
- 루틴 목록(기존 유지) + **AI 호출 이력 최근 20건** 테이블.
- 조치 버튼: 계정 정지/해제, 강제 로그아웃(confirm 다이얼로그 + flash 결과).

### 대시보드

- 기존 카드에 추가: 오늘 AI 호출수·추정 비용, 최근 7일 활성 회원수, 정지 회원수.

---

## 테스트 계획 (단위 테스트만)

- `SystemConfigServiceTest`: 타입 검증(정수/소수/SELECT), 잘못된 값 거부, 캐시 TTL·즉시 갱신, 기본값 복원.
- `AiCallLogServiceTest`: 토큰→비용 계산(텍스트/이미지/로컬), usage 없는 응답 방어, 저장 실패 무해화.
- `MemberAccessGuardTest`: SUSPENDED 거부, tokenInvalidBefore 이전 토큰 거부, 활동 갱신 스로틀.
- `AdminMemberServiceTest`: 검색/필터/페이지, 정지·해제·강제 로그아웃 상태 변화.
- 기존 클라이언트 테스트(GeminiTextClientTest 등)는 config 서비스 목 주입으로 갱신.

## 이슈 분리

1. `⚙️[기능추가][서버][관리자] SystemConfig 기반 동적 설정 관리 (AI 모델·파라미터 실시간 교체)`
2. `⚙️[기능추가][서버][관리자] AI 호출 로그·토큰 사용량·비용 모니터링`
3. `⚙️[기능추가][서버][회원] 회원 활동 추적·계정 정지·강제 로그아웃`
4. `🚀[기능개선][서버][관리자] 회원 관리 화면 고도화 (검색·페이지네이션·사용량 통계·운영 조치)`

구현 순서는 1 → 2 → 3 → 4 (2는 1의 요금 설정, 4는 2·3의 데이터에 의존).
배포는 4건 구현·검증 완료 후 한 번에 진행한다.
