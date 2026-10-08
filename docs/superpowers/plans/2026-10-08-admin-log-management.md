# 관리자 서버 로그 관리 개편 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 관리자 페이지 하나로 운영 로그를 보고·찾고·받고·지우고·레벨을 바꾸고·배포 상태를 안다.

**Architecture:** logback이 인스턴스 색(`ELUM_INSTANCE`)별 폴더에 일반·오류 파일을 쓰고, 메모리 appender가 최근 ERROR를 모은다. 생명주기 리스너가 `deploy-history.log`에 한 줄씩 남긴다. 관리자 JSON API(`/admin/logs/api/**`)가 경로 검증을 거쳐 목록·tail·검색·다운로드·삭제·배포 이력·레벨·오류를 제공하고 `logs.html`이 탭 UI로 묶는다.

**Tech Stack:** Spring Boot 4.1 · logback · Thymeleaf + daisyUI(동봉 admin.css, `server/tool/build-admin-css.sh`로 재생성) · JUnit 5 + AssertJ

**Spec:** `docs/superpowers/specs/2026-10-08-admin-log-management-design.md`

## Global Constraints

- 로그 루트: `${ELUM_LOG_DIR:logs}` — logback과 서비스가 같은 값을 쓴다.
- 인스턴스: `${ELUM_INSTANCE}` 값이 `blue`/`green`이 아니면 `local`.
- 파일: `{instance}/elum.log`(10MB·7일·1GB), `{instance}/elum-error.log`(WARN+, 10MB·30일·200MB), `deploy-history.log`(최근 1000줄).
- 관리자 로그 컨트롤러에는 `@LogMonitoring`을 붙이지 않는다. JSON 컨트롤러는 `@JsonErrorResponse`.
- 새 ErrorCode는 `messages_ko.properties`·`messages_en.properties` 양쪽에 문구가 있어야 한다(패리티 테스트).
- 주석은 로직의 WHY만, 이슈 번호·경위 금지.

## 스펙 대비 조정

- 삭제 금지 범위를 넓힌다: **모든 색의 `elum.log`·`elum-error.log`**(배포 중 반대 색 JVM이 아직 쓰고 있을 수 있어 지우면 그 JVM의 이후 로그가 사라진다)와 `deploy-history.log`. 롤링된 `.gz`와 이전 형식 파일만 지운다.
- 다운로드는 JSON 에러를 내기 위해 API 컨트롤러(`/admin/logs/api/download`)에 둔다.
- 경로 검증 클래스는 관리자만 쓰므로 `admin/application/service/LogFileLocator`에 둔다.
- `hibernate.type.descriptor: TRACE`는 Hibernate 6에서 쓰이지 않는 로거라 운영 로그 1000줄 중 0줄이었다. 운영 yml은 Secret이라 건드리지 않고, 레벨 탭에서 실제 바인딩 로거(`org.hibernate.orm.jdbc.bind`)를 다룰 수 있게 한다.

## Review Focus

1. 경로 탐색(`../`, 절대경로, 인코딩된 슬래시, 심볼릭 링크) — 로그 폴더 밖 파일을 절대 내주지 않는다.
2. 배포 중 두 JVM이 각자 쓰는 파일을 삭제하려는 시도 — 409로 막는다.
3. 깨진 `.gz`·빈 파일·한 줄짜리 거대 항목 검색 — 500이 아니라 읽기 실패 코드 또는 잘린 항목.
4. `deploy-history.log`에 깨진 줄·알 수 없는 이벤트 — 무시하고 나머지를 판정한다.
5. 존재하지 않는 로거·잘못된 레벨 — 400, "원래대로"는 처음 바꾸기 전 설정값으로 복구.

---

### Task 1: logback 구조 · 인스턴스 · 최근 오류 저장소

**Files:**
- Modify: `server/src/main/resources/logback-spring.xml`
- Create: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/logging/{LogInstance,RecentErrorStore,RecentErrorAppender}.java`
- Modify: `server/build.gradle` (`springBoot { buildInfo() }`), `server/.gitignore` (`logs/`)
- Test: `server/src/test/java/com/chuseok22/elumserver/common/infrastructure/logging/{LogInstanceTest,RecentErrorStoreTest}.java`

**Interfaces (Produces):**
- `LogInstance.normalize(String raw) -> String` (`blue|green|local`), `LogInstance.opposite(String) -> Optional<String>`
- `RecentErrorStore.global()`, `record(Instant, String logger, String message, String exceptionClass)`, `snapshot(Instant now) -> Snapshot(int last24h, Instant since, List<RecentError> recent)`
- `RecentErrorAppender extends AppenderBase<ILoggingEvent>` — ERROR만 `RecentErrorStore.global()`에 기록

- [ ] 테스트: normalize(null/"BLUE"/"weird"), 50건 상한·최신 우선, 24시간 경계 제외
- [ ] 구현 → 테스트 통과

### Task 2: 로그 파일 위치 · 목록 · tail · 삭제 · 다운로드

**Files:**
- Create: `admin/application/service/LogFileLocator.java`, `admin/application/dto/response/LogFileListResponse.java`
- Modify: `admin/application/service/AdminLogService.java`, `admin/application/controller/AdminLogApiController.java`, `common/infrastructure/exception/ErrorCode.java`, `i18n/messages_{ko,en}.properties`
- Test: `LogFileLocatorTest`, `AdminLogServiceTest`(기존 수정)

**Interfaces (Produces):**
- `LogFileLocator(Path root, String instance)`: `resolve(String rel) -> Path`(INVALID_LOG_PATH/LOG_FILE_NOT_FOUND), `isDeletable(String rel)`, `currentLogPath() -> "{me}/elum.log"`, `list() -> LogFileListResponse`
- `AdminLogService.tail(String path, Long offset, Integer lines)`, `delete(String path)`, `download(String path) -> Path`
- ErrorCode: `INVALID_LOG_PATH(400)`, `LOG_FILE_NOT_FOUND(404)`, `LOG_FILE_IN_USE(409)`, `LOG_FILE_DELETE_FAILED(500)`, `INVALID_LOG_LEVEL(400)`

- [ ] 테스트: `../x`, `/etc/passwd`, `blue/../../x`, 패턴 밖 이름, 심볼릭 링크 → INVALID_LOG_PATH / 정상 경로 허용 / 활성 파일 삭제 → LOG_FILE_IN_USE / `.gz` 삭제 성공 / 목록 그룹·합계 / 기존 tail 동작 유지
- [ ] 구현 → 테스트 통과

### Task 3: 검색

**Files:** Create `admin/application/service/AdminLogSearchService.java`, `dto/response/LogSearchResponse.java`; Test `AdminLogSearchServiceTest`

**Interfaces:** `search(String path, String level, String q, String from, Integer limit) -> LogSearchResponse(path, scanned, matched, entries[{timestamp, level, text}])` 최신 순

- [ ] 테스트: 평문·gz, 스택트레이스 묶음, 최소 레벨(WARN → WARN+ERROR), 키워드 대소문자 무시, from 이후만, limit 최신 순, 긴 항목 잘림, 깨진 gz → LOG_FILE_READ_FAILED
- [ ] 구현 → 테스트 통과

### Task 4: 배포 이력

**Files:** Create `common/infrastructure/logging/DeployHistoryRecorder.java`, `admin/application/service/DeployHistoryService.java`, `dto/response/DeployHistoryResponse.java`; Test `DeployHistoryRecorderTest`, `DeployHistoryServiceTest`

**Interfaces:** `DeployHistoryRecorder.append(String event)` 줄 형식 `ts instance version port EVENT`, 1000줄 트림 / `DeployHistoryService.list(Instant now) -> List<Deployment(instance, version, port, startedAt, readyAt, stoppedAt, status, current)>` status ∈ RUNNING·STOPPED·FAILED·STARTING

- [ ] 테스트: 성공→종료, READY 없이 STOPPED → FAILED, READY 없이 같은 색 재기동 → FAILED, 3분 지난 미준비 → FAILED, 최근 미준비 → STARTING, 깨진 줄 무시, 트림
- [ ] 구현 → 테스트 통과

### Task 5: 로거 레벨 · 최근 오류 · 인스턴스 API

**Files:** Create `admin/application/service/AdminLogLevelService.java`, `dto/response/{LoggerLevelResponse,RecentErrorsResponse,LogInstanceResponse}.java`; Modify `AdminLogApiController`; Test `AdminLogLevelServiceTest`

- [ ] 테스트: 잘못된 레벨·이름 → INVALID_LOG_LEVEL, 변경 후 조회 반영, reset → 처음 설정값 복구
- [ ] 구현 → 테스트 통과

### Task 6: 화면 · 배지 · 대시보드 · CSS

**Files:** Modify `templates/admin/logs.html`, `templates/admin/fragments/admin-layout.html`, `templates/admin/dashboard.html`, `AdminViewController`, `static/admin/vendor/admin.css`(재생성); Test `AdminTemplateTagBalanceTest`(기존)

- [ ] 탭 5개 + 상단 카드 + 실패 토스트(에러 코드) + 빈 상태
- [ ] 사이드바 ERROR 배지, 대시보드 최근 오류 카드
- [ ] `bash server/tool/build-admin-css.sh`

### Task 7: 배포 워크플로

**Files:** Modify `.github/workflows/PROJECT-SPRING-CICD.yaml` — `docker run`에 `-e ELUM_INSTANCE="${CONTAINER_NAME##*-}" -e ELUM_PORT="${PORT}"`

### Task 8: 검증 · 커밋 · 배포 · 실측

- [ ] `./gradlew test` 전체 1회
- [ ] `/pro-commit` → push → main 최신화 → `/pro-changelog-deploy`
- [ ] 운영 실측: 인스턴스 카드, deploy-history, 다운로드, 삭제 409, 레벨 변경, 배지
- [ ] `/pro-report` → 라벨 작업완료 → 이슈 닫기
