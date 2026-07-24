# 설계: 서버 로그 파일화·관리자 로그 조회 / 앱 빌드 트리거 필터 / 프롬프트 이력 / devFlag 안전장치

- 날짜: 2026-07-24
- 브랜치: develop
- 범위: `server/`(로그·프롬프트 이력·관리자 화면), `.github/workflows/`(트리거 필터·devFlag 안전장치)

4개의 독립 작업을 하나의 스펙으로 묶는다. 각 작업은 별도 이슈로 상태를 관리한다.

---

## ① 서버 로그 .log 파일 저장 + 관리자 실시간 조회

### 배경

- 현재 서버는 logback 설정 파일이 없어 **콘솔로만** 로그를 남긴다. `.log` 파일은 생성되지 않는다.
- 배포 컨테이너(`elum-back`)는 `docker run -v /volume1/project/elum/server:/app`으로 NAS 경로가
  `/app`에 마운트돼 있고, Dockerfile의 `WORKDIR /app`·JAR은 `/app.jar`(루트)라 마운트와 충돌하지 않는다.
- 따라서 **상대경로 `logs/`에 파일을 쓰면 컨테이너에선 `/app/logs` → NAS에 영구 저장**된다.
  Docker/CICD 설정 변경이 필요 없다.

### 구현

**로그 파일 생성 — `server/src/main/resources/logback-spring.xml` 신규**

- 콘솔 appender 유지(`docker logs`·기존 외부 로그 엔드포인트 호환).
- `RollingFileAppender`: `logs/elum-server.log`, 일 단위 + 10MB 롤링(`logs/elum-server.2026-07-24.0.log.gz`),
  보관 7일·총량 상한 1GB. 경로는 시스템 프로퍼티 `ELUM_LOG_DIR`로 재정의 가능(기본 `logs`).
- Spring Boot 기본 패턴을 따르는 콘솔/파일 패턴 사용. `application.yml`은 수정하지 않는다
  (`application-*.yml` 접근 금지 규칙과 무관한 별도 파일).

**관리자 조회 — `/admin/logs`**

- `AdminLogController`(@Controller): `GET /admin/logs` → `templates/admin/logs.html`.
- `AdminLogApiController`(@RestController, 기존 `AdminPromptTestController` 분리 패턴 준수):
  - `GET /admin/logs/api/tail?offset={bytes}&lines={n}` → JSON
    `{ exists, fileSize, nextOffset, content }`
  - `offset` 미지정(첫 호출): 파일 끝에서 최대 `lines`줄(기본 200, 최대 1000)을 읽어 반환.
  - `offset` 지정: 해당 바이트부터 끝까지 증분 반환(최대 256KB 상한, 초과 시 뒤쪽 우선).
  - **로테이션/축소 감지**: `offset > fileSize`면 처음처럼 마지막 N줄로 리셋.
- 서비스 `AdminLogService`: `RandomAccessFile`로 읽기 전용 접근. UTF-8 디코딩.
- 화면(`logs.html`, daisyUI): 검은 배경 `<pre>` 로그 뷰어, 2초 `setInterval` 폴링,
  자동 스크롤(사용자가 위로 스크롤하면 일시 정지), [팔로우 토글]·[지우기] 버튼,
  연결 상태 배지. 사이드바에 "로그" 메뉴 추가(`admin-layout.html`).

**실패 경로**

| 상황 | 동작 |
|---|---|
| 로그 파일 미존재(로컬 첫 실행 등) | `exists=false` 반환 → 화면은 "로그 파일이 아직 없습니다" 빈 상태 표시, 폴링은 계속 |
| 파일 읽기 IOException | `ErrorCode.LOG_FILE_READ_FAILED` (E-LOG-001 노출), 화면에 에러 배지 + 다음 폴링에서 자동 재시도 |
| 네트워크/fetch 실패 | 화면 상태 배지 "연결 끊김 — 재시도 중", 폴링 유지 |
| 로그 파일 롤링 발생 | offset 리셋 로직으로 자연 복구 |

폴링(2s) 선택 이유: 세션(formLogin) 인증과 궁합이 좋고, SSE/WS 기존 패턴·의존성이 전무하며,
프록시(리버스 프록시) 환경에서 무한 스트림 이슈가 없다. 24시간 해커톤 코드베이스에는 가장 단순한 안이 맞다.

---

## ② 앱 빌드 트리거 — `client/**` 변경 시에만

### 배경

main 푸시 시 자동 실행되는 Flutter 빌드 워크플로우 4개에 `paths` 필터가 없어
`server/**`만 변경돼도 앱 빌드·배포가 전부 돌았다. 서버 CICD는 이미 `paths: ['server/**']`로 제한돼
있는 비대칭 구조.

### 구현

아래 4개 워크플로우의 `on.push`에 `paths: ["client/**"]` 추가. `workflow_dispatch`(수동 실행)는 유지.

- `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml`
- `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`
- `PROJECT-FLUTTER-ANDROID-SELFHOSTED-CICD.yaml`
- `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`

**실패 경로**: client 변경 없이 앱 재빌드가 필요한 예외 상황은 `workflow_dispatch` 수동 실행으로 커버.

---

## ③ 프롬프트 변경 이력(history)

### 배경

`PromptTemplate`(promptKey unique, content TEXT)은 수정 시 dirty checking으로 **덮어써서 기존
내용이 소실**된다. 관리자 페이지에서 이전 버전을 볼 수도, 되돌릴 수도 없다.

### 구현

**엔티티 `PromptTemplateHistory`** (`ai/infrastructure/entity/`, BaseEntity 상속, PK UUID 문자열)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | String(UUID) | PK |
| promptKey | PromptKey(STRING) | 어떤 프롬프트의 이력인지 (unique 아님) |
| content | TEXT | **교체되기 직전의(이전) 내용** 스냅샷 |

- 저장 시점: `PromptTemplateService.update()`에서 content가 실제로 달라질 때만,
  **기존 content를 history에 insert 후** 새 값으로 갱신. 같은 값 저장은 이력을 만들지 않는다.
- 조회: `findByPromptKeyOrderByCreatedAtDesc` (+ `@Index(prompt_key, created_at)`).

**Flyway `V5__create_prompt_template_history.sql`**

- `CREATE TABLE IF NOT EXISTS prompt_template_history` (id VARCHAR(255) PK, prompt_key VARCHAR(255)
  NOT NULL, content TEXT NOT NULL, created_at/updated_at TIMESTAMP) + prompt_key·created_at 인덱스.
- `IF NOT EXISTS`인 이유: 이 스키마는 ddl-auto와 Flyway가 공존하므로 어느 쪽이 먼저 생성해도 안전해야 한다.

**관리자 화면**

- `prompts.html` 각 카드에 "이력 보기" 링크 → `GET /admin/prompts/{key}/history`
  (`AdminPromptController`에 추가, `templates/admin/prompt-history.html`).
- 이력 페이지: 현재 적용본을 상단에 표시, 아래로 시각 역순 이력 목록(daisyUI collapse로 본문 접기).
  각 이력에 "이 버전으로 복원" 버튼 → 기존 저장 엔드포인트 `POST /admin/prompts/{key}`로 해당
  content 재저장(복원 자체도 이력으로 남는 자연스러운 구조).

**실패 경로**

| 상황 | 동작 |
|---|---|
| 이력 0건 | "아직 변경 이력이 없습니다" 빈 상태 |
| 존재하지 않는 key | 기존 `PROMPT_TEMPLATE_NOT_FOUND` 흐름(에러 페이지) |
| history insert 실패 | update와 동일 트랜잭션 → 함께 롤백, 이력 없는 덮어쓰기는 발생하지 않음 |

---

## ④ 배포 빌드 devFlag 강제 비활성화 안전장치

### 배경

- "devFlag" = `client/.env`의 `ELUM_SHOW_DEV_TOOLS`(개발자 도구 오버레이)·`ELUM_SKIP_ONBOARDING`(온보딩 건너뛰기).
- 현재 main 배포 워크플로우가 `.env` 생성 후 **강제로 true를 주입**(`Force enable dev tools and skip
  onboarding (hackathon)` 스텝)해서 prod 앱에 devFlag가 켜진 채 배포되고 있다.

### 구현

main 푸시 배포 워크플로우 4개(②와 동일 목록)에서:

1. 기존 "Force enable ..." 주입 스텝을 **제거**.
2. `.env` 생성 직후 `Force disable dev flags (prod safety)` 스텝 추가:
   `sed`로 `ELUM_SHOW_DEV_TOOLS`·`ELUM_SKIP_ONBOARDING` 라인을 제거하고 `false`를 append.
   → Secret(`CLIENT_ENV_FILE`)에 true가 들어 있어도 배포 산출물은 항상 false. ("deploy에 devFlag가
   true이면 false로" 요구를 무조건 false 강제로 구현 — 조건 분기보다 단순하고 누락 여지가 없다)
3. `.env`를 생성하는 **모든 잡**(prepare-build/build 등)에 동일 적용해 잡 간 불일치 제거.
4. 수동/테스트 빌드(`PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`, `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`)는
   테스터용이므로 현행 유지.

**실패 경로**: sed가 매칭할 라인이 없어도 append는 항상 수행되므로 스텝은 실패하지 않는다.
iOS 러너는 BSD sed(`sed -i ''`), Android 러너는 GNU sed(`sed -i`) 문법을 각각 유지한다.

---

## 검증 계획

- 서버: `./gradlew test` 통과 + 신규 로직(AdminLogService tail·offset·롤링 리셋, history 적재) 단위 테스트 추가.
- 워크플로우: YAML 문법 검증(파싱) + 변경 diff 리뷰. 실제 트리거 동작은 배포 시 확인.
- 클라이언트 코드는 변경하지 않는다.

## 배포·보고

작업 프로세스 표준을 따른다: 이슈 4건 등록(작업전→작업중→작업완료) → develop 구현 →
`/pro-commit` → main 최신화 → `/pro-changelog-deploy` → `/pro-report` 이슈 보고 → 라벨 완료.
