# 크래시·오류 수집 도구 도입 설계 (#659)

## 문제

- 앱스토어에 출시됐는데 실사용자 크래시 여부·빈도를 모른다. 스토어 콘솔이나 의견 보내기로만 알 수 있다.
- 전역 오류 처리(`AppDiagnostics`)는 기기 안 로그 버퍼에만 적는다.

## 사용자 결정 (2026-10-29)

- 수집 코드는 넣는다. **운영에서는 꺼 둔다.** 테스트 빌드의 개발자 도구에서만 켤 수 있다.
- 개인정보처리방침(법적 문구)은 고치지 않는다. 개정 초안만 이슈 댓글로 남긴다.

## 검토한 안

| 안 | 장점 | 단점 | 결정 |
|---|---|---|---|
| Firebase Crashlytics | 무료, 이미 FCM 으로 같은 Firebase 프로젝트 사용, iOS·Android 지원, #650 분석과 묶임 | 데이터가 Google(미국)로 감 | **채택** |
| Sentry | 오류 문구 마스킹 규칙이 풍부 | 유료 구간, 새 계정·DSN 관리, 국외 이전 대상 하나 더 늘어남 | 안 씀 |

## 수집 켜는 조건 (게이트 3겹)

1. 네이티브 기본값: `AndroidManifest.xml` `firebase_crashlytics_collection_enabled=false`, `Info.plist` `FirebaseCrashlyticsCollectionEnabled=false`
2. 빌드: `AppConfig.showDevTools` (개발자 도구 빌드만). 운영 빌드는 저장값과 무관하게 꺼짐
3. 사용자 조작: 개발자 도구 `크래시 보내기` 스위치 (기본 꺼짐, `dev.isCrashReportingEnabled` 에 저장)

시작할 때마다 `setCrashlyticsCollectionEnabled(값)` 을 명시한다. 네이티브가 이전 값을 기억하기 때문이다.
끌 때는 `deleteUnsentReports()` 로 꺼진 동안 기기에 쌓인 보고서를 지운다.

## 보내는 것 / 보내지 않는 것 (서비스 원칙 5)

| 보냄 | 보내지 않음 |
|---|---|
| 오류 종류(타입 이름), 스택, 에러 코드(`E-AUTH` 등), 치명 여부 | 오류 메시지(입력값·URL·토큰이 섞일 수 있음) |
| SDK 기본: 앱 버전, OS·버전, 기기 모델·상태, 무작위 설치 번호 | 원문, 아이 이름, 토큰, 사용자 식별자(`setUserIdentifier` 안 부름), 커스텀 키·로그 |

원래 오류 대신 `RedactedError(타입 이름)` 을 보낸다. 사용자 식별자가 필요해지면 내부 id 의 해시만 쓴다(지금은 안 붙임).

## 연결 지점

- `AppDiagnostics._recordUnhandled` (FlutterError.onError · PlatformDispatcher.onError) > `CrashReporter.recordFatal`
- `showFailure` 중 앱 쪽 실패(서버 응답·네트워크 끊김 제외) > `CrashReporter.recordHandled(errorCode)`
- `initializeFirebase` 성공 뒤 > `CrashReporter.applySavedSetting`
- 개발자 도구: 스위치, 테스트 오류(비치명 `E-DEV-CRASH-TEST`), 테스트 크래시(앱 종료)

## 빌드 단계

- Android: Crashlytics Gradle 플러그인(빌드 ID 주입에 필요). R8 매핑 업로드는 기본 끔, `-PelumCrashlyticsMappingUpload=true` 일 때만. 업로드 실패로 배포 빌드가 깨지지 않게
- iOS: dSYM 업로드 스크립트는 넣지 않는다. Dart 스택은 dSYM 없이 읽힌다. 운영에서 켤 때 함께 정한다

## 실패 경로

| 상황 | 동작 |
|---|---|
| Firebase 설정 파일 없음 | `initializeFirebase` 가 잡고 수집만 꺼짐. 스위치를 켜면 "반영 실패" 안내 |
| 수집 설정·저장값 읽기 실패 | 꺼짐으로 두고 로컬 로그에 기록 |
| 전송 실패(동기·비동기) | 무시. `.ignore()` 로 비동기 실패가 PlatformDispatcher 로 되돌아오지 않게 |

## 하지 않는 것

- 운영 빌드에서 켜기, 개인정보처리방침 수정, iOS dSYM 업로드, `ElumErrorView` 기록(빌드마다 불려 중복 전송)

## 남은 일

- 개인정보처리방침 개정 확정, 운영에서 켜기 결정, 실기기 크래시 수신 확인
