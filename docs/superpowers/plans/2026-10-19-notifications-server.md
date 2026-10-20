# 알림 서버 (#827) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 보호자에게 갈 알림 5종을 서버에 기록하고(목록·읽음·설정·공지 탭 API), FCM으로 푸시를 보낸다. Firebase 키가 없으면 푸시만 건너뛴다.

**Architecture:** 새 도메인 `notification`. 일이 일어나는 서비스(일과·초대·의견)는 `ApplicationEventPublisher`로 이벤트만 낸다. `NotificationEventListener`가 커밋 뒤 비동기로 받아 `NotificationRecorder`로 행을 쓰거나 고치고(묶음 키 유일), 새로 쓰였거나 개수가 늘었을 때만 `PushDispatcher`가 설정을 보고 `PushSender`(FCM 또는 빈 발송기)로 보낸다. 다른 도메인 저장소는 직접 쓰지 않고 서비스를 거친다(`ArchitectureRulesTest`).

**Tech Stack:** Spring Boot 4.1, Java 21, JPA + Flyway(Postgres), `com.google.firebase:firebase-admin`, JUnit5 + Mockito, `@WebMvcTest`.

**Spec:** `docs/superpowers/specs/2026-10-19-notifications-design.md`

## Global Constraints
- 경로 머리: `server/src/main/java/com/chuseok22/elumserver/`(이하 `M/`), 테스트 `server/src/test/java/com/chuseok22/elumserver/`(이하 `T/`).
- 받는 사람은 보호자만. 이룸이 기기 토큰(`caller.isElumi()`)은 기기 등록·알림 API 모두 403 (`SecurityConfig` 기본 `anyRequest().hasAuthority(GUARDIAN)`이 그대로 막는다 — 규칙을 더하지 않는다).
- **요청한 사람 빼기는 보호자 기기 요청일 때만**: `actorMemberId = caller.isElumi() ? null : caller.memberId()`. 이룸이 기기의 `memberId`는 연결해 준 보호자라 빼면 안 된다.
- 푸시(FCM) 제목·본문에 일과 제목·이룸이 이름 등 입력 원문을 넣지 않는다. 알림 행에도 원문을 복사하지 않고 id만 저장한다.
- 알림 행은 설정과 무관하게 항상 쓴다. 설정은 푸시 여부만 정한다.
- 알림·푸시 실패가 본래 요청을 실패시키지 않는다 (AFTER_COMMIT + 비동기 + 예외 로그 후 삼키지 않고 기록).
- 로그 영어, 접두사 `[notification record]`, `[notification push]`. 토큰·원문 금지.
- 새 ErrorCode는 `messages_ko.properties` 문구 + 클라 `server_error_code.dart` 같은 이름 (서버 CLAUDE.md).
- 모든 엔드포인트 `@LogMonitoring` + `*ControllerDocs`. request DTO에 `jakarta.validation` 금지.
- `notification` 패키지를 `GlobalExceptionHandler` `basePackages`에 추가.
- 마이그레이션 V47 (develop 에 V43~V46 이 먼저 있어 번호를 밀었다), 추가만, `IF NOT EXISTS`, NOT NULL엔 DEFAULT.
- 시간대 `Asia/Seoul` (`NoticeService.ZONE` 재사용 금지 — `notification`에 `NotificationClock` 없이 `Clock` 주입, 기본 `Clock.system(ZoneId.of("Asia/Seoul"))`).

## Review Focus
1. 이룸이가 같은 일과 두 개를 거의 동시에 끝냄 → 묶음 행 유일 제약 충돌. 기대: 한 줄, 개수 2. (Task 2에 동시성 재시도 테스트)
2. 이룸이 기기에서 끝낸 일과 → 그 기기를 연결해 준 보호자도 받아야 한다. (Task 3 테스트)
3. 이미 완료된 일과에 `completeStep`·`syncProgress`가 다시 들어옴(재전송·중복 동기화) → 이벤트 없음. (Task 3 테스트)
4. 보호자가 이룸이에서 나간 뒤 남은 알림/새 알림 → 나간 보호자에게는 새 알림이 안 가고, 목록 응답에서 접근 못 하는 이룸이의 이름은 비운다. (Task 6 테스트)
5. FCM이 토큰 문제(`UNREGISTERED`)를 돌려줌 → 그 토큰 행 삭제, 다른 기기는 계속 발송. (Task 4 테스트)

---

### Task 1: 저장 구조 (마이그레이션 · 엔티티 · 저장소 · 탈퇴 정리)

**Files:**
- Create: `server/src/main/resources/db/migration/V47__create_notification_tables.sql`
- Create: `M/notification/core/NotificationType.java`
- Create: `M/notification/infrastructure/entity/{Notification,PushDevice,NotificationSetting,NoticeSeen}.java`
- Create: `M/notification/infrastructure/repository/{Notification,PushDevice,NotificationSetting,NoticeSeen}Repository.java`
- Create: `M/notification/application/service/NotificationCleanupService.java`
- Modify: `M/notice/infrastructure/entity/AppNotice.java` (`revisedAt` 추가), revision을 올리는 `NoticeService` 지점에서 `revisedAt = now()`
- Modify: `M/member/application/service/WithdrawnMemberService.java:118` `purge`, `M/member/application/service/MemberService.java:181` `withdraw`, `M/member/application/service/GuardianshipService.java:207` `removeProfile`
- Modify: `M/common/application/exception/GlobalExceptionHandler.java:25`
- Test: `T/common/WithdrawCoversMemberReferencesTest` (기존, 통과해야 함), `T/notification/application/service/NotificationCleanupServiceTest.java`

**Interfaces:**
- Produces:
  - `enum NotificationType { ROUTINE_COMPLETED, ROUTINE_SENT_BY_CO_GUARDIAN, CO_GUARDIAN_JOINED, CREDIT_REFILLED, FEEDBACK_RESOLVED }`
  - `Notification` (BaseEntity 상속, UUID id): `recipientMemberId`(member_id 컬럼명 `member_id`), `profileId`(nullable), `type`, `targetId`(nullable), `groupKey`, `subjectIds`(쉼표 구분 문자열, 일과 완료의 일과 id 목록), `count`(int), `lastOccurredAt`, `readAt`(nullable). 유일 제약 `(member_id, group_key)`.
  - `PushDevice`: `memberId`(`member_id`), `token`(유일, 4096), `platform`(`PushPlatform { IOS, ANDROID }`), `locale`(`AppLocale`), `lastRegisteredAt`.
  - `NotificationSetting`: `memberId`(PK, `member_id`), `allEnabled`, 종류별 boolean 5개(`routineCompletedEnabled`, `routineSentEnabled`, `coGuardianJoinedEnabled`, `creditRefilledEnabled`, `feedbackResolvedEnabled`), 모두 DEFAULT true.
  - `NoticeSeen`: `memberId`(PK, `member_id`), `seenAt`.
  - `NotificationRepository`: `Optional<Notification> findByRecipientMemberIdAndGroupKey(String, String)`, `List<Notification> findByRecipientMemberIdOrderByLastOccurredAtDescIdDesc(String, Pageable)` (커서는 Task 6에서 `lastOccurredAt` 기준 쿼리로 대체 가능), `long countByRecipientMemberIdAndReadAtIsNull(String)`, `int deleteAllByRecipientMemberId(String)`, `int deleteAllByProfileId(String)`, `int deleteAllByLastOccurredAtBefore(LocalDateTime)`.
  - `PushDeviceRepository`: `Optional<PushDevice> findByToken(String)`, `List<PushDevice> findAllByMemberIdIn(Collection<String>)`, `void deleteByToken(String)`, `int deleteAllByMemberId(String)`.
  - `NotificationCleanupService.deleteAllOf(String memberId)`, `deleteAllOfProfile(String profileId)`.

- [ ] **Step 1:** V46 작성: 표 4개(`notification`, `push_device`, `notification_setting`, `notice_seen`) + `app_notice.revised_at timestamp NULL` + 인덱스 `notification(member_id, last_occurred_at desc)`.
- [ ] **Step 2:** 엔티티·저장소·`NotificationType`·`PushPlatform` 작성, `GlobalExceptionHandler` basePackages에 `com.chuseok22.elumserver.notification` 추가.
- [ ] **Step 3: 실패하는 테스트** `NotificationCleanupServiceTest.deleteAllOf_removesNotificationsDevicesSettingsAndSeen` — 네 저장소의 `deleteAllByMemberId`/`deleteById`가 각각 1회 호출되는지 Mockito로 검증.
- [ ] **Step 4:** `NotificationCleanupService` 구현, `withdraw`·`purge`에서 `notificationCleanupService.deleteAllOf(memberId)`, `removeProfile`에서 `deleteAllOfProfile(profileId)` 호출. 서비스를 거치므로 `WithdrawCoversMemberReferencesTest` 화이트리스트에 feedback 사례처럼 4개 엔티티를 등록.
- [ ] **Step 5:** `cd server && ./gradlew test --tests '*NotificationCleanupServiceTest' --tests '*WithdrawCoversMemberReferencesTest' --tests '*ArchitectureRulesTest' --tests '*MigrationRollbackContractTest' --tests '*ExceptionHandlerCoverageTest'` → PASS
- [ ] **Step 6:** `/pro-commit` (V46, notification 패키지, 탈퇴 정리 3곳, 화이트리스트)

### Task 2: NotificationRecorder (묶음 · 받는 사람)

**Files:**
- Create: `M/notification/application/service/NotificationRecorder.java`
- Create: `M/notification/core/NotificationDraft.java`
- Modify: `M/member/application/service/ProfileGuardianService.java` (`guardianMemberIdsOf` 추가)
- Test: `T/notification/application/service/NotificationRecorderTest.java`, `T/member/application/service/ProfileGuardianServiceTest.java`(있으면 추가, 없으면 생성)

**Interfaces:**
- Produces:
  - `List<String> ProfileGuardianService.guardianMemberIdsOf(String profileId)` — `findAllByProfileIdOrderByJoinedAtAsc` → member id 목록
  - `record NotificationDraft(NotificationType type, String profileId, String targetId, String groupKey, String subjectId, LocalDateTime occurredAt)`
  - `record RecordedNotification(String notificationId, String recipientMemberId, int count, boolean shouldPush)`
  - `List<RecordedNotification> NotificationRecorder.record(NotificationDraft draft, Collection<String> recipientMemberIds)` — 받는 사람마다 별도 트랜잭션(`REQUIRES_NEW`)
- 묶음 키 규칙 (`NotificationDraft` 정적 팩토리로 고정):
  - `routineCompleted(profileId, routineId, LocalDate routineDate, now)` → `ROUTINE_COMPLETED:{profileId}:{yyyy-MM-dd}`, subjectId=routineId
  - `routineSent(profileId, routineId, now)` → `ROUTINE_SENT:{routineId}`
  - `coGuardianJoined(profileId, joinedMemberId, now)` → `CO_GUARDIAN_JOINED:{profileId}:{joinedMemberId}`
  - `creditRefilled(periodKey, now)` → `CREDIT_REFILLED:{periodKey}` (profileId null)
  - `feedbackResolved(feedbackId, now)` → `FEEDBACK_RESOLVED:{feedbackId}`

- [ ] **Step 1: 실패하는 테스트** (`NotificationRecorderTest`)
  - `firstCompletion_createsRowWithCount1_andShouldPush`
  - `secondDifferentRoutineSameDay_updatesSameRow_count2_unreadAgain_shouldPush` (`readAt` → null, `lastOccurredAt` 갱신)
  - `sameRoutineCompletedAgain_keepsCount_shouldNotPush`
  - `feedbackResolvedTwice_secondIsNoOp_shouldNotPush`
  - `uniqueViolationOnInsert_retriesAsUpdate` (첫 save가 `DataIntegrityViolationException` → 재조회 후 갱신, 결과 count 2)
- [ ] **Step 2:** `./gradlew test --tests '*NotificationRecorderTest'` → FAIL (클래스 없음)
- [ ] **Step 3:** 구현. 묶음 없는 종류는 기존 행이 있으면 아무것도 안 함(`shouldPush=false`). `subjectIds`는 쉼표 구분, 이미 있으면 그대로.
- [ ] **Step 4:** `ProfileGuardianServiceTest.guardianMemberIdsOf_returnsJoinedOrder` 추가 → 구현 → 두 테스트 PASS
- [ ] **Step 5:** `/pro-commit`

### Task 3: 이벤트 기반과 네 도메인의 이벤트 발행

**Files:**
- Create: `M/common/infrastructure/config/AsyncConfig.java` (`@EnableAsync`, 빈 이름 `notificationExecutor`, core 2 / max 4 / queue 500)
- Create: `M/notification/core/event/{RoutineCompletedEvent,RoutineSentEvent,CoGuardianJoinedEvent,FeedbackResolvedEvent}.java` (record)
- Create: `M/notification/application/listener/NotificationEventListener.java`
- Modify: `M/routine/application/service/RoutineProgressService.java:34` `completeStep`, `:114` `syncProgress`
- Modify: `M/routine/application/service/RoutineService.java:44` `confirm`, `:73` `duplicate`
- Modify: `M/routine/application/service/RoutineLibraryService.java:45` `send`
- Modify: `M/member/application/service/ProfileInviteService.java:140` `redeem`
- Modify: `M/feedback/application/service/FeedbackService.java:97` `changeStatus`
- Test: `T/routine/application/service/RoutineProgressServiceTest`, `RoutineServiceTest`, `RoutineLibraryServiceTest`, `T/member/.../ProfileInviteServiceTest`, `T/feedback/.../FeedbackServiceTest` (기존 파일에 추가), `T/notification/application/listener/NotificationEventListenerTest.java`

**Interfaces:**
- Produces (이벤트 record, 패키지 `notification.core.event` — common이 아닌 notification에 두고 다른 도메인이 import. 규칙 위반이면 `common/event`로 옮긴다):
  - `RoutineCompletedEvent(String routineId, String profileId, LocalDate routineDate, String actorMemberId)` — `routineDate = routine.getScheduledAt().toLocalDate()`
  - `RoutineSentEvent(String routineId, String profileId, String actorMemberId)`
  - `CoGuardianJoinedEvent(String profileId, String joinedMemberId)`
  - `FeedbackResolvedEvent(String feedbackId, String memberId)`
- Consumes: `NotificationRecorder.record`, `ProfileGuardianService.guardianMemberIdsOf`, Task 4의 `PushDispatcher.dispatch(List<RecordedNotification>, NotificationType)`
- 리스너: `@Async("notificationExecutor") @TransactionalEventListener(phase = AFTER_COMMIT)` 메서드 4개. 받는 사람 = `guardianMemberIdsOf(profileId)` − actor(합류는 − joinedMemberId, 의견은 memberId 한 명). 예외는 `[notification record] failed type=... : {class}` 로그.

- [ ] **Step 1: 실패하는 테스트** (각 기존 서비스 테스트에 `@Mock ApplicationEventPublisher`)
  - `completeStep_lastStep_publishesRoutineCompleted_withActorNullForElumi` (`Caller.elumi(...)`)
  - `completeStep_lastStep_byGuardian_publishesActorMemberId`
  - `completeStep_alreadyCompleted_publishesNothing`
  - `syncProgress_newlyCompleted_publishes` / `syncProgress_wasCompleted_publishesNothing` / `syncProgress_partial_publishesNothing`
  - `confirm_publishesRoutineSent`, `duplicate_publishesRoutineSent`, `librarySend_publishesRoutineSent`, `libraryCopy_publishesNothing`
  - `redeem_success_publishesCoGuardianJoined`, `redeem_failure_publishesNothing`
  - `changeStatus_toDone_publishesFeedbackResolved`, `changeStatus_toInProgress_publishesNothing`, `changeStatus_sameStatus_publishesNothing`
  - `NotificationEventListenerTest`: `routineCompleted_excludesActor_includesLinkingGuardianWhenActorNull`, `recorderThrows_doesNotPropagate`
- [ ] **Step 2:** `./gradlew test --tests '*RoutineProgressServiceTest' --tests '*RoutineServiceTest' --tests '*RoutineLibraryServiceTest' --tests '*ProfileInviteServiceTest' --tests '*FeedbackServiceTest' --tests '*NotificationEventListenerTest'` → 새 테스트 FAIL
- [ ] **Step 3:** 각 서비스 생성자에 `ApplicationEventPublisher` 주입, 상태가 새로 COMPLETED가 된 경우(이전 상태 != COMPLETED)에만 발행. `AsyncConfig`, 리스너 구현.
- [ ] **Step 4:** 위 명령 → PASS, 이어서 `./gradlew test` 전체 → PASS (생성자 변경으로 깨진 기존 테스트 정리 포함)
- [ ] **Step 5:** `/pro-commit`

### Task 4: 푸시 발송 (FCM · 빈 발송기 · 문구 · 설정)

**Files:**
- Modify: `server/build.gradle` (`// Firebase Admin (FCM)` + `implementation 'com.google.firebase:firebase-admin:9.4.3'`)
- Create: `M/common/infrastructure/properties/FirebaseProperties.java` (`@ConfigurationProperties(prefix = "firebase") record FirebaseProperties(String serviceAccountKeyPath)`)
- Create: `M/notification/infrastructure/push/{PushSender,FcmPushSender,NoOpPushSender,PushSenderConfig}.java`
- Create: `M/notification/application/service/{PushDispatcher,PushMessageFactory}.java`
- Modify: `server/src/main/resources/i18n/messages_{ko,en,ja,zh,es}.properties` (없는 언어 파일은 만들지 않고 해당 언어는 en으로 대체) — 키 `push.*`
- Test: `T/notification/application/service/{PushDispatcherTest,PushMessageFactoryTest}.java`, `T/notification/infrastructure/push/PushSenderConfigTest.java`

**Interfaces:**
- Produces:
  - `record PushMessage(String token, String title, String body, Map<String,String> data, String collapseKey)`
  - `enum PushResult { SENT, INVALID_TOKEN, FAILED }`
  - `interface PushSender { PushResult send(PushMessage message); }`
  - `PushSenderConfig`: 키 파일이 있으면 `FcmPushSender`(FirebaseApp 초기화, Android `tag`·iOS `apns-collapse-id` = collapseKey), 경로가 비었거나 파일이 없으면 `NoOpPushSender`(로그 `[notification push] disabled : no service account key`)
  - `PushMessage PushMessageFactory.create(RecordedNotification n, NotificationType type, PushDevice device)` — data 키: `type`, `notificationId`, `profileId`, `targetId`
  - `void PushDispatcher.dispatch(List<RecordedNotification> recorded, NotificationType type)` — `shouldPush`인 것만, 설정(`allEnabled && 종류별`) 확인, 받는 사람의 기기 전부 발송, `INVALID_TOKEN`이면 `deleteByToken`
- 문구 (title은 모두 `이룸`/`ELUM`):

| 키 | ko | en |
|---|---|---|
| `push.routine_completed.one` | 이룸이가 오늘 일과를 끝냈어요 | Your ELUM user finished a routine today |
| `push.routine_completed.many` | 이룸이가 오늘 일과 {0}개를 끝냈어요 | Your ELUM user finished {0} routines today |
| `push.routine_sent` | 함께하는 보호자가 새 일과를 보냈어요 | A co-guardian sent a new routine |
| `push.co_guardian_joined` | 새 보호자가 함께하기 시작했어요 | A new guardian joined |
| `push.credit_refilled` | 이번 주 크레딧이 채워졌어요 | This week's credits are refilled |
| `push.feedback_resolved` | 보내 주신 의견을 확인하고 처리했어요 | We reviewed your feedback |

  ja·zh·es는 같은 뜻으로 번역해 넣는다(파일이 있는 언어만).

- [ ] **Step 1: 실패하는 테스트**
  - `PushMessageFactoryTest.body_neverContainsRoutineTitleOrProfileName` (가짜 일과 제목 "세수하기", 이름 "하늘이"가 body·title·data 어디에도 없음)
  - `PushMessageFactoryTest.routineCompletedCount2_usesManyCopy_withCollapseKeyEqualsGroupKey`
  - `PushMessageFactoryTest.unknownLocale_fallsBackToEn`
  - `PushDispatcherTest.allDisabled_sendsNothing`, `typeDisabled_sendsNothing`, `noSettingRow_sendsToAllDevices`, `invalidToken_deletesDevice_andContinuesOthers`, `senderThrows_doesNotPropagate`
  - `PushSenderConfigTest.missingKeyFile_yieldsNoOpSender`
- [ ] **Step 2:** `./gradlew test --tests '*PushMessageFactoryTest' --tests '*PushDispatcherTest' --tests '*PushSenderConfigTest'` → FAIL
- [ ] **Step 3:** 구현. FCM 오류 코드 `UNREGISTERED`, `INVALID_ARGUMENT`(토큰) → `INVALID_TOKEN`, 그 밖 → `FAILED`(로그 `[notification push] failed : {errorCode}`).
- [ ] **Step 4:** 위 명령 PASS + `./gradlew test` 전체 PASS
- [ ] **Step 5:** `/pro-commit`

### Task 5: 기기 등록 · 알림 설정 API

**Files:**
- Create: `M/notification/application/controller/{PushDeviceController,PushDeviceControllerDocs,NotificationSettingController,NotificationSettingControllerDocs}.java`
- Create: `M/notification/application/service/{PushDeviceService,NotificationSettingService}.java`
- Create: `M/notification/application/dto/request/{PushDeviceRegisterRequest,NotificationSettingRequest}.java`, `.../response/NotificationSettingResponse.java`
- Modify: `M/common/infrastructure/exception/ErrorCode.java` (`PUSH_TOKEN_INVALID(HttpStatus.BAD_REQUEST)`), `messages_ko.properties`, `client/lib/core/network/server_error_code.dart`(이름만)
- Test: `T/notification/application/controller/NotificationSecurityTest.java`, `T/notification/application/service/{PushDeviceServiceTest,NotificationSettingServiceTest}.java`

**Interfaces:**
- `PUT /api/push-devices` body `{ token: String, platform: "IOS"|"ANDROID" }` → 204. locale은 `CurrentLocale.get()`. 같은 토큰이 다른 회원 것이면 memberId를 옮긴다. 토큰 비었거나 4096자 초과 → `PUSH_TOKEN_INVALID`.
- `DELETE /api/push-devices/{token}` → 204 (내 토큰이 아니면 아무것도 안 함, 204).
- `GET /api/notification-settings` → `NotificationSettingResponse(boolean allEnabled, boolean routineCompleted, boolean routineSent, boolean coGuardianJoined, boolean creditRefilled, boolean feedbackResolved)`; 행 없으면 모두 true.
- `PUT /api/notification-settings` body 같은 모양 → 200 같은 응답.

- [ ] **Step 1: 실패하는 테스트**
  - `NotificationSecurityTest.elumiToken_registerDevice_403`, `elumiToken_getNotifications_403`, `guardianToken_registerDevice_204`, `noToken_401` (패턴: `T/feedback/application/controller/FeedbackSecurityTest`)
  - `PushDeviceServiceTest.sameTokenOtherMember_reassignsOwner`, `blankToken_throwsPushTokenInvalid`
  - `NotificationSettingServiceTest.noRow_returnsAllTrue`, `update_persistsAllSixFlags`
- [ ] **Step 2:** `./gradlew test --tests '*NotificationSecurityTest' --tests '*PushDeviceServiceTest' --tests '*NotificationSettingServiceTest'` → FAIL
- [ ] **Step 3:** 구현 (`Caller.from(authentication)`, 헤더 불필요)
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** `/pro-commit`

### Task 6: 알림 목록 · 안 읽음 요약 · 읽음 API

**Files:**
- Create: `M/notification/application/controller/{NotificationController,NotificationControllerDocs}.java`
- Create: `M/notification/application/service/NotificationQueryService.java`, `NotificationReadService.java`
- Create: `M/notification/application/dto/response/{NotificationItemResponse,NotificationPageResponse,UnreadSummaryResponse}.java`
- Modify: `M/routine/application/service/` 에 제목 일괄 조회 메서드 (예: `RoutineQueryService.titlesOf(Collection<String> routineIds): Map<String,String>`), `ProfileGuardianService`/`ProfileService`에 `Map<String,String> profileNamesOf(String memberId, Collection<String> profileIds)` (접근 가능한 이룸이만)
- Modify: `ErrorCode` (`NOTIFICATION_NOT_FOUND(HttpStatus.NOT_FOUND)`) + 문구 + 클라 이름
- Test: `T/notification/application/service/{NotificationQueryServiceTest,NotificationReadServiceTest}.java`, `NotificationSecurityTest`에 추가

**Interfaces:**
- `GET /api/notifications?cursor={notificationId}&size=20` (size 최대 50) → `NotificationPageResponse(List<NotificationItemResponse> items, String nextCursor)`; 정렬 `lastOccurredAt desc, id desc`.
- `NotificationItemResponse(String id, NotificationType type, String profileId, String profileName, String targetId, String routineTitle, int count, LocalDateTime occurredAt, boolean isRead)` — `profileName`·`routineTitle`은 지금 값, 지워졌거나 접근 못 하면 null. 일과 완료는 `routineTitle` = 가장 최근 subject 일과 제목.
- `GET /api/notifications/unread-summary` → `UnreadSummaryResponse(boolean hasUnreadNotification, long unreadNotificationCount, boolean hasUnreadNotice)` (공지 계산은 Task 7의 `NoticeHistoryService.hasUnseenNotice(memberId, platform)`; 쿼리 `platform` 받음)
- `POST /api/notifications/{id}/read` → 204 (남의 알림이면 `NOTIFICATION_NOT_FOUND`), `POST /api/notifications/read-all` → 204.

- [ ] **Step 1: 실패하는 테스트**
  - `NotificationQueryServiceTest.page_ordersByLastOccurredDesc_andReturnsNextCursor`
  - `deletedRoutine_titleNull`, `profileNoLongerAccessible_profileNameNull`
  - `NotificationReadServiceTest.readOthersNotification_throwsNotFound`, `readAll_marksOnlyMine`
- [ ] **Step 2:** FAIL 확인 → **Step 3:** 구현 → **Step 4:** PASS (`./gradlew test --tests '*Notification*'`)
- [ ] **Step 5:** `/pro-commit`

### Task 7: 공지 탭 목록 · 공지 읽음

**Files:**
- Create: `M/notification/application/service/NoticeHistoryService.java` (또는 `notice` 도메인 안 `NoticeHistoryService` — `AppNoticeRepository`를 쓰므로 **`notice` 도메인에 둔다**: `M/notice/application/service/NoticeHistoryService.java`)
- Modify: `M/notice/application/controller/` 에 `NoticeHistoryController` + Docs (`/api/notices/history`, `/api/notices/seen` — 보호자 인증, 기존 공개 `/api/app/notices`와 경로가 달라 기본 규칙으로 보호자 전용)
- Create: `M/notice/application/dto/response/NoticeHistoryPageResponse.java`
- Test: `T/notice/application/service/NoticeHistoryServiceTest.java`

**Interfaces:**
- `LocalDateTime AppNotice.visibleSince()` = `max(startsAt, revisedAt)` (revisedAt null이면 startsAt)
- `GET /api/notices/history?platform=IOS|ANDROID&cursor=&size=20` → 항목: `id, title, body, imageUrl, buttonLabel, buttonUrl, visibleSince` ; 조건: `enabled`, `startsAt <= now`, `visibleSince >= now - 90일`, `locale == CurrentLocale.get()`, `platform.reaches(requested)`; 정렬 visibleSince desc. 게시가 끝난 것도 포함.
- `POST /api/notices/seen` → `NoticeSeen.seenAt = now` (upsert), 204
- `boolean NoticeHistoryService.hasUnseenNotice(String memberId, String platform)` — 위 조건에서 `visibleSince > seenAt`(행 없으면 하나라도 있으면 true)

- [ ] **Step 1: 실패하는 테스트** `includesEndedNotice_within90Days`, `excludesOtherLocale`, `excludesDisabled`, `republishedAfterSeen_isUnseen`, `noSeenRow_anyNotice_isUnseen`
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS
- [ ] **Step 5:** `/pro-commit`

### Task 8: 스케줄러 (크레딧 알림 · 90일 정리)

**Files:**
- Create: `M/notification/infrastructure/scheduler/{CreditRefillNotificationScheduler,NotificationRetentionScheduler}.java`
- Modify: `M/credit/application/service/` 에 `List<String> CreditQueryService.memberIdsDepletedIn(CreditPeriod period)` (원장 `balanceAfter <= 0` 이 그 주기 안에 있는 계정의 memberId, 탈퇴로 memberId null인 계정 제외)
- Test: `T/credit/.../CreditQueryServiceTest`(추가), `T/notification/infrastructure/scheduler/CreditRefillNotificationSchedulerTest.java`

**Interfaces:**
- `@Scheduled(cron = "${elum.notification.credit-refill-cron:0 0 9 * * MON}", zone = "Asia/Seoul")` → 지난 주기 = `CreditPeriod.of(now.minusWeeks(1))`, 대상마다 `NotificationDraft.creditRefilled(CreditPeriod.of(now).key(), now)` 기록 + 발송.
- `@Scheduled(cron = "${elum.notification.retention-cron:0 0 5 * * *}", zone = "Asia/Seoul")` → `deleteAllByLastOccurredAtBefore(now - 90일)`.

- [ ] **Step 1: 실패하는 테스트** `memberIdsDepletedIn_onlyBalanceZeroInPeriod`, `scheduler_recordsOncePerMember_usingCurrentPeriodKey`, `scheduler_runTwice_noDuplicatePush`(묶음 키로 2회째 shouldPush=false)
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS
- [ ] **Step 5:** `/pro-commit`

### Task 9: 배포 준비와 실측 확인

**Files:**
- Modify: `.gitignore` (`server/src/main/resources/firebase-adminsdk.json`, `client/android/app/google-services.json`, `client/ios/Runner/GoogleService-Info.plist`)
- Modify: `.github/workflows/PROJECT-SPRING-CICD.yaml:54-59` 주석 해제 (`FIREBASE_ADMINSDK_JSON` → `src/main/resources/firebase-adminsdk.json`)
- Modify: `scripts/copy-worktree-local-files.sh` `LOCAL_FILES`에 서버 키 한 줄
- 로컬: `~/.elum-secrets/firebase-elum-dd083/firebase-adminsdk.json` → `server/src/main/resources/firebase-adminsdk.json`

- [ ] **Step 1:** `.gitignore` 먼저 고치고 `git check-ignore -v server/src/main/resources/firebase-adminsdk.json` → 규칙이 잡힘 확인 후 파일 복사
- [ ] **Step 2:** `/pro-github`로 Actions Secret `FIREBASE_ADMINSDK_JSON` 등록 (값은 파일에서 읽어 넣고 출력하지 않음), `application-prod.yml`의 `firebase.service-account-key-path`가 클래스패스 기준인지 `FirebaseProperties` 해석과 맞는지 확인(`classpath:` 접두 또는 파일 경로 — Task 4 구현과 같은 방식으로 맞춘다)
- [ ] **Step 3:** `cd server && ./gradlew test` 전체 PASS, `./gradlew bootRun`(dev, 키 없음) 기동 로그에 `[notification push] disabled` 확인
- [ ] **Step 4:** `/pro-commit` → (사용자 요청 시) 푸시 → 배포 후 `/pro-ssh`로 기동 로그에 FCM 초기화 성공, `curl`로 `GET /api/notifications` 200 확인
