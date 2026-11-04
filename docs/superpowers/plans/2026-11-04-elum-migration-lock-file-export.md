# 파일 내보내기 API · 이전 잠금 (#1053) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 친구 서버에서 그림·음성 파일을 관리자 API 로 받을 수 있게 하고, 전환 순간 친구 서버의 모든 쓰기·발송을 멈추는 이전 잠금을 만든다. 둘 다 기본 꺼짐.

**Architecture:** 새 패키지 `migration` 에 잠금 판정(`MigrationLock`)과 파일 내보내기를 둔다. 기존 지점(점검 필터, 푸시 발송기, 신고 메일 리스너, 예약 작업 4개, 광고 보상 콜백, `/s/` 공유 미리보기)은 `MigrationLock` 하나만 묻는다.

**Tech Stack:** Spring Boot, Spring Security 필터, `RestClient`, JUnit5 + Mockito + `@TempDir`

**Spec:** `docs/superpowers/specs/2026-11-04-elum-server-cutover-design.md` [B] 절

## Global Constraints

- 새 설정 3개 모두 그룹 `APP_CONTROL`, 기본값: `MIGRATION_LOCK=false`, `MIGRATION_FILE_EXPORT_ENABLED=false`, `APP_API_BASE_URL=""`. 시드 마이그레이션 불필요 (`SystemConfigInitializer` 가 기본값을 넣음).
- 잠금이 꺼져 있으면 기존 동작과 바이트 단위로 같다 (점검 필터 응답 포함).
- 새 오류 코드 5개는 관리자 전용이라 기존 관리자 코드처럼 ko·en 메시지에 `E-MIG-00N` 식별자와 함께 넣고(나머지 언어는 기본 체인), 앱 `client/lib/core/network/server_error_code.dart` 에도 같은 이름을 넣는다 (`CrossStackContractTest` 가 강제).
- 로그 문구: 영어, 접두사 `[migration lock]` / `[migration export]`.
- 파일 내보내기 area 4개와 기준 폴더: `routine-images` = `RoutineProperties.imageStoragePath`, `talk-images` = `TalkProperties.imageStoragePath`, `notice-images` = `NoticeProperties.imageStoragePath`, `routine-speech` = `TtsProperties.speechStoragePath`.
- 운영에서 잠금·내보내기를 켜는 시험은 하지 않는다.

## Review Focus

1. 잠금 중 토큰 갱신: 점검과 달리 503 이어야 한다 (열리면 전환 뒤 로그아웃) → Task 2 `locked_blocksRefresh`.
2. 잠금 중 광고 보상 콜백 쿼리: 서명 검증이 쿼리 문자열 그대로라 한 글자라도 다시 인코딩되면 새 서버가 거부한다 → Task 4 `relay_forwardsRawQueryExactly`.
3. 내보내기 경로: `../`, 절대 경로, 심볼릭 링크 파일·폴더 → Task 1 `download_rejects*`.
4. 서로 잠긴 두 서버가 콜백을 계속 넘김 → Task 4 `relay_alreadyRelayed_returns503`.
5. 앞으로 새로 생기는 `@Scheduled` 가 잠금을 빠뜨림 → Task 3 규칙 테스트.

---

### Task 1: 설정 키 + 잠금 판정 + 파일 내보내기 API

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/systemconfig/core/ConfigKey.java` (APP_CONTROL 묶음, `MAINTENANCE_MESSAGE` 뒤)
- Modify: `.../admin/application/service/SystemConfigOverviewService.java` (`MIGRATION_LOCK` 상단 강조)
- Modify: `.../common/infrastructure/exception/ErrorCode.java`, `server/src/main/resources/i18n/messages_{ko,en,es,ja,zh}.properties`
- Modify: `.../admin/core/AdminAuditAction.java`, `.../admin/core/AdminAuditTargetType.java`
- Create: `.../migration/core/MigrationFileArea.java`, `.../migration/application/service/MigrationFileExportService.java`, `.../migration/application/dto/response/MigrationFileListResponse.java`, `.../migration/application/controller/AdminMigrationFileApiController.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/migration/application/service/MigrationFileExportServiceTest.java`, `.../MigrationLockTest.java`

**Interfaces:**
- Produces:
  - `ConfigKey.MIGRATION_LOCK`, `ConfigKey.MIGRATION_FILE_EXPORT_ENABLED`, `ConfigKey.APP_API_BASE_URL`
  - `MigrationLock` (@Component, `systemconfig/application/service` — 모든 기능이 이미 의존하는 곳, common→기능 역방향 의존을 피함): `boolean isLocked()` (설정 읽기 실패 시 false, 경고 로그), `boolean isBlockingScheduledJob(String jobName)` (잠겼으면 `[migration lock] scheduled job skipped : {jobName}` 로그 후 true), `Optional<String> newServerBaseUrl()` (공백 제거, 끝 `/` 제거, 비면 empty)
  - `MigrationFileArea` enum: `ROUTINE_IMAGES("routine-images")`, `TALK_IMAGES("talk-images")`, `NOTICE_IMAGES("notice-images")`, `ROUTINE_SPEECH("routine-speech")`, `static MigrationFileArea fromCode(String)` (모르면 `CustomException(INVALID_MIGRATION_FILE_AREA)`)
  - `MigrationFileExportService`: `MigrationFileListResponse listFiles(MigrationFileArea area)`, `Path resolveForDownload(MigrationFileArea area, String relativePath)`
  - `MigrationFileListResponse(String area, int fileCount, long totalBytes, List<MigrationFileEntry> files)`, 중첩 `MigrationFileEntry(String path, long size, String sha256, String modifiedAt)` (경로는 `/` 구분 상대 경로, 시각 ISO-8601)
  - API: `GET /admin/migration/api/files?area=` (감사 `MIGRATION_FILES_LISTED`, 대상 id = area 코드, detail = `files={n} bytes={b}`), `GET /admin/migration/api/files/download?area=&path=` (첨부, `Content-Length`, 감사 없음)
  - ErrorCode: `MIGRATION_FILE_EXPORT_DISABLED(404)`, `INVALID_MIGRATION_FILE_AREA(400)`, `INVALID_MIGRATION_FILE_PATH(400)`, `MIGRATION_FILE_NOT_FOUND(404)`
  - `AdminAuditTargetType.MIGRATION_FILE("이전 파일")`, `AdminAuditAction.MIGRATION_FILES_LISTED("이전 파일 목록 조회", MIGRATION_FILE, false)`

- [ ] **Step 1: 테스트 작성** (`@TempDir` 로 area 기준 폴더를 만들고 `SystemConfigService` 는 mock)

```java
listFiles_returnsRelativePathSizeAndSha256()      // a/1.png("abc") > path "a/1.png", size 3, sha256 "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
listFiles_skipsSymbolicLinks()                    // 링크 파일 제외, fileCount 1
listFiles_disabled_throwsExportDisabled()         // 설정 false > MIGRATION_FILE_EXPORT_DISABLED
download_rejectsParentTraversal()                 // "../secret" > INVALID_MIGRATION_FILE_PATH
download_rejectsAbsolutePath()                    // "/etc/passwd" > INVALID_MIGRATION_FILE_PATH
download_rejectsSymbolicLink()                    // 링크 파일 > INVALID_MIGRATION_FILE_PATH
download_missing_throwsNotFound()                 // MIGRATION_FILE_NOT_FOUND
download_valid_returnsFile()
fromCode_unknown_throwsInvalidArea()
// MigrationLockTest
newServerBaseUrl_trimsTrailingSlash()             // " https://api.elum.suhsaechan.kr/ " > "https://api.elum.suhsaechan.kr"
newServerBaseUrl_blank_isEmpty()
isLocked_configFails_isFalse()
isBlockingScheduledJob_locked_isTrue()
```

- [ ] **Step 2: 실패 확인** — 컴파일 실패(클래스 없음)
- [ ] **Step 3: 구현** — 경로 검사는 `LogFileLocator.resolve` 와 같은 순서(정규화 > 기준 폴더 안 > 기준 폴더 자체 아님 > 파일과 상위 폴더 심볼릭 링크 아님 > `isRegularFile(NOFOLLOW_LINKS)`). 목록은 `Files.walk` 를 `NOFOLLOW` 로, 심볼릭 링크 건너뜀, 정렬된 경로 순.
- [ ] **Step 4: 통과 확인** — Task 5 에서 묶어 실행
- [ ] **Step 5: 커밋**

### Task 2: 점검 필터에 잠금 규칙

**Files:**
- Modify: `.../systemconfig/infrastructure/security/MaintenanceModeFilter.java`, `.../common/infrastructure/config/SecurityConfig.java:138` (생성자에 `MigrationLock`)
- Test: `server/src/test/java/com/chuseok22/elumserver/systemconfig/infrastructure/security/MaintenanceModeFilterTest.java` (추가)

**Interfaces:**
- Consumes: `MigrationLock.isLocked()`
- 잠금 중 여는 곳 3개: `API_APP_STATUS`, `API_CONSENT_DOCUMENTS`, `API_ADS_SSV`. 그 밖은 점검과 같은 503 `MAINTENANCE_MODE` (같은 메시지). 잠금이 꺼져 있으면 기존 규칙 그대로.

- [ ] **Step 1: 테스트 추가**

```java
locked_blocksRefresh()                 // POST /api/auth/refresh > 503
locked_passesAppStatus()
locked_passesAdSsv()
locked_blocksWriteEvenWhenMaintenanceOff()
unlocked_maintenanceOn_refreshStillOpen() // 기존 동작 유지
```

- [ ] **Step 3: 구현** — `shouldNotFilter` 의 열린 경로 판정을 `doFilterInternal` 안으로 옮겨 잠금 > 점검 순으로 본다.
- [ ] **Step 5: 커밋**

### Task 3: 발송·예약 작업 멈춤 + 규칙 테스트

**Files:**
- Create: `.../notification/infrastructure/push/MigrationLockAwarePushSender.java`
- Modify: `.../notification/infrastructure/push/PushSenderConfig.java` (선택한 발송기를 감쌈)
- Modify: `.../talk/application/listener/TalkReportMailListener.java` (첫 줄 잠금 확인)
- Modify: 예약 작업 4개 — `WithdrawnMemberPurgeScheduler.run`, `CreditRefillNotificationScheduler.run`, `NotificationRetentionScheduler.run`, `RoutineStepSpeechSweeper.sweep` 첫 줄 `if (migrationLock.isBlockingScheduledJob("<클래스명>")) return;`
- Test: `.../notification/infrastructure/push/MigrationLockAwarePushSenderTest.java`, `server/src/test/java/com/chuseok22/elumserver/migration/MigrationLockScheduledJobRuleTest.java`

**Interfaces:**
- Produces: `MigrationLockAwarePushSender(PushSender delegate, MigrationLock migrationLock) implements PushSender` — 잠겼으면 `PushResult.FAILED` (발송 안 함, 로그), 아니면 위임.

- [ ] **Step 1: 테스트**

```java
locked_doesNotSend_returnsFailed()
unlocked_delegates()
// 규칙: server/src/main/java 아래 "@Scheduled" 가 있는 파일은 모두 "isBlockingScheduledJob(" 를 가진다
everyScheduledJob_checksMigrationLock()
```

- [ ] **Step 5: 커밋**

### Task 4: 광고 보상 콜백 전달 + 공유 링크 이동

**Files:**
- Create: `.../migration/application/service/AdSsvRelayService.java`, `.../migration/infrastructure/client/AdSsvRelayClient.java`(인터페이스) + `RestAdSsvRelayClient.java`, `.../migration/infrastructure/web/MigrationShareRedirectFilter.java`, `.../migration/infrastructure/config/MigrationWebConfig.java`
- Modify: `.../adreward/application/controller/AdSsvCallbackController.java` (잠겼으면 전달)
- Test: `.../migration/application/service/AdSsvRelayServiceTest.java`, `.../migration/infrastructure/web/MigrationShareRedirectFilterTest.java`

**Interfaces:**
- Produces:
  - `AdSsvRelayClient`: `RelayResponse forward(URI target)` — `record RelayResponse(int status, String body)`; 요청 헤더 `X-Elum-Ssv-Relayed: 1`, 연결 5초·응답 10초
  - `AdSsvRelayService`: `ResponseEntity<String> relay(String rawQuery, boolean isAlreadyRelayed)` — 새 주소 없음·이미 전달됨 > 503, 그 밖은 `{base}/api/ads/ssv?{rawQuery}` 로 그대로 (`URI.create`, 다시 인코딩 금지) > 상태·본문 그대로. 전달 실패(연결 오류) > 503
  - `MigrationShareRedirectFilter`: `/s/*` 에만 등록. 잠겼고 새 주소가 있으면 302 `Location: {base}{requestURI}[?{query}]`, 아니면 통과

- [ ] **Step 1: 테스트**

```java
relay_noBaseUrl_returns503()
relay_alreadyRelayed_returns503()
relay_forwardsRawQueryExactly()        // "ad_network=5450213213286189855&key_id=3335741209&signature=MEUCIQ%2B%2F&user_id=a%3Ab" 그대로
relay_clientFails_returns503()
redirect_lockedWithBase_302()          // /s/abc?x=1 > https://api.elum.suhsaechan.kr/s/abc?x=1
redirect_unlocked_passes()
redirect_lockedWithoutBase_passes()
```

- [ ] **Step 5: 커밋**

### Task 5: 검증 · 마무리

- [ ] Run: `./gradlew compileJava compileTestJava` / Expected: BUILD SUCCESSFUL
- [ ] Run: `./gradlew test --tests '*Migration*' --tests '*MaintenanceModeFilter*' --tests '*LocalizedError*' --tests '*AdSsv*' --tests '*AdminAudit*' --tests '*SystemConfig*'` / Expected: 모두 통과
- [ ] `/pro-code-consult` 변경분 점검 > `/pro-commit`
