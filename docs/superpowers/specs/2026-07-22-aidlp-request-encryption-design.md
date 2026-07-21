# AI DLP 요청 구간 암호화 (AES-256-GCM + HMAC)

> 작성일 2026-07-22 · 대상 모듈: `client/` + `server/`

## 1. 배경 · 목적

현재 보호자가 입력한 일과 원문(`rawInputText`, `text`)이 **평문 JSON**으로 클라이언트 →
백엔드에 전송된다. AI DLP 게이트웨이가 마스킹을 담당하지만, **마스킹은 서버 도착 이후**에
일어나므로 네트워크 구간에서는 원문이 그대로 노출된다(TLS 아래 계층 한정).

이 설계는 **AI DLP 진입점의 요청 본문을 클라이언트에서 암호화**해 전송하고, 서버가
비즈니스 로직 이전 단계에서 복호화하도록 한다. "보안을 맨 처음부터 철저히"라는 요구에 따라
전송 구간 기밀성·무결성·재전송 방지를 함께 확보한다.

### 위협 모델 · 한계 (명시)

- **막는 것**: 네트워크 구간 평문 노출, 본문 위변조, 요청 재전송(replay).
- **막지 못하는 것**: 클라이언트 앱에 마스터 시크릿을 심으므로, **앱 디컴파일 시 시크릿 추출
  가능**. 즉 이는 "완벽한 기밀"이 아니라 **네트워크 구간 방어 + DLP 게이트웨이 보안 시연**이
  목적이다. 이 한계를 발표·문서에 그대로 밝힌다.

## 2. 적용 범위

암호화를 적용하는 엔드포인트는 **AI DLP 진입점 3개**로 한정한다.

| 메서드 | 경로 | 암호화 대상 필드 |
| --- | --- | --- |
| POST | `/api/routines` | `rawInputText` |
| POST | `/api/routines/questions` | `rawInputText` |
| POST | `/api/internal/sensitive-check` | `text` |

그 외 엔드포인트(단계 수정 등)는 이번 범위에서 제외한다.

## 3. 암호화 방식 (확정)

| 항목 | 선택 |
| --- | --- |
| 대칭 암호 | **AES-256-GCM** (AEAD — 암호화 + 무결성 태그 동시) |
| 키 파생 | **HKDF-SHA256** — 마스터 시크릿 1개에서 요청마다 salt로 AES 키·HMAC 키 파생 |
| 재전송 방지 | **HMAC-SHA256 서명 헤더** — timestamp + nonce + ciphertext 서명, 서버가 시각·nonce 검증 |
| 마스터 시크릿 | `application-dev.yml` 1개 + 클라 `.env` 1개 (동일 값 공유) |

### 왜 GCM인데 HMAC을 또 쓰나

GCM 태그는 **본문 무결성**을 보장한다. HMAC 헤더는 그 위에 **요청 메타데이터(timestamp,
nonce)까지 묶어 서명**해 **재전송 공격**을 막는 역할이다. 역할이 겹치지 않는다.

## 4. 전송 포맷

### 4.1 요청 본문 — 봉투(envelope) DTO

기존 평문 필드 대신 암호문 봉투 하나로 감싼다. **서버 비즈니스 로직은 그대로 두고**,
복호화 계층(필터)이 봉투를 열어 기존 평문 DTO로 되돌린다.

```jsonc
// POST /api/routines  요청 본문
{
  "encrypted": {
    "ciphertext": "<base64>",   // AES-256-GCM(평문 원본 JSON) — 태그 포함
    "iv":         "<base64>",   // 12바이트 GCM IV (암호화용, X-Elum-Nonce와 별개)
    "salt":       "<base64>"    // 16바이트, HKDF 키 파생용
  }
}
```

- **평문 원본**은 기존 요청 JSON 전체다. 예:
  `{"rawInputText":"...","scheduledAt":"...","answers":[...]}`
- 서버는 복호화 후 이 JSON을 기존 `RoutineCreateRequest`로 역직렬화한다.

### 4.2 인증 헤더

| 헤더 | 값 | 용도 |
| --- | --- | --- |
| `X-Elum-Timestamp` | epoch millis | 재전송 방지(허용 오차 ±5분) |
| `X-Elum-Nonce` | base64 랜덤 16바이트 | 재전송 방지(윈도우 내 1회용) |
| `X-Elum-Signature` | base64 HMAC-SHA256 | 위변조·재전송 검증 |

**서명 대상 문자열**(양쪽 동일 규약):
```
signingString = timestamp + "." + nonce + "." + base64(ciphertext)
X-Elum-Signature = HMAC-SHA256(hmacKey, signingString)
```

## 5. 키 파생 (HKDF)

마스터 시크릿 1개에서 요청마다 **두 개의 키**를 파생한다.

```
masterSecret  = (yml / .env 공유 값, 32바이트 이상 권장)
prk           = HKDF-Extract(salt, masterSecret)
aesKey (32B)  = HKDF-Expand(prk, info="elum-aes-gcm",  L=32)
hmacKey (32B) = HKDF-Expand(prk, info="elum-hmac-sha256", L=32)
```

- `salt`는 **요청마다 새로 생성**해 봉투에 실어 보낸다 → 같은 원문도 매번 다른 키·암호문.
- `info` 라벨을 다르게 줘 **한 salt에서 AES·HMAC 키를 분리**한다(키 재사용 방지).

## 6. 아키텍처 · 데이터 흐름

```
[클라] 평문 JSON
   │  1) salt·iv·nonce 생성
   │  2) HKDF → aesKey, hmacKey
   │  3) AES-GCM 암호화 → ciphertext
   │  4) HMAC 서명 → X-Elum-Signature
   ▼
{encrypted:{ciphertext,iv,salt}} + 헤더 3개
   ▼  (HTTPS)
[서버 복호화 필터]  ← JWT 인증 이후, 컨트롤러 이전
   │  1) timestamp 오차·nonce 중복 검사 → 실패 시 400(E-DLP-xxx)
   │  2) HKDF → aesKey, hmacKey (동일 salt)
   │  3) HMAC 재계산·상수시간 비교 → 불일치 시 400
   │  4) AES-GCM 복호화(태그 검증 포함) → 평문 JSON
   │  5) 요청 본문을 평문 JSON으로 치환
   ▼
[기존 컨트롤러] RoutineCreateRequest 등 평문 DTO 그대로 수신 (변경 없음)
```

### 6.1 클라이언트 구성 (`client/`)

| 구성 | 위치(신규/수정) | 역할 |
| --- | --- | --- |
| `AidlpCrypto` | `lib/core/security/aidlp_crypto.dart` (신규) | HKDF·AES-GCM·HMAC 유틸. 순수 함수로 테스트 가능 |
| `EncryptionInterceptor` | `lib/core/network/encryption_interceptor.dart` (신규) | 대상 3경로 요청 본문을 봉투로 치환 + 헤더 부착 |
| `dio_client.dart` | 수정 | 위 인터셉터를 Auth 인터셉터 뒤에 등록 |
| `AppConfig` | `lib/core/config/app_config.dart` 수정 | `aidlpSecret` getter(기본값 포함) |
| `.env.example` | 수정 | `ELUM_AIDLP_SECRET=` 키 문서화 |

- **암호 라이브러리**: `cryptography` 패키지(순수 Dart, build hook 없음 → 트러블슈팅의
  build_runner 문제 회피). AES-GCM·HKDF·HMAC 모두 지원. 계획 단계에서 pub 추가 검증.
- 인터셉터는 **대상 경로에만** 적용한다. 그 외 요청은 그대로 통과.

### 6.2 서버 구성 (`server/`)

| 구성 | 위치(신규/수정) | 역할 |
| --- | --- | --- |
| `AidlpCryptoService` | `common/infrastructure/security/AidlpCryptoService.java` (신규) | HKDF·AES-GCM·HMAC 검증/복호화 |
| `AidlpDecryptionFilter` | `common/infrastructure/security/AidlpDecryptionFilter.java` (신규) | 대상 경로 요청 본문 복호화 + 재전송 검증 |
| `SecurityConfig` | 수정 | 필터를 `JwtAuthenticationFilter` 뒤에 등록 |
| `NonceStore` | `common/infrastructure/security/NonceStore.java` (신규) | 윈도우 내 nonce 중복 차단(인메모리 TTL 맵) |
| `AidlpProperties` | `common/infrastructure/properties/` (신규) | `elum.aidlp.secret` 바인딩 |
| `ErrorCode` | 수정 | DLP 복호화 관련 에러코드 추가 |
| `application-dev.yml` | **사용자가 직접 추가** | `elum.aidlp.secret: <값>` (아래 §9) |

- 요청 본문을 필터에서 읽어 치환하려면 **`ContentCachingRequestWrapper` 또는 커스텀
  `HttpServletRequestWrapper`** 로 body를 교체한다(스트림은 1회성이므로).
- 필터는 대상 경로가 아니면 즉시 통과(`shouldNotFilter`).

## 7. 실패 경로 (필수)

CLAUDE.md 원칙: 어떤 오류에도 화면이 깨지지 않고, **에러 코드**를 노출한다.
데모는 어떤 실패에도 fallback으로 끝까지 진행한다.

| 실패 | 서버 응답 | 클라이언트 동작 |
| --- | --- | --- |
| timestamp 만료(±5분 밖) | 400 `E-DLP-401` | 로깅 후 **기존 로컬 fallback**으로 진행(카드 로컬 생성) |
| nonce 재사용 | 400 `E-DLP-402` | 동일 fallback |
| HMAC 불일치 | 400 `E-DLP-403` | 동일 fallback |
| 복호화/태그 검증 실패 | 400 `E-DLP-404` | 동일 fallback |
| 봉투 형식 오류·필드 누락 | 400 `E-DLP-405` | 동일 fallback |
| 클라 암호화 자체 실패 | — (전송 전) | 암호화 예외를 잡아 **로컬 fallback**으로 진행, 데모 중단 없음 |

- `RoutineRepository`는 이미 실패 시 `_localRoutine` fallback을 갖고 있다. 암호화 실패도
  이 경로로 흘려 **데모가 멈추지 않게** 한다.
- `POST /questions`는 원래 **실패해도 200**이므로 기존 동작 유지.
- 서버 에러 응답은 기존 `CustomException` + `ErrorCode` + `GlobalExceptionHandler` 규약을
  따르고, **원문·복호문을 로그에 남기지 않는다**(원칙 5번, `@LogMonitoring(false,false)` 유지).

## 8. 테스트

### 클라이언트 (`flutter test`)
- `AidlpCrypto` 왕복 단위 테스트: 암호화→복호화 원문 일치, salt마다 암호문 상이.
- HMAC 서명이 서명 대상 규약대로 생성되는지.
- 인터셉터가 **대상 경로만** 봉투로 바꾸고 그 외는 통과하는지.
- 암호화 실패 시 fallback으로 카드가 나오는지(데모 성립 조건).

### 서버 (`./gradlew test`, 단위테스트만)
- `AidlpCryptoService` 왕복: 클라와 동일 벡터로 복호화 성공.
- HMAC 불일치·timestamp 만료·nonce 재사용 → 각 에러코드.
- **크로스 검증**: 클라에서 만든 봉투(고정 테스트 벡터)를 서버가 복호화(양쪽 규약 일치 확인).
  통합테스트·curl 금지 규칙에 따라 **고정 벡터 기반 단위테스트**로 대체한다.

## 9. 시크릿 설정 (사용자 작업)

서버 규칙상 나는 `application-*.yml`을 열람·수정하지 않는다. **사용자가 직접** 아래를 넣는다.

**서버** — `server/src/main/resources/application-dev.yml`:
```yaml
elum:
  aidlp:
    secret: <32바이트 이상 랜덤 문자열>   # 클라 .env와 동일 값
```

**클라이언트** — `client/.env` (커밋 안 함) + GitHub Secret `CLIENT_ENV_FILE`:
```
ELUM_AIDLP_SECRET=<서버와 동일 값>
```

- `.env.example`에는 빈 값으로 키만 문서화한다.
- **동일 값**이어야 양쪽 HKDF 파생 결과가 일치한다. 값이 다르면 전부 복호화 실패 →
  fallback으로 빠져 조용히 로컬 카드만 나오므로, 계획 단계에서 값 일치를 먼저 확인한다.
- 배포 앱은 `.env`가 아니라 `CLIENT_ENV_FILE` Secret에서 온다 → **배포 전 Secret 갱신**.

## 10. 구현 순서(요약)

1. 양쪽 crypto 유틸을 **동일 규약**으로 먼저 만들고 고정 벡터로 왕복 테스트.
2. 서버 복호화 필터 + 재전송 검증 + 에러코드.
3. 클라 인터셉터 + `.env`/`AppConfig` + fallback 연결.
4. 크로스 검증 테스트 → 실기기(dev) 확인.
5. 시크릿은 사용자가 넣고, 값 일치 확인 후 배포.

## 11. 열린 질문

- 마스터 시크릿 값 자체(사용자가 생성·주입).
- `cryptography` 패키지 최종 채택 여부(계획 단계 pub 검증에서 확정).
- nonce 저장소를 인메모리로 둘지(단일 인스턴스 데모에 충분) — 다중 인스턴스면 재검토.
