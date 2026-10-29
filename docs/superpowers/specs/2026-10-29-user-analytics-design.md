# 사용자 행동 분석 이벤트 설계 (#650)

## 문제

- 보호자가 어디서 멈추는지(온보딩 이탈), 일과 생성이 얼마나 성공하는지, 이룸이 화면을 얼마나 쓰는지 데이터가 없다.
- 앱에 분석 도구가 없다.

## 사용자 결정 (2026-10-29)

- 수집 코드는 넣는다. **운영에서는 꺼 둔다.** 테스트 빌드의 개발자 도구에서만 켤 수 있다.
- 개인정보처리방침·스토어 개인정보 항목은 고치지 않는다. 개정 초안만 이슈에 남긴다.

## 검토한 안

| 안 | 장점 | 단점 | 결정 |
|---|---|---|---|
| Firebase Analytics | 무료, FCM·Crashlytics 와 같은 Firebase 프로젝트, 국외 이전 대상이 늘지 않음 | 데이터가 Google(미국)로 감, 콘솔 반영이 늦음(최대 하루) | **채택** |
| Amplitude·Mixpanel | 퍼널 분석 화면이 좋음 | 새 계정·키 관리, 국외 이전 대상 하나 더 | 안 씀 |
| 서버 자체 수집 | 데이터가 우리 서버에만 | 화면 추적까지 API·저장소를 새로 만들어야 함 (M 크기 초과) | 안 씀 |

## 수집 켜는 조건 (#659 와 같은 게이트 3겹)

1. 네이티브 기본값: Android `firebase_analytics_collection_enabled=false`, iOS `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false`
   - `..._DEACTIVATED` 는 쓰지 않는다. 런타임에 다시 켤 수 없기 때문이다
2. 빌드: `AppConfig.showDevTools` (개발자 도구 빌드만). 운영 빌드는 저장값과 무관하게 꺼짐
3. 사용자 조작: 개발자 도구 `분석 보내기` 스위치 (기본 꺼짐, `dev.isAnalyticsEnabled` 에 저장)

시작할 때마다 `setAnalyticsCollectionEnabled(값)` 을 명시한다. 끌 때는 `resetAnalyticsData()` 로 기기의 분석 데이터와 앱 인스턴스 id 를 지운다.

광고 식별자는 분석에서 뺀다.

| 플랫폼 | 설정 |
|---|---|
| Android | `google_analytics_adid_collection_enabled`, `google_analytics_ssaid_collection_enabled`, `google_analytics_default_allow_ad_personalization_signals` 를 false |
| iOS | Podfile `$FirebaseAnalyticsWithoutAdIdSupport = true` (IDFA 없는 `FirebaseAnalytics/Core`), `GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED`·`GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS` 를 false |

자동 화면 기록(Activity·UIViewController)도 끈다. Flutter 는 화면이 하나라 의미 없는 값만 남고, 라우터 기록과 겹친다.

## 공통화

- `DeveloperCollectionOptIn` (`core/config/`): 켤 수 있는 빌드 판정과 저장값 읽기·저장. CrashReporter·AppAnalytics 가 같이 쓴다. "운영 빌드는 항상 꺼짐" 규칙이 한 곳에만 있다
- `_SwitchTile` (`core/dev/dev_tools_widgets.dart`): 개발자 도구의 켜고 끄는 행. 온보딩 건너뛰기·크래시 보내기·분석 보내기 3곳째라 뽑았다

## 화면 추적

- `AnalyticsScreenTracker` 가 라우터 위치 변경(`routerDelegate` 알림)을 보고 맨 위 화면의 **경로 패턴**(`GoRouterState.fullPath`)을 `screen_view` 로 보낸다
- NavigatorObserver 를 쓰지 않은 이유: 보호자 하단 바 칸 전환(`StatefulShellRoute`)은 루트 네비게이터에 push 가 없어 관찰자가 보지 못한다
- 경로 패턴(`/guardian/talk/posts/:postId`)만 보내므로 실제 id·쿼리(초대 코드 등)가 빠진다. 다이얼로그·시트는 세지 않는다
- 같은 패턴이 연달아 오면(쿼리만 바뀜) 한 번만 보낸다

## 핵심 이벤트

이름·파라미터 키는 `core/analytics/analytics_events.dart` 한 곳. 값은 숫자(1·0 포함)와 에러 코드만 쓴다.

| 이벤트 | 지점 | 파라미터 | 답하는 질문 |
|---|---|---|---|
| `screen_view` | 라우터 위치 변경 | `screen_name`(경로 패턴) | 어느 화면에서 멈추는가 (온보딩 단계별 이탈, 이룸이 화면 사용률) |
| `onboarding_complete` | `OnboardingNotifier.complete` 끝 | `is_server_saved`, `example_category_count` | 새 보호자 중 몇 %가 온보딩을 마치는가, 서버 저장 실패는 얼마나 되는가 |
| `routine_generate_start` | `_createRoutine` 시작 (AI 요청 1회) | 없음 | 일과 생성을 몇 번 시도하는가 |
| `routine_generate_complete` | 생성 성공 | `card_count` | 생성 성공률, 카드 수 분포 |
| `routine_generate_fail` | 생성 실패·시간 초과 | `error_code` | 어떤 오류로 실패하는가 (크레딧 부족 `CREDIT_*` 포함) |
| `routine_confirm` | 카드확인 `저장하기` 승인 성공 | `card_count` | 만든 일과 중 몇 %를 이룸이에게 보내는가 |
| `child_routine_complete` | 이룸이가 마지막 카드를 처음 체크 | `card_count` | 이룸이가 일과를 끝까지 하는가 |
| `credit_blocked` | 일과 만들기 전 크레딧 안내 팝업 | `reason`(`exhausted`·`generating`) | 크레딧 부족으로 얼마나 막히는가 |
| `feedback_send` | 의견 보내기 결과 | `is_sent`, `has_app_log`, `error_code`(실패 시) | 의견 보내기를 쓰는가, 실패하는가 |

## 보내지 않는 것 (서비스 원칙 1·5)

- 진단명·장애 유형, `supportGoals`
- 원문: 보호자 입력, 카드 글, 일과 제목, 의견 글
- 아이 이름, 토큰, 연결 암호·초대 코드, 사용자 id(`setUserId` 안 부름), 사용자 속성(`setUserProperty` 안 부름)
- 광고 식별자 (위 네이티브 설정)

이벤트 메서드가 타입 있는 인자(숫자·bool·코드)만 받아, 부르는 쪽이 자유 문자열을 실을 길이 없다.

## 실패 경로

| 상황 | 동작 |
|---|---|
| Firebase 설정 파일 없음·초기화 실패 | `initializeFirebase` 가 잡고 수집만 꺼짐. 스위치를 켜면 "반영 실패" 안내 |
| 수집 설정·저장값 읽기 실패 | 꺼짐으로 두고 로컬 로그에 기록 |
| 전송 실패(동기·비동기) | 무시. `.ignore()` 로 비동기 실패가 PlatformDispatcher 로 가지 않게 |
| 라우터 상태 읽기 실패·빈 설정 | 그 이동만 건너뜀. 화면 이동은 그대로 |
| 생성 시간 초과 뒤 늦은 성공 | `fail` 과 `complete` 가 둘 다 남음. 시간 초과율을 보는 데는 그대로 쓴다 |

## 하지 않는 것

- 운영 빌드에서 켜기, 개인정보처리방침·스토어 개인정보 항목 수정
- 사용자 id·사용자 속성, 광고 전환 연동, 동의(Consent Mode) 화면
- 이벤트 단위 테스트 (앱 테스트는 두지 않음, #848)

## 남은 일

- 개인정보처리방침 개정 확정, 스토어 개인정보 항목(App Store 앱 개인정보·Play 데이터 보안) 반영
- 운영에서 켜기 결정
- 실기기에서 DebugView 로 이벤트 수신 확인
