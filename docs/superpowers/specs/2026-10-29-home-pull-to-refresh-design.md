# 이룸이 홈 · 보호자 홈 당겨서 새로고침 설계 (#998)

## 문제

- 이룸이 홈은 30초마다 저절로 오늘 일과를 다시 받는다(`RoutineAutoRefresh` > `PeriodicRefresh`). 보호자가 방금 보낸 일과를 보려면 최대 30초를 기다려야 하고, 직접 받을 방법이 없다.
- 보호자 홈도 같다. 다른 보호자가 같은 이룸이에게 더한 일과를 보려면 화면을 나갔다 들어와야 한다.

## 조사

| 항목 | 현재 |
|---|---|
| `RefreshIndicator` 사용처 | 4곳: 알림 목록 · 공지 기록 탭(`notification_list_tab`, `notice_history_tab`), 이야기 목록 · 상세(`talk_feed_screen`, `talk_detail_screen`). 두 홈에는 없다 |
| 실패 처리 | 이야기 2곳은 `try` > 실패면 `unawaited(showFailure(...))`, 같은 모양이 두 번 반복. 알림 2곳은 컨트롤러가 오류를 상태로 바꿔 던지지 않는다 |
| 색 | 4곳 모두 테마 기본값(`colorScheme.primary` = `textPrimary`) |
| 자동 새로고침 | `RoutineAutoRefresh._refresh`: `todayRoutinesProvider` 가 받는 중(`isLoading`)이면 건너뛰고, 아니면 `invalidate` |
| 실패 시 목록 | `todayRoutinesProvider` · `pastRoutinesProvider` 는 `invalidate` 후 실패해도 `.value` 에 직전 목록이 남는다(Riverpod 3). 두 홈 모두 `.value` 로 그린다 |
| #987 우회 | `readRoutineManageSourcesBeforeEntering` 은 일과관리 칸에 들어가기 전에 목록을 미리 읽는다. 홈에서 오늘·지난 목록만 다시 받으면 지금의 30초 주기와 같은 경로라 새 충돌이 없다 |

## 검토한 안

| 안 | 내용 | 판단 |
|---|---|---|
| A. 홈마다 `RefreshIndicator` 직접 | 두 홈에 이야기 화면 모양 그대로 복사 | 실패 처리 복사본이 4곳이 된다. 3번째에 공통화 규칙 위반 |
| **B. 공통 위젯 `ElumPullToRefresh`** | 받기 > 실패면 실패 팝업(에러 코드)을 한 곳에. 기존 4곳도 옮기고 규칙 검사로 직접 사용을 막는다 | **고름.** 색 토큰 · 실패 안내 · 당김 물리값을 한 곳에서 정한다 |
| C. `SingleFlight` 로 겹침 방지 | 당김 전용 잠금 객체 | 자동 새로고침은 `invalidate` 라 잠금을 거치지 않는다. 둘이 같은 기준을 보려면 provider 상태(`isLoading`)를 기준으로 삼는 편이 맞다 |

## 설계

### 1. 공통 위젯 `core/widgets/elum_pull_to_refresh.dart`

- `ElumPullToRefresh({onRefresh, failureMessage, failureCode, child})`
  - `onRefresh` 가 던지면 `showFailure(failureMessage, failureCode)` — 스피너는 팝업을 기다리지 않는다(`unawaited`).
  - 색: 동그라미 `colors.textPrimary`, 바탕 `colors.surface`(토큰).
- 물리값 상수 2개
  - `physics` = `AlwaysScrollableScrollPhysics()` — 내용이 짧거나 0건이어도 당겨진다.
  - `calmPhysics` = `AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics())` — 이룸이 화면용. iOS 에서도 목록이 끝에서 튕겨 늘어나지 않고 동그라미만 내려온다.
- `tool/design_rules.yaml` `material_widgets` 에 `RefreshIndicator` 추가, 감싸는 파일로 이 위젯만 허용.

### 2. 겹침 방지 `core/state/refresh_joining_in_flight.dart`

- `refreshJoiningInFlight(ref, provider)`: provider 가 받는 중이면 그 결과를 기다리고(요청 안 보냄), 아니면 `ref.refresh(provider.future)`.
- 자동 새로고침의 "받는 중이면 건너뜀"과 같은 기준(`isLoading`)이라 어느 쪽이 먼저 시작해도 요청은 한 번이다.
  - 당김 중 30초 주기 도착 > `isLoading` 이라 건너뜀
  - 30초 주기 받는 중 당김 > 그 요청 결과를 기다림
  - 받는 중 또 당김 > `RefreshIndicator` 가 끝날 때까지 새 당김을 받지 않음

### 3. 무엇을 다시 받나 (`routine_providers.dart` 확장)

| 화면 | 다시 받는 것 | 실패 코드 · 문구 |
|---|---|---|
| 이룸이 홈 | 오늘 일과 | `E-CHLIST` · `todayRoutineLoadFailedFallback` (빈 화면 코드와 같음) |
| 보호자 홈 | 오늘 + 지난 일과 (화면에 보이는 두 칸) | `E-HOME` · `todayRoutineLoadFailedFallback` |

- 일과관리 원본 · 묶음 · 전체 목록(`refreshRoutines()`)은 다시 받지 않는다. 홈에 안 보이고, 들어갈 때 #987 경로로 다시 계산된다.
- 회원 정보(별)는 지금처럼 30초 주기만 받는다.

### 4. 화면 적용

| 화면 | 배치 | 적용 |
|---|---|---|
| 이룸이 홈 | 세로(폰 · 태블릿) | 기존 `SingleChildScrollView` 를 감싸고 `calmPhysics` |
| 이룸이 홈 | 가로 태블릿 두 칸 | 오른쪽 목록 칸만 감싼다(동그라미가 목록 위에 나옴) |
| 이룸이 홈 | 일과 0건 | 빈 화면을 남는 높이 그대로 스크롤 안에 넣어(`calmPhysics`) 당겨지게. 배치는 그대로 |
| 보호자 홈 | 폰 · 세로 | 기존 스크롤을 감싸고 `physics` |
| 보호자 홈 | 가로 태블릿 두 칸 | 오른쪽 목록 칸만 감싼다 |
| 보호자 홈 | 코치마크 중 | 지금처럼 `NeverScrollableScrollPhysics` — 당김도 막힌다(구멍이 어긋나지 않게) |

## 실패 경로

| 상황 | 동작 |
|---|---|
| 네트워크 실패 · 타임아웃 | 보이던 목록 유지(빈 화면으로 안 바뀜) + 실패 팝업(에러 코드). 이룸이 화면도 실패는 `showFailure` 하나로 알린다는 기존 규칙(#433) |
| 목록이 0건에서 실패 | 이룸이 홈: 빈 화면에 코드 표시(기존) + 팝업. 보호자 홈: 칸 안 실패 표시(기존) + 팝업 |
| 조용한 실패(`AppFailure.isSilent`, 로그아웃 등) | 팝업 없음(`showFailure` 규칙 그대로) |
| 받는 중 또 당김 · 주기 갱신과 겹침 | 요청 1번 (2절) |
| 받는 중 화면을 떠남 | `context.mounted` 확인 후에만 팝업 |

## 하지 않는 것

- 서버 변경, 실시간 푸시로 목록 갱신
- 30초 자동 새로고침 동작 변경
- 알림 · 공지 탭 빈 화면의 당김 문제(빈 화면 스크롤이 `AlwaysScrollable` 이 아님)는 이번에 고치지 않는다 — 위젯만 공통 위젯으로 바꾼다

## 검증

- `flutter analyze`, `dart run tool/check_design_rules.dart`, `check_layer_imports.dart`, `check_hangul_literals.dart lib`
- 시뮬레이터에서 두 홈 당김 캡처(가능하면)
