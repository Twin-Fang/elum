# 개발자 도구 오버레이 설계

- 날짜: 2026-07-21
- 대상: `client` — 신규 `core/dev/`, `AppConfig`, `LocalStorage`, `app.dart`, `main.dart`

## 배경

온보딩을 한 번 끝내면 `onboardingCompleted: true`가 기기에 저장되고, 이후 시작 화면이
보호자 홈으로 바로 넘어간다 (`splash_screen.dart` — `isDone ? Routes.guardian : ...`).
온보딩 화면을 다시 보려면 앱을 삭제·재설치해야 한다.

이 동작 자체는 정상이다. 문제는 **개발·데모·심사 중에 그 상태를 초기화할 수단이 없다**는 것.
Figma 대조 작업 중에는 화면을 수십 번 확인하므로 재설치 방식은 현실적이지 않다.

또한 실기기·릴리스 빌드에서는 `flutter run` 콘솔이 없어 **로그를 볼 방법이 없다.**
데모 중 문제가 생기면 원인을 알 수 없다.

## 범위

앱 내 개발자 도구 오버레이를 만든다. 플래그로 켜고 끈다.

### 할 수 있는 것 / 없는 것

| 기능 | 가능 | 비고 |
| --- | --- | --- |
| 온보딩 상태 리셋 | O | 저장소만 지우면 된다 |
| 앱 내 로그 뷰어 | O | `debugPrint`를 링버퍼로 가로챈다 |
| 로그 클립보드 복사 | O | |
| 현재 상태 덤프 | O | 저장값·설정값 |
| 화면 바로 이동 | O | go_router |
| **git 커밋·푸시** | **X** | 아래 참조 |

**앱에서 git 커밋·푸시는 구현하지 않는다.** Flutter 앱은 샌드박스 안에서 동작해
git 바이너리에 접근할 수 없고, 앱이 자기 소스 저장소를 들고 있지도 않다. 심사 대상
앱에 git 자격증명을 넣는 것은 보안상으로도 부적절하다. 커밋·푸시는 개발 머신에서 한다.

## 설계

### 1. 표시 플래그 — `kDebugMode`를 걸지 않는다

```dart
/// 개발자 도구 오버레이를 띄울지.
///
/// ⚠️ [enableNetworkLog]와 달리 `kDebugMode`를 걸지 않는다.
/// 심사자·테스터는 릴리스 빌드로 확인하므로 debug 게이트를 걸면 보이지 않는다.
/// 정식 출시 전 `.env`에서 false로 바꾼다.
static bool get showDevTools => _bool('ELUM_SHOW_DEV_TOOLS', false);
```

`enableNetworkLog`는 `kDebugMode &&`를 쓰지만 이 플래그는 쓰지 않는다.
**목적이 다르기 때문이다** — 네트워크 로깅은 운영에서 절대 켜지면 안 되는 값이고,
개발자 도구는 심사·데모 중 릴리스 빌드에서 켜져야 하는 값이다.

기본값은 `false`. `.env`에 명시적으로 켠 사람만 동작한다.

### 2. 저장소 초기화 — `LocalStorage.clearAll()`

인터페이스에 추가해 `SharedPrefsStorage`·`InMemoryStorage` 양쪽이 구현한다.
인터페이스에 두어야 테스트에서 동작을 검증할 수 있다.

```dart
/// 저장된 온보딩 결과를 전부 지운다. **개발·테스트 전용.**
Future<void> clearAll();
```

5개 키(호칭·목표·캐릭터·PIN·완료여부)를 모두 지운다. 일부만 지우면 어중간한
상태가 남아 더 헷갈린다.

### 3. 로그 수집 — 링버퍼

`main()`에서 `debugPrint`를 감싼다. 원본 출력은 유지하고 버퍼에도 쌓는다.

```dart
/// 앱 내 로그 뷰어용 링버퍼. 최근 [_maxLines]줄만 유지한다.
///
/// 원문 비저장 원칙(docs 원칙 5번)은 그대로다 — 보호자 입력 원문은
/// 애초에 debugPrint로 나가지 않으므로 이 버퍼에도 담기지 않는다.
```

메모리를 무한정 먹지 않도록 200줄 상한을 둔다.

### 4. 오버레이 배치 — `MaterialApp.router`의 `builder`

화면별 코드를 전혀 건드리지 않는다. `app.dart` 한 곳에서 모든 화면 위에 얹는다.

```dart
builder: (context, child) => MaterialApp.router(
  ...
  builder: (context, child) => DevToolsOverlay(child: child),
),
```

플래그가 꺼져 있으면 `child`를 그대로 반환해 **런타임 비용이 0이다.**

### 5. UI

- 드래그 가능한 작은 원형 버튼 (기본 우하단)
- 탭하면 바텀시트로 패널 표시
- 아동도 볼 수 있는 화면이므로 눈에 띄지 않는 반투명 회색

**패널 기능 4개**

| 기능 | 동작 |
| --- | --- |
| 온보딩 초기화 | 확인 다이얼로그 → `clearAll()` → 시작 화면 이동 |
| 로그 보기 | 최근 200줄 + 복사 버튼 |
| 현재 상태 | 저장값(호칭·목표·캐릭터·PIN 여부)·설정값(API URL·mock) |
| 화면 이동 | 온보딩 각 단계·보호자 홈 |

**PIN은 값을 표시하지 않고 설정 여부만 보여준다.** 평문 저장 중이라 화면에 띄우면
어깨너머로 노출된다.

## 테스트

기능이 층으로 나뉘므로 테스트도 나눈다. `main.dart`의 분기는 테스트하지 않는다 —
`main()`은 `WidgetsFlutterBinding`과 실제 `SharedPreferences`를 잡아 위젯 테스트로
감쌀 수 없다. 대신 조각을 각각 테스트하고 `main()`은 잇기만 하는 몇 줄로 유지한다.

| 대상 | 검증 | 파일 |
| --- | --- | --- |
| `clearAll()` | 5개 값이 전부 지워진다 | `test/local_storage_test.dart` (신설) |
| `showDevTools` | 기본값 false, `.env`로 켜진다 | `test/app_config_test.dart` (기존) |
| 로그 버퍼 | 상한 초과 시 오래된 줄부터 버린다 | `test/dev_log_buffer_test.dart` (신설) |
| 오버레이 | 플래그 꺼지면 렌더링되지 않는다 | `test/dev_tools_overlay_test.dart` (신설) |

## 정식 출시 전 할 일

이 기능은 **임시**다. 코드에 이슈 번호와 함께 제거 안내를 남긴다.

- `.env` / GitHub Secret `CLIENT_ENV_FILE`에서 `ELUM_SHOW_DEV_TOOLS=false`
- 또는 `core/dev/` 디렉터리 통째 삭제 + `app.dart`의 `builder` 한 줄 제거

## 범위 밖

- git 커밋·푸시 — 위 「할 수 있는 것/없는 것」 참조
- 로그 파일 저장·서버 전송 — 원문 비저장 원칙과 충돌할 여지가 있어 하지 않는다
- 네트워크 요청 목록 뷰어 — 지금은 mock 위주라 가치가 낮다 (YAGNI)
