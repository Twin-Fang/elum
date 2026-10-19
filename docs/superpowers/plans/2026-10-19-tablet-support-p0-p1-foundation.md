# 태블릿 지원 P0·P1 (스파이크 + 기반 + 폰 비율 열) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 창 크기를 한 곳에서 판단해 크기 배율을 정하고, 모든 화면이 태블릿에서 깨지지 않는 "폰 비율 가운데 열"을 기본으로 깐다. 폰 출력은 한 픽셀도 바뀌지 않는다.

**Architecture:** `core/layout/`에 창 등급·배율 계산(순수 함수)과 루트 스코프를 둔다. `ScreenUtilInit`의 `designSize`를 창 크기에 맞춰 바꿔 `.w/.h`가 같은 배율 s를 갖게 한다(compact는 현행 그대로). 각 라우트는 `slidePage`/`fadePage`를 통해 `AdaptivePageFrame`에 들어가고, 시트·다이얼로그는 공통 헬퍼에서 폭 상한을 건다. 사용자에게 열리는 네이티브 스위치(아이패드 family, Android 세로 고정 해제)는 이 계획에서 **켜지 않고** 로컬 검증용 패치로만 둔다.

**Tech Stack:** Flutter, `flutter_screenutil 5.9.3`, `go_router`, Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-19-tablet-support-design.md` (§4 결정, §6 이름, §9 테스트, §10 단계)

**이 계획의 범위 밖 (P1이 땅에 닿은 뒤 각각 별도 계획):** P2 이룸이 적응형 화면 · P3 보호자 적응형 화면 · P4 나머지 화면/문구("기기")/광고/공유 · P5 스토어 자산과 네이티브 스위치 켜기.

## Global Constraints

- 위치: 새 코드는 `client/lib/core/layout/`. `core/`는 `features/`를 import하지 않는다 (`test/tool/check_layer_imports_test.dart`가 막음, 동결 목록에 줄을 **더하지 않는다**).
- 주석은 한국어, 명사형·짧은 구, WHY 중심. 작업 경위·"~합니다" 문장 금지. 로그는 영어 + 기능 접두사.
- 이름: 약어 금지, boolean은 `is/has/can/should`, 파일명 = 주된 타입 이름(snake_case), 한 파일 300줄 이하.
- 화면 코드에 색·간격·breakpoint 숫자를 직접 쓰지 않는다. 숫자는 `AppLayout`(`context.layout`)에서만.
- 창 등급: `compact <600 / medium 600~839 / expanded ≥840` (창 폭 dp). 높이 `<480`이면 `isShortHeight`.
- 배율(medium·expanded): `s = clamp(min(창폭/393, 창높이/852), 0.80, 1.30)`, compact는 **현행 그대로**(실제 창 크기).
- 폰 회귀 0: 기존 테스트·골든은 하나도 바뀌지 않는다. 골든을 갱신하지 않는다.
- 사용자에게 열리는 네이티브 변경(`TARGETED_DEVICE_FAMILY`, iPad 방향 키, `screenOrientation`)은 **커밋하지 않는다**. 패치 파일로만 둔다.
- 사용자 문구를 새로 만들지 않는다 (이 계획은 문구 변경 없음). 이룸이를 "아이"라 쓰지 않는다.
- `git push` 금지(사용자 요청 시만), 커밋은 `/pro-commit`으로 **내가 건드린 경로만** 스테이징, `git add -A` 금지. 테스트 환경에서 `devicePixelRatio`를 반드시 고정한다(기본값이면 비율이 2배로 잡히는 함정).

## Review Focus

사용자가 실제로 겪기 쉬운데 spec이 직접 말하지 않는 입력 (각 줄의 테스트는 지정한 Task에 있다):

1. 첫 프레임 창 크기 0×0 → compact로 취급, 예외 없음 (Task 1)
2. 회전·분할로 등급이 compact↔medium 경계를 넘을 때 입력 중인 글이 사라짐 (Task 4)
3. 프레임 스크롤 폴백 + 키보드가 올라온 상태에서 CTA가 가려짐 (Task 4)
4. 분할 보기 극단 320×1024 · 1024×320에서 오버플로 (Task 7)
5. 글자 크기 200% + 가로에서 오버플로 (Task 7)
6. 아주 넓은 창(1366+, 크롬북)에서 시트·다이얼로그가 전폭으로 늘어남 (Task 5)

---

### Task 0: 이슈 · worktree

**Files:** 없음 (운영 작업)

- [ ] **Step 1:** `/pro-github`로 이슈 생성. 제목 `⚙️[기능추가][클라][태블릿] 태블릿 지원 기반(창 크기 배율·폰 비율 열) 구축`, 본문에 spec 경로와 이 계획의 Task 목록, 라벨 `작업전`.
- [ ] **Step 2:** `/pro-init-worktree`로 worktree 생성 (`develop` 최신화 후). 생성물(`build/`, `Pods/` 등) 복사 금지.
- [ ] **Step 3:** 작업 시작 라벨을 `set-labels`로 `작업중`으로 교체.

---

### Task 1: 레이아웃 토큰과 창 등급·배율 계산 (순수 함수)

**Files:**
- Create: `client/lib/core/layout/app_layout.dart`, `window_size_class.dart`, `layout_metrics.dart`
- Modify: `client/lib/core/theme/app_theme.dart:49` (extensions에 `AppLayout.standard` 추가)
- Test: `client/test/layout_metrics_test.dart`

**Interfaces:**
- Produces:
  - `class AppLayout extends ThemeExtension<AppLayout>` — `static const AppLayout standard`; double 필드 `mediumMinWidth(600) expandedMinWidth(840) shortHeightMax(480) phoneColumnWidth(393) designHeight(852) minFrameScale(0.8) maxFrameScale(1.3) contentColumnMaxWidth(560) readingMaxWidth(640) masterPaneWidth(360) paneGutter(24) sheetMaxWidth(560) dialogMaxWidth(420)`; `double pageMarginFor(WindowSizeClass sizeClass)` (compact 24 / medium 40 / expanded 56)
  - `enum WindowSizeClass { compact, medium, expanded }`
  - `class LayoutMetrics` — `factory LayoutMetrics.fromWindowSize(Size windowSize, {AppLayout layout = AppLayout.standard})`; 필드 `Size windowSize`, `WindowSizeClass sizeClass`, `bool isLandscape`, `bool isShortHeight`, `bool isScaleOverridden`, `double scale`(compact는 1.0); `Size designSizeFor(Size baseDesignSize)`; `double get phoneColumnWidthPixels`(= phoneColumnWidth × scale, 창 폭 이하로 자름)

- [ ] **Step 1: 실패하는 테스트.** `layout_metrics_test.dart`에 아래 케이스를 `test('…')`로 쓴다 (기대값은 spec 값 그대로):
  - 등급 경계: `599×1000→compact`, `600×960→medium`, `839×1000→medium`, `840×900→expanded`
  - `393×852`: compact, `isScaleOverridden == false`, `designSizeFor(Size(393,852)) == Size(393,852)`
  - `1194×834`: expanded, `isLandscape`, `scale ≈ 834/852`, `designSizeFor` 결과로 `1194/design.width ≈ 834/design.height ≈ scale`
  - `744×1133`: medium, `scale == 1.3` (상한), `phoneColumnWidthPixels ≈ 393×1.3`
  - `960×600`: expanded, `scale == 0.8` (하한), `isShortHeight == false`
  - `1024×320`: `isShortHeight == true`
  - `Size.zero`: compact, 예외 없음 (Review Focus 1)
- [ ] **Step 2:** `flutter test test/layout_metrics_test.dart` → 파일/타입 없음으로 FAIL.
- [ ] **Step 3: 구현.** 위 시그니처대로. 배율 공식·`designSizeFor`는 `Size(창폭/s, 창높이/s)`(compact는 `baseDesignSize` 그대로). `AppLayout`의 `copyWith`/`lerp`는 ThemeExtension 규약대로 작성. 토큰 옆에 값의 뜻·단위 주석.
- [ ] **Step 4:** 같은 명령 → PASS. `flutter analyze lib/core/layout lib/core/theme` 0건.
- [ ] **Step 5:** `/pro-commit` (위 Files 경로만).

---

### Task 2: P0 스파이크 — 창 크기에 따라 `.w/.h`가 같은 배율을 갖는가

**Files:**
- Create: `client/lib/core/layout/adaptive_scope.dart`, `adaptive_screen_scale.dart`, `layout_context_ext.dart`
- Test: `client/test/adaptive_screen_scale_test.dart`

**Interfaces:**
- Consumes: Task 1 `LayoutMetrics`, `AppLayout`
- Produces:
  - `class AdaptiveScope extends InheritedWidget` — `final LayoutMetrics metrics`; `static LayoutMetrics? maybeOf(BuildContext)`
  - `class AdaptiveScreenScale extends StatefulWidget` — `const AdaptiveScreenScale({required Size baseDesignSize, required Widget Function(BuildContext context, Widget? child) builder, bool minTextAdapt = true})`. `ScreenUtilInit`을 감싸고 `View.of(context)` 창 크기를 `didChangeMetrics`로 따라가 `designSize: metrics.designSizeFor(baseDesignSize)`를 넘기며, builder 결과를 `AdaptiveScope`로 감싼다.
  - `extension LayoutContextExt on BuildContext` — `AppLayout get layout`(테마, 없으면 `AppLayout.standard`), `LayoutMetrics get layoutMetrics`(스코프 없으면 `MediaQuery.sizeOf`로 계산 → **기존 156곳 테스트가 스코프 없이도 동작**), `WindowSizeClass get sizeClass`, `bool get isLandscape`

- [ ] **Step 1: 실패하는 테스트.** `tester.view.devicePixelRatio = 1.0` 고정 후 `AdaptiveScreenScale`로 앱을 띄우고 builder 안에서 `100.w`, `100.h`를 읽어 기록한다:
  - `393×852`: `100.w == 100.w(기존 ScreenUtilInit만 쓴 경우)`, `100.h`도 동일 (**compact 동치**). 같은 비교를 `430×932`, `320×568`에도 한다.
  - `1194×834`: `100.w ≈ 100.h ≈ 97.9` (같은 배율)
  - `744×1133`: `100.w ≈ 100.h ≈ 130`
  - **리사이즈**: `393×852`로 시작 → `tester.view.physicalSize = Size(1194, 834)` 후 `pump()` → 위 값으로 갱신됨 (회전·분할 재현)
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3: 구현.** 방법 M1 — `designSize`를 동적으로 넘긴다(위 Interfaces). **게이트:** 리사이즈 테스트가 통과하지 않으면 방법 M2 — 스코프 `build`에서 `ScreenUtil.configure(data: …copyWith(size: 가상크기), designSize: baseDesignSize)`를 직접 호출 — 로 바꿔 같은 테스트를 통과시킨다. 둘 다 안 되면 **여기서 멈추고** 결과(재현 로그·시도한 방법)를 사용자에게 보고한다 (spec §4.2의 `Scale` 치환안은 사전 승인된 대안이므로 새 계획을 쓴다).
- [ ] **Step 4:** 테스트 PASS. 어느 방법이 채택됐는지 `adaptive_screen_scale.dart` 클래스 주석 한 줄에 남긴다.
- [ ] **Step 5:** `/pro-commit`.

---

### Task 3: 앱 루트에 연결 + 폰 회귀 확인

**Files:**
- Modify: `client/lib/app.dart:205-209` (`ScreenUtilInit(` → `AdaptiveScreenScale(baseDesignSize: const Size(393, 852), …)`, `minTextAdapt: true`, builder 시그니처 동일)
- Test: 기존 전체 스위트 (신규 테스트 없음 — 회귀 확인이 목적)

**Interfaces:** Consumes Task 2 `AdaptiveScreenScale`. Produces: 앱 루트가 `AdaptiveScope`를 제공.

- [ ] **Step 1:** `app.dart`의 `ScreenUtilInit` 호출 한 곳을 교체. `builder` 내부(`MaterialApp.router`)는 건드리지 않는다.
- [ ] **Step 2:** `cd client && flutter test` — 전체 통과, 골든 파일 변경 0 (`git status`로 `test/goldens` 확인). 실패하면 원인이 compact 동치 깨짐이므로 Task 2로 돌아가 고친다 (골든을 갱신하지 않는다).
- [ ] **Step 3:** `flutter analyze` 0건 (기존 경고 외 신규 없음).
- [ ] **Step 4:** `/pro-commit`.

---

### Task 4: `AdaptivePageFrame` + 라우트 연결

**Files:**
- Create: `client/lib/core/layout/screen_layout_kind.dart`, `adaptive_page_frame.dart`
- Modify: `client/lib/core/router/app_transitions.dart` (`slidePage`, `fadePage`에 `ScreenLayoutKind layoutKind = ScreenLayoutKind.phoneColumn` 이름 인자 추가, `child`를 프레임으로 감싼다), `routes_child.dart` · `routes_entry.dart` · `routes_guardian.dart` · `routes_routine_flow.dart`의 `builder:` 라우트 6곳을 프레임으로 감싸기, `lib/features/guardian/presentation/widgets/home_coach_mark.dart:64` (`1.sw` → `MediaQuery.sizeOf(context).width`)
- Test: `client/test/adaptive_page_frame_test.dart`

**Interfaces:**
- Consumes: Task 1 `LayoutMetrics`, Task 2 `LayoutContextExt`
- Produces:
  - `enum ScreenLayoutKind { phoneColumn, contentColumn, adaptive }`
  - `class AdaptivePageFrame extends StatefulWidget` — `const AdaptivePageFrame({required ScreenLayoutKind kind, required Widget child})`
    - compact → 자식을 **그대로** 둔다(구조 동일)
    - `phoneColumn` · medium/expanded → 배경(`colors.background`) 전폭 + 폭 `phoneColumnWidthPixels` 가운데 열, 높이 `max(창 높이, designHeight×s)`가 창보다 크면 세로 스크롤. 열 안 `MediaQuery`는 `size`를 열 크기로, 좌우 `padding`/`viewPadding`을 0으로 덮고 `viewInsets`는 유지
    - `contentColumn` → 폭 `contentColumnMaxWidth.w` 상한 가운데, 높이 부족 시 스크롤
    - `adaptive` → 자식 그대로 (화면이 직접 구성)
    - 자식은 `GlobalKey`를 가진 `KeyedSubtree`로 감싸 **등급이 바뀌어도 상태(입력 글·스크롤)가 유지**된다

- [ ] **Step 1: 실패하는 테스트.** `adaptive_page_frame_test.dart`:
  - `1194×834`에서 `TextField`를 가진 `Scaffold` 자식: 열 폭 ≈ `393×0.979`, 열이 가운데 (`tester.getCenter`가 창 가운데 ±1), 오버플로·예외 없음
  - `393×852`: 프레임이 자식의 `RenderBox` 크기를 바꾸지 않음 (프레임 유무 비교 동일)
  - 열 안 `MediaQuery.sizeOf(context).width`가 열 폭과 같음
  - **상태 유지 (Review Focus 2):** `393×852`에서 `TextField`에 `'하늘이'` 입력 → `physicalSize`를 `800×1280`으로 변경 → 입력값이 그대로
  - **스크롤 폴백 (Review Focus 3):** `960×600`(높이 부족)에서 `Scrollable`이 존재하고, `viewInsets.bottom`을 올린 상태에서도 하단 `ElevatedButton`을 `tester.ensureVisible`로 볼 수 있음
  - `kind: adaptive`는 자식을 그대로 반환
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3: 구현.** `app_transitions.dart`의 두 헬퍼가 `child`를 `AdaptivePageFrame(kind: layoutKind, child: child)`로 감싸 **32개 pageBuilder 라우트는 수정 없이** 적용된다. `builder:` 6곳은 `AdaptivePageFrame(kind: ScreenLayoutKind.phoneColumn, child: …)`로 직접 감싼다(전환 방식은 바꾸지 않는다). 라우터 밖에서 전체 화면을 그리는 곳(`AppStatusGate` 점검/강제 업데이트 화면, `InstallationRetryApp`)도 grep으로 찾아 같은 프레임으로 감싼다.
- [ ] **Step 4:** 신규 테스트 PASS + `flutter test` 전체 PASS (골든 변화 0).
- [ ] **Step 5:** `/pro-commit`.

---

### Task 5: 시트 · 다이얼로그 · 토스트 폭 상한

**Files:**
- Modify: `client/lib/core/widgets/elum_bottom_sheet.dart` (`showElumSheet`에 `constraints: BoxConstraints(maxWidth: context.layout.sheetMaxWidth.w)`, 정렬 가운데), `elum_dialog.dart` (`ElumDialogCard` 폭 상한 `dialogMaxWidth.w`), `elum_toast.dart` (폭 상한·가운데 — 현재 구조를 읽고 같은 방식 적용)
- Test: `client/test/adaptive_overlay_width_test.dart`

**Interfaces:** Consumes `LayoutContextExt.layout`.

- [ ] **Step 1: 실패하는 테스트 (Review Focus 6).** `1366×1024`와 `1194×834`에서 `showElumSheet`로 연 시트 폭 `<= 560×s + 1`이고 가운데; `showElumDialog` 카드 폭 `<= 420×s + 1`; `393×852`에서는 시트 폭이 창 폭과 같고 다이얼로그 크기가 기존과 동일(기존 `elum_dialog` 골든 PASS).
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 구현. 기존 시그니처·반환 타입을 바꾸지 않아 호출처 7곳은 수정하지 않는다. 호출처 중 헬퍼를 거치지 않는 `showModalBottomSheet(` / `showDialog(` / `showGeneralDialog(` 직접 호출이 있으면 목록으로 보고하고, 있는 만큼 Task 6의 동결 목록에 넣는다.
- [ ] **Step 4:** 신규 + 전체 테스트 PASS.
- [ ] **Step 5:** `/pro-commit`.

---

### Task 6: 방향 정책 + 로컬 검증용 네이티브 패치

**Files:**
- Create: `client/lib/core/layout/device_kind.dart`, `orientation_policy.dart`, `client/tool/tablet_native.patch`, `client/tool/apply_tablet_native.sh`
- Modify: `client/lib/main.dart` (`runApp` 전, `WidgetsFlutterBinding.ensureInitialized()` 뒤에 방향 정책 적용)
- Test: `client/test/orientation_policy_test.dart`

**Interfaces:**
- Produces:
  - `enum DeviceKind { phone, tablet }` — `static DeviceKind fromPhysicalSize(Size logicalSize)` (짧은 변 ≥ 600 → tablet)
  - `abstract final class OrientationPolicy` — `static List<DeviceOrientation> allowedOrientationsFor(DeviceKind kind)` (phone → `[portraitUp]`, tablet → 4방향), `static Future<void> apply()` (기기 화면 크기로 `SystemChrome.setPreferredOrientations`)
  - `tool/apply_tablet_native.sh apply|revert` — `tool/tablet_native.patch`(pbxproj `TARGETED_DEVICE_FAMILY "1,2"`, `Info.plist`에 `UISupportedInterfaceOrientations~ipad` 4방향, `AndroidManifest.xml`의 `screenOrientation`을 `unspecified`로)를 `git apply` / `git apply -R`로 적용·되돌림

- [ ] **Step 1: 실패하는 테스트.** `599×1000→phone`, `600×960→tablet`; `allowedOrientationsFor(phone) == [portraitUp]`; tablet은 4방향 모두 포함.
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 구현. 정책은 **항상 동작**한다(폰은 어디서든 세로). 사용자에게 열리는 여부는 네이티브가 결정하므로 코드에 플래그를 두지 않는다. 스크립트는 패치가 이미 적용된 상태에서 `apply`를 다시 하면 아무것도 하지 않고 안내만 출력(멱등).
- [ ] **Step 4:** 테스트 PASS. `tool/apply_tablet_native.sh apply` → `git diff --stat`로 3개 파일 변경 확인 → `revert` → `git status`로 3개 파일이 원복(깨끗)됐는지 확인. **이 3개 네이티브 파일은 커밋하지 않는다.**
- [ ] **Step 5:** `/pro-commit` (Dart 파일·패치·스크립트·테스트만).

---

### Task 7: 규칙 테스트 + 태블릿 매트릭스

**Files:**
- Create: `client/test/tablet_layout_rule_test.dart`, `client/test/tablet_matrix_test.dart`, `client/test/helpers/adaptive_test_app.dart`
- Modify: `client/test/device_sizes_test.dart` 변경 없음 (참고만)

**Interfaces:**
- Produces: `Widget adaptiveTestApp({required Widget home, required Size windowSize, double textScale = 1.0})` — `AdaptiveScreenScale` + `MaterialApp(theme: AppTheme.light)`로 실제 앱 루트와 같은 구성 (단일 구성 원본). 사용 전 호출 측이 `tester.view.devicePixelRatio = 1.0`, `physicalSize` 설정.

- [ ] **Step 1: 규칙 테스트 (동결 목록 방식, `feature_raw_widget_rule_test.dart`의 `expectFrozen`과 같은 형태).** `lib/features/`와 `lib/core/`(단 `lib/core/layout/` 제외)에서 금지: `1.sw`/`1.sh`/`ScreenUtil()` 직접 호출, `MediaQuery.sizeOf(...).width`와 `600`/`840` 숫자 비교, `Platform.isIOS`/`isAndroid`로 태블릿 판별 흉내, `showModalBottomSheet(`/`showDialog(`/`showGeneralDialog(` 직접 호출. Task 5에서 발견한 직접 호출만 사유 주석과 함께 동결 목록에 둔다. 또 `routes_*.dart`의 모든 `GoRoute`가 `slidePage`/`fadePage`/`AdaptivePageFrame` 중 하나를 거치는지 검사.
- [ ] **Step 2: 실패 확인.** 규칙 테스트가 현 코드베이스에서 정확히 동결 목록과 일치하는지(추가·소멸 모두 실패 사유) 확인.
- [ ] **Step 3: 매트릭스 테스트.** 아래 창 크기 × 글자 배율(1.0, 2.0)에서 화면 4개(`GuardianHomeScreen`, `ChildHomeScreen`, `ChildStarsScreen`, `RoutineInputScreen` — `device_sizes_test.dart`와 같은 override 사용)를 `adaptiveTestApp`으로 띄워 `tester.takeException()`이 null:
  `393×852`, `744×1133`, `1133×744`, `820×1180`, `1180×820`, `1024×1366`, `1366×1024`, `800×1280`, `1280×800`, `600×960`, `960×600`, `320×1024`, `1024×320`.
  (Review Focus 4·5.) 전 화면(39개) 확장은 P2~P4 계획에서 화면을 올릴 때마다 목록에 더한다.
- [ ] **Step 4:** 테스트 PASS, 전체 스위트 PASS, `flutter analyze` 신규 0건.
- [ ] **Step 5:** `/pro-commit`.

---

### Task 8: 실기기 확인 + 문서

**Files:**
- Modify: `client/docs/design-system.md` (레이아웃 토큰·창 등급 절 추가), `client/docs/architecture.md` (`core/layout` 구조), `client/CLAUDE.md` (코딩 규칙에 "크기는 `context.layout`/`context.sizeClass`만, 화면 숫자 breakpoint 금지" 한 줄)
- Evidence: `docs/projectops/tablet/20261019_P1_검증/` 에 대표 캡처만 (최대 8장, 중복 금지)

- [ ] **Step 1:** `tool/apply_tablet_native.sh apply` 후 `/pro-launch`로 iPad Pro 13" · iPad mini 시뮬레이터와 Android 10" 태블릿 에뮬레이터에서 앱을 띄운다. raw `adb input tap` 좌표 조작 금지.
- [ ] **Step 2:** 가로·세로에서 확인하고 캡처: 로그인, 보호자 홈, 일과 만들기 입력, 이룸이 홈, 카드 상세, 시트 하나, 다이얼로그 하나, 회전 중 입력 유지. 확인 기준: 폰 비율 열이 가운데, CTA가 보이고, 오버플로·잘림 없음, 회전해도 입력한 글 유지.
- [ ] **Step 3:** `tool/apply_tablet_native.sh revert` → `git status`에서 네이티브 3개 파일 변경 없음 확인.
- [ ] **Step 4:** 문서 3곳 수정, 폰 시뮬레이터에서 보호자 홈·이룸이 홈이 이전과 같은 모습인지 1장씩 확인.
- [ ] **Step 5:** `/pro-commit`. 이후 `/pro-report`로 이슈에 보고서, 남은 일(P2~P5)을 체크리스트로 남기고 이슈는 **닫지 않는다**(`작업중` 유지, 상위 이슈 성격).

---

## Self-Review (작성 시 확인)

- Spec 커버: §4.1 등급(T1) · §4.2 배율(T1·T2·T3) · §4.3 종류(T4) · §4.4 토큰(T1) · §4.5 방향(T6) · §4.6 오버레이(T5) · §9 규칙·매트릭스·실기(T7·T8). §4.7 애니메이션, §5 화면 설계, §8 문구, 광고·공유는 P2~P4 범위 밖으로 명시.
- 이름 일관: `AppLayout` · `WindowSizeClass` · `LayoutMetrics`(`fromWindowSize`, `designSizeFor`, `phoneColumnWidthPixels`) · `AdaptiveScope` · `AdaptiveScreenScale` · `ScreenLayoutKind` · `AdaptivePageFrame` · `DeviceKind` · `OrientationPolicy` — 모든 Task에서 동일.
- 알려진 위험: Task 2가 막히면 전체 계획이 바뀐다(게이트 명시). 라우터 밖 전체 화면 목록은 구현 시 grep으로 확정.
