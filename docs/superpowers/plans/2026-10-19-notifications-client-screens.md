# 알림 클라 화면 (#826) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 종 아이콘과 빨간 점, 알림·공지사항 두 탭 화면, 알림 설정 화면을 만든다. 푸시 없이도(서버 #827만으로) 전부 동작한다.

**Architecture:** `lib/features/notification/` 새 기능. `data/notification_repository.dart`가 서버 API(#827)를 부르고, `application/`의 provider가 안 읽음 요약·목록 페이지·설정 상태를 든다. 알림을 눌렀을 때의 이동 규칙은 `application/notification_navigator.dart` 한 곳에 두어 #828 푸시 탭도 같은 규칙을 쓴다. 기기 권한은 `NotificationPermissionGate` 인터페이스 뒤에 둔다.

**Tech Stack:** Flutter, Riverpod, go_router 17, dio, flutter_local_notifications(권한 확인), `app_settings`(기기 알림 설정 열기).

**Spec:** `docs/superpowers/specs/2026-10-19-notifications-design.md`  · 서버 계약: `docs/superpowers/plans/2026-10-19-notifications-server.md` Task 5~7

## Global Constraints
- 경로 머리 `client/`(이하 `C/`). 기능 폴더 규칙 `features/<f>/{application,data,domain,presentation,presentation/widgets}`, provider는 파일 안 최상위 `final`.
- 다른 기능의 `data`·`presentation` import 금지(`tool/check_layer_imports.dart`). 프로필 세션은 `features/profile/application/profile_session.dart`만 쓴다.
- 화면 문구는 ARB(`lib/l10n/app_{ko,en}.arb` 필수, 열린 언어 ko·en), 한글 리터럴 금지. 키 접두사 `notification…`, `@key` description 필수.
- 용어: `이룸이`, `기기`(휴대폰 금지), 해요체.
- 색·글자 크기 직접 지정 금지(`design_token_test`), `Colors.*` 금지, 태블릿 판정은 `context.sizeClass`만.
- 에셋은 `AppAssets` 상수로만. `notifications_empty.png`는 지운다.
- 실패는 `showFailure`/`ElumErrorView` + 에러 코드: 목록 `E-NOTIF-LIST`, 설정 저장 `E-NOTIF-SETTING`, 접근 불가 이룸이 `E-NOTIF-PROFILE`, 공지 목록 `E-NOTICE-HISTORY`.
- 서버 새 ErrorCode(`PUSH_TOKEN_INVALID`, `NOTIFICATION_NOT_FOUND`)는 `core/network/server_error_code.dart`에 같은 이름(서버 Task 5·6에서 이미 더했으면 확인만).
- 인자 없는 `pop` 금지 → `context.popOrHome`.

## Review Focus
1. 목록을 넘기다(무한 스크롤) 같은 알림이 두 번 나옴 — 커서 경계에서 중복이 생기면 id로 걸러 한 번만. (Task 3 테스트)
2. 이룸이가 여럿인 보호자가 다른 이룸이의 알림을 누름 → 이룸이를 바꾼 뒤 이동, 바꾸는 동안 두 번 눌러도 한 번만 이동. (Task 3 테스트)
3. 자정을 넘겨 앱을 켜 둔 채 목록을 다시 엶 → "오늘/어제" 묶음이 지금 날짜 기준으로 다시 계산. (Task 3 테스트 — `now`를 주입)
4. 설정 스위치를 빠르게 여러 번 누름 → 마지막 상태가 서버에 남고, 실패하면 직전 값으로 돌아감. (Task 5 테스트)
5. 서버가 모르는 알림 종류 코드를 내려줌(새 버전 서버) → 그 줄만 건너뛰고 목록은 정상. (Task 1 테스트)

---

### Task 1: 도메인 모델과 저장소

**Files:**
- Create: `C/lib/features/notification/domain/{app_notification,notification_type,unread_summary,notification_settings}.dart`
- Create: `C/lib/features/notification/data/notification_repository.dart`
- Modify: `C/lib/features/notice/domain/app_notice.dart` (이력 항목용 `visibleSince` 필드를 가진 `NoticeHistoryItem` 추가), `C/lib/features/notice/data/notice_repository.dart` (`fetchHistory`, `markSeen`)
- Test: `C/test/notification_repository_test.dart`, `C/test/notice_repository_test.dart`(추가)

**Interfaces:**
- Produces:
  - `enum NotificationType { routineCompleted, routineSentByCoGuardian, coGuardianJoined, creditRefilled, feedbackResolved }` + `static NotificationType? fromServer(String code)` (모르는 값 null)
  - `class AppNotification { String id; NotificationType type; String? profileId; String? profileName; String? targetId; String? routineTitle; int count; DateTime occurredAt; bool isRead; }` + `static AppNotification? fromJson(Map<String,dynamic>)` (종류 모르면 null)
  - `class NotificationPage { List<AppNotification> items; String? nextCursor; }`
  - `class UnreadSummary { bool hasUnreadNotification; int unreadNotificationCount; bool hasUnreadNotice; static const none = ...; }`
  - `class NotificationSettings { bool allEnabled, routineCompleted, routineSent, coGuardianJoined, creditRefilled, feedbackResolved; copyWith(...); toJson(); fromJson(); }`
  - `NotificationRepository(Dio)`:
    - `Future<NotificationPage> fetchPage({String? cursor, int size = 20})` → `GET /api/notifications`
    - `Future<UnreadSummary> fetchUnreadSummary(NoticePlatform platform)` → `GET /api/notifications/unread-summary?platform=`
    - `Future<void> markRead(String id)` → `POST /api/notifications/{id}/read`
    - `Future<void> markAllRead()` → `POST /api/notifications/read-all`
    - `Future<NotificationSettings> fetchSettings()` / `Future<NotificationSettings> saveSettings(NotificationSettings)` → `GET/PUT /api/notification-settings`
    - 모두 `logged('NotificationRepository', ...)` + 실패 시 `throw AppFailure.of(e)`; 요청에 `extra['skipProfileHeader']=true` (보호자 단위 API)
  - `final notificationRepositoryProvider = Provider((ref) => NotificationRepository(ref.watch(dioProvider)))`
  - `NoticeRepository.fetchHistory(NoticePlatform, {String? cursor})` → `GET /api/notices/history`, `markSeen()` → `POST /api/notices/seen`

- [ ] **Step 1: 실패하는 테스트** (`notification_repository_test.dart`, 패턴: `test/notice_repository_test.dart`의 `_Recorder`)
  - `fetchPage_sendsCursorAndSize_parsesItems`
  - `fetchPage_unknownType_skipsOnlyThatRow`
  - `requests_doNotCarryProfileHeader`
  - `saveSettings_putsAllSixFlags`
  - `fetchUnreadSummary_failure_throwsAppFailure`
- [ ] **Step 2:** `cd client && flutter test test/notification_repository_test.dart test/notice_repository_test.dart` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 PASS
- [ ] **Step 5:** `/pro-commit`

### Task 2: 종 아이콘과 빨간 점 (폰 · 태블릿)

**Files:**
- Create: `C/assets/images/notification_bell.png` 교체 — 원본(1254px)을 96x96으로 줄인 파일로 덮어쓴다(`sips -Z 96`), `C/lib/core/assets/app_assets.dart`에 `notificationBell`, `notificationsEmptyLumi`(이 파일도 480px로 줄임) 추가, `C/assets/images/notifications_empty.png` 삭제
- Create: `C/lib/features/notification/application/unread_summary_provider.dart`
- Create: `C/lib/features/notification/presentation/widgets/notification_bell_button.dart`
- Modify: `C/lib/features/guardian/presentation/guardian_home_header.dart:57-78` (CharacterBadge 앞에 벨), `C/lib/features/guardian/presentation/navigation/guardian_side_nav.dart:64-74` (로고 오른쪽 벨)
- Modify: `C/lib/core/router/routes.dart` (`guardianNotifications = '/guardian/notifications'`, `guardianNotificationSettings = '/guardian/settings/notifications'`)
- Test: `C/test/notification_bell_button_test.dart`, 기존 `guardian_home_golden_test.dart`·태블릿 사이드 내비 골든 갱신

**Interfaces:**
- Produces:
  - `final unreadSummaryProvider = AsyncNotifierProvider<UnreadSummaryNotifier, UnreadSummary>` — `build()`에서 `fetchUnreadSummary`, 실패면 `UnreadSummary.none`(조용히, 로그만). `Future<void> refresh()`.
  - `class NotificationBellButton extends ConsumerWidget` — 탭 → `context.push(Routes.guardianNotifications)`, 점은 `hasUnreadNotification || hasUnreadNotice`일 때. 접근성 라벨 `notificationBellLabel`(+ 안 읽음이면 `notificationBellUnreadLabel`).
  - 갱신 시점: 홈 진입(build), 앱 resume(`PeriodicRefresh` 재사용, 주기 없이 resume만이면 `WidgetsBindingObserver`), 알림 화면에서 돌아올 때(`push` await 후 `refresh()`), #828 푸시 수신 시.

- [ ] **Step 1: 실패하는 테스트** `bell_showsDot_whenUnreadNotification`, `bell_showsDot_whenUnreadNoticeOnly`, `bell_noDot_whenSummaryFails`, `bell_tap_pushesNotificationsRoute`
- [ ] **Step 2:** `flutter test test/notification_bell_button_test.dart` → FAIL
- [ ] **Step 3:** 구현, 헤더·사이드 내비에 배치
- [ ] **Step 4:** PASS + `flutter test --update-goldens test/guardian_home_golden_test.dart`(및 사이드 내비 골든) 후 이미지를 열어 벨 위치가 시안과 같은지 확인
- [ ] **Step 5:** `/pro-commit`

### Task 3: 알림 화면 — 탭 컴포넌트와 알림 탭

**Files:**
- Create: `C/lib/core/widgets/elum_segmented_tabs.dart`
- Create: `C/lib/features/notification/application/{notification_list_controller,notification_day_grouping,notification_navigator}.dart`
- Create: `C/lib/features/notification/presentation/{notifications_screen,widgets/notification_row,widgets/notification_list_tab,widgets/notifications_empty_body}.dart`
- Create: `C/lib/features/notification/presentation/widgets/notification_copy.dart` (종류 → 문구)
- Modify: `C/lib/core/router/routes_guardian.dart` (`GoRoute(path: Routes.guardianNotifications, pageBuilder: (c, s) => slidePage(s, const NotificationsScreen()))`)
- Modify: `C/lib/l10n/app_ko.arb`, `app_en.arb`
- Test: `C/test/notification_day_grouping_test.dart`, `C/test/notification_list_controller_test.dart`, `C/test/notification_navigator_test.dart`, `C/test/notifications_screen_golden_test.dart`

**Interfaces:**
- Produces:
  - `ElumSegmentedTabs({required List<ElumTab> tabs, required int selectedIndex, required ValueChanged<int> onSelected})`, `class ElumTab { String label; bool hasDot; }` (시안 상단 두 칸 탭, 점 포함)
  - `enum NotificationDay { today, yesterday, earlier }` · `List<(NotificationDay, List<AppNotification>)> groupByDay(List<AppNotification>, DateTime now)` (기기 현지 날짜 기준)
  - `final notificationListControllerProvider = AsyncNotifierProvider.autoDispose<NotificationListController, NotificationListState>` — `NotificationListState { List<AppNotification> items; String? nextCursor; bool isLoadingMore; }`, `loadMore()`(id 중복 제거), `refresh()`, `markRead(String id)`(화면 먼저 읽음, 실패해도 되돌리지 않음), `markAllRead()`
  - `final notificationNavigatorProvider` — `Future<void> open(BuildContext context, {required NotificationType type, String? profileId, String? notificationId})`:
    - profileId가 있고 지금 선택과 다르면 `profileSessionProvider.notifier.select(...)`; 내 이룸이 목록에 없으면 `showFailure(..., fallbackCode: 'E-NOTIF-PROFILE')` 후 끝
    - 이동: routineCompleted·routineSentByCoGuardian → `Routes.guardian`(go) / coGuardianJoined → `Routes.guardianPeople`(push) / creditRefilled → `Routes.guardianCreditHistory`(push) / feedbackResolved → 이동 없음
    - 진행 중이면 두 번째 호출 무시
- 문구 (ko / en). 이룸이가 2명 이상인 보호자에게만 줄 위에 `profileName`을 작은 글자로:

| 키 | ko | en |
|---|---|---|
| `notificationRoutineCompletedOne` | '{title}' 일과를 끝냈어요 | Finished '{title}' |
| `notificationRoutineCompletedMany` | 오늘 일과 {count}개를 끝냈어요 | Finished {count} routines today |
| `notificationRoutineCompletedNoTitle` | 일과를 끝냈어요 | Finished a routine |
| `notificationRoutineSent` | 함께하는 보호자가 '{title}' 일과를 보냈어요 | A co-guardian sent '{title}' |
| `notificationRoutineSentNoTitle` | 함께하는 보호자가 새 일과를 보냈어요 | A co-guardian sent a new routine |
| `notificationCoGuardianJoined` | 새 보호자가 함께하기 시작했어요 | A new guardian joined |
| `notificationCreditRefilled` | 이번 주 크레딧이 채워졌어요 | This week's credits are refilled |
| `notificationFeedbackResolved` | 보내 주신 의견을 확인하고 처리했어요 | We reviewed your feedback |
| `notificationTabNotifications` / `notificationTabNotices` | 알림 / 공지사항 | Notifications / Notices |
| `notificationDayToday` / `Yesterday` / `Earlier` | 오늘 / 어제 / 이전 | Today / Yesterday / Earlier |
| `notificationMarkAllRead` | 모두 읽음 | Mark all read |
| `notificationEmpty` | 아직 받은 알림이 없어요 | No notifications yet |
| `notificationListFailed` | 알림을 불러오지 못했어요 | Couldn't load notifications |
| `notificationProfileUnavailable` | 이 이룸이의 알림은 더 볼 수 없어요 | This ELUM user is no longer available |

- [ ] **Step 1: 실패하는 테스트**
  - `groupByDay_splitsTodayYesterdayEarlier`, `groupByDay_afterMidnight_recomputesWithNewNow`
  - `loadMore_dropsDuplicateIdsAtCursorBoundary`, `markRead_failure_keepsReadInUi`
  - `open_otherProfile_selectsThenGoesHome`, `open_lostProfile_showsFailureAndStays`, `open_calledTwiceFast_navigatesOnce`, `open_feedbackResolved_doesNotNavigate`
- [ ] **Step 2:** `flutter test test/notification_day_grouping_test.dart test/notification_list_controller_test.dart test/notification_navigator_test.dart` → FAIL
- [ ] **Step 3:** 구현 (안 읽은 줄 바탕은 민트 연한 토큰 — 없으면 `design/tokens`에 `notificationUnreadBackground` 추가, 빈 화면 `AppAssets.notificationsEmptyLumi`, 실패 `ElumErrorView.failure(e, errorCode: 'E-NOTIF-LIST', onRetry: refresh)`)
- [ ] **Step 4:** PASS + 골든 3장(목록 / 빈 화면 / 실패) 생성 후 시안 이미지와 나란히 열어 확인
- [ ] **Step 5:** `/pro-commit`

### Task 4: 공지사항 탭

**Files:**
- Create: `C/lib/features/notification/application/notice_history_controller.dart`, `C/lib/features/notification/presentation/widgets/notice_history_tab.dart`
- Test: `C/test/notice_history_controller_test.dart`

**Interfaces:**
- Consumes: `NoticeRepository.fetchHistory`, `markSeen` (Task 1), 기존 `parseNoticeTitle()`, 공지 상세는 기존 `show_notice_popup.dart`의 슬라이드 위젯 재사용(한 건만)
- Produces: `noticeHistoryControllerProvider` (AsyncNotifier, 페이지), 탭을 처음 열 때 `markSeen()` 1회 → `unreadSummaryProvider.refresh()`
- 문구: `notificationNoticeEmpty` 아직 올라온 공지가 없어요 / No notices yet, 실패 `E-NOTICE-HISTORY`

- [ ] **Step 1: 실패하는 테스트** `openTab_marksSeenOnce_andRefreshesSummary`, `markSeenFails_listStillShows`
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS + 골든 1장
- [ ] **Step 5:** `/pro-commit`

### Task 5: 알림 설정 화면

**Files:**
- Modify: `C/pubspec.yaml` (`app_settings: ^6.1.1`)
- Create: `C/lib/features/notification/data/notification_permission_gate.dart`
- Create: `C/lib/features/notification/application/notification_settings_controller.dart`
- Create: `C/lib/features/notification/presentation/notification_settings_screen.dart`
- Modify: `C/lib/features/guardian/presentation/guardian_settings_screen.dart:188` `_list()` (설정 줄 `notificationSettingsTitle` → `Routes.guardianNotificationSettings`), `routes_guardian.dart`
- Test: `C/test/notification_settings_controller_test.dart`, `C/test/notification_settings_screen_golden_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class NotificationPermissionGate { Future<bool> isGranted(); Future<bool> request(); Future<void> openDeviceSettings(); }` — 구현 `LocalNotificationPermissionGate`: Android `areNotificationsEnabled()`·`requestNotificationsPermission()`, iOS `checkPermissions()`·`requestPermissions(alert: true, badge: false, sound: true)`, 열기 `AppSettings.openAppSettings(type: AppSettingsType.notification)`. `final notificationPermissionGateProvider`.
  - `notificationSettingsControllerProvider` — `toggle(NotificationSettingField field, bool value)`: 화면 먼저 바꾸고 저장, 실패면 직전 값 복원 + `showFailure(fallbackCode: 'E-NOTIF-SETTING')`; 연속 토글은 마지막 요청만 반영(진행 중 요청이 끝나면 최신 값으로 한 번 더 저장).
  - `enum NotificationSettingField { all, routineCompleted, routineSent, coGuardianJoined, creditRefilled, feedbackResolved }`
  - `allEnabled`가 꺼지면 종류별 스위치는 회색(비활성), 값은 유지.
  - 기기 권한이 꺼져 있으면 맨 위 안내 줄 + `notificationOpenDeviceSettings` 버튼. 화면 resume 시 다시 확인.
- 문구: `notificationSettingsTitle` 알림 설정, `notificationSettingAll` 모든 알림 받기, `notificationSettingRoutineCompleted` 이룸이가 일과를 끝냈을 때, `notificationSettingRoutineSent` 다른 보호자가 일과를 보냈을 때, `notificationSettingCoGuardianJoined` 새 보호자가 함께할 때, `notificationSettingCreditRefilled` 이번 주 크레딧이 채워졌을 때, `notificationSettingFeedbackResolved` 의견을 처리했을 때, `notificationPermissionOff` 기기 알림이 꺼져 있어 알림을 받을 수 없어요, `notificationOpenDeviceSettings` 기기 설정 열기, `notificationSettingSaveFailed` 설정을 저장하지 못했어요 (en 같은 뜻)

- [ ] **Step 1: 실패하는 테스트** `toggle_failure_restoresPrevious_andShowsCode`, `toggle_rapid_lastValueWins`, `allOff_disablesTypeSwitches_keepsValues`
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS + 골든 2장(권한 켜짐 / 꺼짐 안내)
- [ ] **Step 5:** `/pro-commit`

### Task 6: 전체 확인

- [ ] **Step 1:** `cd client && flutter analyze --no-fatal-infos` 0건, `flutter test` 전체 PASS(골든 포함)
- [ ] **Step 2:** 로컬 서버(#827 브랜치, 키 없음)에 붙여 iOS 시뮬레이터 폰·아이패드에서 `/pro-launch`로: 종 → 알림 탭(데이터는 DB에 직접 넣은 알림 3건) → 누르면 이동 → 모두 읽음 → 빨간 점 사라짐 → 공지 탭 → 설정 화면 스위치 저장. 각 화면 캡처를 열어 확인
- [ ] **Step 3:** `/pro-commit` (골든·문서)
