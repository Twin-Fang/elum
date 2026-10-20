# 알림 클라 푸시 수신 (#828) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 보호자 기기가 FCM 토큰을 서버에 등록하고, 푸시를 받아 배너를 띄우고, 누르면 알림 화면과 같은 규칙으로 이동한다.

**Architecture:** `firebase_messaging`을 `PushMessagingClient` 인터페이스 뒤에 둔다(테스트는 가짜). `PushTokenRegistrar`가 등록·해제 시점을 한 곳에서 정하고, `PushMessageRouter`가 전경 배너·탭 이동을 맡아 #826의 `notificationNavigatorProvider.open`을 부른다. flutter_local_notifications 플러그인 인스턴스는 리마인더와 한 개로 합친다.

**Tech Stack:** `firebase_core`, `firebase_messaging`, flutter_local_notifications 22, Riverpod.

**Spec:** `docs/superpowers/specs/2026-10-19-notifications-design.md` · 선행: #827 서버 Task 5, #826 클라 Task 1·3

## Global Constraints
- 경로 머리 `client/`(이하 `C/`). 레이어 규칙·ARB·용어 규칙은 #826 계획과 같다.
- Firebase 프로젝트 `elum-dd083`. 설정 파일 원본은 `~/.elum-secrets/firebase-elum-dd083/` — **`.gitignore`에 먼저 넣고** 복사한다. 값은 이슈·대화·커밋에 붙이지 않는다.
- 이룸이 기기(`storage.isElumiDevice`)는 토큰을 등록하지 않는다.
- 보호자 기기가 이룸이 화면일 때(`storage.resumeOnElumiScreen == true`) 토큰은 유지, 전경 배너는 띄우지 않는다.
- 권한은 앱 첫 실행에 묻지 않는다. 첫 일과 보내기 직후 안내 시트를 거친다.
- Android 채널 `guardian_updates`(이름 ARB `pushChannelGuardianUpdates` 보호자 알림), 리마인더 채널 `routine_reminder`와 분리.
- 앱 배포(스토어 심사)는 사용자가 "배포해줘"라고 할 때만.

## Review Focus
1. 로그아웃 직후 같은 기기로 다른 보호자가 로그인 → 앞 사람 알림이 오면 안 된다. 해제가 실패해도 새 로그인의 등록이 토큰 주인을 옮긴다(서버 Task 5). (Task 2 테스트)
2. 앱이 완전히 꺼진 상태에서 푸시를 눌러 켬 → 로그인·라우터 준비 뒤 한 번만 이동. (Task 4 테스트)
3. 권한 안내 시트에서 `나중에` 후 다시 일과를 보냄 → 시트를 다시 띄우지 않는다. (Task 3 테스트)
4. 토큰 발급 실패(시뮬레이터·APNs 미준비) → 앱은 그대로, 로그만. (Task 2 테스트)
5. 이룸이 화면으로 전환된 동안 푸시 도착 → 배너 없음, 보호자 화면으로 돌아오면 빨간 점 갱신. (Task 4 테스트)

---

### Task 1: Firebase 붙이기 (패키지 · 네이티브 · CI)

**Files:**
- Modify: `.gitignore` (`client/android/app/google-services.json`, `client/ios/Runner/GoogleService-Info.plist` — 서버 계획 Task 9에서 이미 했으면 확인만)
- Modify: `C/pubspec.yaml` (`firebase_core`, `firebase_messaging` — 설치 시점 최신 안정판)
- Modify: `C/android/settings.gradle.kts` (`id("com.google.gms.google-services") version "4.4.2" apply false`), `C/android/app/build.gradle.kts` plugins에 `id("com.google.gms.google-services")`
- Modify: `C/ios/Runner/Runner.entitlements` (`aps-environment` = `development`; 릴리스 빌드는 Xcode가 production으로 서명), `C/ios/Runner/Info.plist` (`UIBackgroundModes` = `remote-notification`), `Runner.xcodeproj`에 GoogleService-Info.plist를 Runner 타깃 리소스로 등록
- Modify: `scripts/copy-worktree-local-files.sh` `LOCAL_FILES` 두 줄
- Modify: `.github/workflows/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`, `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` (secret `GOOGLE_SERVICE_INFO_PLIST` → `ios/Runner/GoogleService-Info.plist` 생성 단계), Android 워크플로우는 `GOOGLE_SERVICES_JSON` 생성 단계가 있는지 확인하고 없는 것에 추가
- Modify: `C/lib/main.dart` (`AppConfig.load` 뒤 `Firebase.initializeApp()`; 실패해도 앱은 계속 — try/catch 후 `AppDiagnostics` 기록, 푸시만 꺼짐)

- [ ] **Step 1:** `.gitignore` 고치고 `git check-ignore -v` 두 경로 확인 → 원본 복사
- [ ] **Step 2:** `/pro-github`로 Secret `GOOGLE_SERVICES_JSON`(이미 있으면 값 교체 여부 사용자 확인), `GOOGLE_SERVICE_INFO_PLIST` 등록
- [ ] **Step 3:** `flutter build apk --debug`, `flutter build ios --simulator --debug` 성공, 시뮬레이터 실행 시 시작 직후 꺼지지 않음 확인(`/pro-launch app launch`)
- [ ] **Step 4:** `/pro-commit`

### Task 2: 토큰 등록 · 해제

**Files:**
- Create: `C/lib/features/notification/data/{push_messaging_client,push_device_repository}.dart`
- Create: `C/lib/features/notification/application/push_token_registrar.dart`
- Modify: `C/lib/features/auth/data/auth_repository.dart:411` `logout()` (`/api/auth/logout` **전에** 해제), `:444` `deleteAccount()` (전에 해제), `C/lib/features/link/data/device_link_repository.dart:241` 이룸이 기기로 바뀌기 전 해제 — 직접 import 대신 `application`의 콜백/provider를 통해 (레이어 규칙)
- Modify: `C/lib/app.dart` (로그인 상태가 보호자로 확정되면 `registrar.syncRegistration()`)
- Test: `C/test/push_token_registrar_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class PushMessagingClient { Future<String?> getToken(); Stream<String> get onTokenRefresh; Future<void> deleteToken(); Future<bool> hasPermission(); Future<bool> requestPermission(); Stream<PushMessage> get onForegroundMessage; Stream<PushMessage> get onMessageOpenedApp; Future<PushMessage?> getInitialMessage(); }` + `FirebasePushMessagingClient`
  - `class PushMessage { NotificationType? type; String? notificationId; String? profileId; String? targetId; String? title; String? body; }` (`data` 키: `type`, `notificationId`, `profileId`, `targetId` — 서버 Task 4와 같은 이름)
  - `PushDeviceRepository(Dio)`: `register(String token, PushPlatform platform)` → `PUT /api/push-devices`, `unregister(String token)` → `DELETE /api/push-devices/{token}`; `skipProfileHeader`
  - `PushTokenRegistrar`: `Future<void> syncRegistration()` (보호자·이룸이 기기 아님·권한 있음일 때만 토큰 등록, `onTokenRefresh` 구독), `Future<void> unregisterBeforeSignOut()` (서버 해제 → `deleteToken()`, 실패해도 다음 단계 진행)
  - `final pushTokenRegistrarProvider`

- [ ] **Step 1: 실패하는 테스트** `sync_elumiDevice_registersNothing`, `sync_noPermission_registersNothing`, `sync_guardian_registersToken`, `tokenRefresh_registersNewToken`, `getTokenThrows_noCrash_logsOnly`, `unregister_serverFails_stillDeletesLocalToken`
- [ ] **Step 2:** `flutter test test/push_token_registrar_test.dart` → FAIL
- [ ] **Step 3:** 구현 + logout·deleteAccount·이룸이 기기 전환에 연결
- [ ] **Step 4:** PASS + 기존 `auth_repository` 테스트 PASS
- [ ] **Step 5:** `/pro-commit`

### Task 3: 권한 안내 시트

**Files:**
- Create: `C/lib/features/notification/presentation/push_permission_sheet.dart`, `C/lib/features/notification/application/push_permission_prompt.dart`
- Modify: `C/lib/core/storage/local_storage.dart` (`hasAskedPushPermission` bool, 키는 `StorageKeys`)
- Modify: `C/lib/features/guardian/presentation/card_review_screen.dart:183` `_saveNow()` 성공 뒤 (`context.go(Routes.guardian)` 다음 홈에서 1회), `C/lib/features/guardian/presentation/routine_manage_screen.dart:80` `_send()` 성공 뒤
- Test: `C/test/push_permission_prompt_test.dart`

**Interfaces:**
- Produces: `Future<void> PushPermissionPrompt.maybeAsk(BuildContext context)` — `hasAskedPushPermission`이면 끝; 이미 권한 있으면 플래그만 세우고 `syncRegistration()`; 아니면 시트 → `알림 받기`: `requestPermission()` → 허용이면 `syncRegistration()`, 거부면 `showFailure(fallbackCode: 'E-PUSH-PERM')` 안내(설정에서 켤 수 있다고) / `나중에`: 플래그만. 어느 쪽이든 플래그 true.
- 문구: `pushPermissionSheetTitle` 이룸이가 일과를 끝내면 알려 드릴까요?, `pushPermissionSheetBody` 다른 보호자의 소식과 크레딧 안내도 함께 알려 드려요, `pushPermissionAllow` 알림 받기, `pushPermissionLater` 나중에, `pushPermissionDenied` 알림 설정에서 언제든 켤 수 있어요 (en 같은 뜻)

- [ ] **Step 1: 실패하는 테스트** `alreadyAsked_showsNothing`, `later_setsFlag_noOsPrompt`, `allow_granted_registers`, `allow_denied_showsCode_setsFlag`, `alreadyGranted_noSheet_registers`
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS + 시트 골든 1장
- [ ] **Step 5:** `/pro-commit`

### Task 4: 받기 · 전경 배너 · 눌러서 이동

**Files:**
- Create: `C/lib/core/notifications/local_notifications_plugin.dart` (플러그인 1개 + 초기화 1회 + 탭 콜백 스트림)
- Modify: `C/lib/features/reminder/data/reminder_scheduler.dart:33-55` (자체 인스턴스 대신 위 provider 사용, 동작 동일)
- Create: `C/lib/features/notification/application/push_message_router.dart`
- Modify: `C/lib/main.dart` (최상위 `@pragma('vm:entry-point') Future<void> firebaseBackgroundHandler(RemoteMessage m) async {}` 등록), `C/lib/app.dart` (라우터 준비 후 `router.start()`)
- Test: `C/test/push_message_router_test.dart`, `C/test/reminder_scheduler_test.dart`(있으면 PASS 유지)

**Interfaces:**
- Consumes: `notificationNavigatorProvider.open` (#826 Task 3), `unreadSummaryProvider.refresh()` (#826 Task 2), `PushMessagingClient` (Task 2)
- Produces: `PushMessageRouter.start()`:
  - 전경 수신: `unreadSummaryProvider.refresh()`; `resumeOnElumiScreen`이 아니면 로컬 알림(`guardian_updates`, payload = data JSON)으로 배너. iOS는 `setForegroundNotificationPresentationOptions(alert: true, sound: true)` 대신 로컬 알림 하나로 통일해 중복 배너를 막는다(`alert: false`).
  - `getInitialMessage()` / `onMessageOpenedApp` / 로컬 알림 탭 → 로그인이 보호자로 확정된 뒤 `open(type, profileId, notificationId)` 1회, 그 알림을 `markRead`.
  - 로그인 안 됨 → 이동하지 않고 버림(로그인 후 홈).

- [ ] **Step 1: 실패하는 테스트** `foreground_onGuardianScreen_showsLocalBanner_andRefreshes`, `foreground_onElumiScreen_noBanner_refreshesOnly`, `initialMessage_waitsForAuth_thenOpensOnce`, `tap_unknownType_opensNotificationsScreen`, `notSignedIn_dropsTap`
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS
- [ ] **Step 5:** `/pro-commit`

### Task 5: 실기기 확인

- [ ] **Step 1:** `flutter analyze --no-fatal-infos` 0건, `flutter test` 전체 PASS
- [ ] **Step 2:** iOS 시뮬레이터(Apple silicon, 원격 푸시 지원)와 Android 에뮬레이터에서 `/pro-launch`로: 보호자 로그인 → 일과 보내기 → 안내 시트 → 허용 → 서버 DB `push_device`에 토큰 1행
- [ ] **Step 3:** 다른 기기(이룸이)에서 일과 완료 → 보호자 기기에 배너, 같은 날 두 번째 완료 → 배너가 한 줄로 바뀜, 앱 꺼진 상태에서 눌러 홈 이동. 캡처를 열어 확인
- [ ] **Step 4:** iOS 실기기 1대에서 같은 흐름(사용자 기기 필요 — 안 되면 "실기기 확인 전"으로 보고)
- [ ] **Step 5:** `/pro-commit` → 이슈에 `@projectops app build <브랜치명>` 댓글(브랜치 원격 선반영)
