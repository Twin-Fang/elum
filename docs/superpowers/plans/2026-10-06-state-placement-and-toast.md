# 실패·빈 상태 위치 통일과 토스트 공통 호출 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 실패·빈 상태·로딩이 화면마다 다른 자리에 놓이는 것을 규칙 두 개로 묶고, 토스트를 한 함수로 띄운다.

**Architecture:** 본문 전체 상태는 새 공통 위젯 `ElumStateBody`(남는 높이의 세로 가운데, 넘치면 스크롤)로 감싼다. 구역 상태는 각 화면이 이미 가진 칸·여백을 로딩과 함께 쓰게 맞춘다. 토스트는 `showElumToast` 하나가 루트 messenger 를 안전하게 잡아 앞 것을 지우고 띄운다.

**Tech Stack:** Flutter, Riverpod, flutter_screenutil, flutter_test

**Spec:** `docs/superpowers/specs/2026-10-06-state-placement-and-toast-design.md` (이슈 #574)

## Global Constraints

- 문구·색·그림·`snackBarTheme` 값은 바꾸지 않는다.
- 이룸이 홈 실패/빈 상태는 건드리지 않는다.
- 새 화면 문구를 만들지 않는다 (ARB 추가 없음).
- 주석은 로직 WHY 만, 이슈 번호·경위 없이 짧게.
- `!` 강제 언랩 금지, 예외를 삼키지 않는다 (삼킬 땐 로그).

## Review Focus

1. 글자 크기 2.0 — `ElumStateBody` 안 내용이 높이를 넘으면 잘리지 않고 스크롤돼야 한다 → Task 1 테스트.
2. 높이 제한 없는 부모(스크롤 안)에 `ElumStateBody` 를 넣어도 예외가 나지 않아야 한다 → Task 1 테스트.
3. 토스트를 연달아 두 번 부르면 마지막 하나만 보여야 한다 → Task 2 테스트.
4. messenger 가 없는 context 에서 토스트를 불러도 예외가 없어야 한다 → Task 2 테스트.
5. 연결 상태 로딩 → 실패 전환 때 내용 중심이 같은 자리 → Task 3 테스트.

---

### Task 1: `ElumStateBody` 공통 배치 위젯

**Files:**
- Create: `client/lib/core/widgets/elum_state_body.dart`
- Test: `client/test/elum_state_body_test.dart`

**Interfaces:**
- Produces: `ElumStateBody({Key? key, required Widget child})`, `ElumStateBody.loading({Key? key})`

- [ ] Step 1: 테스트 — (a) 400 높이 부모에서 child 중심 y == 200, (b) child 가 높이보다 크면 `Scrollable` 이 있고 overflow 예외 없음, (c) `SingleChildScrollView` 안(높이 무한)에서도 예외 없음, (d) `.loading()` 이 `CircularProgressIndicator` 를 같은 중심에 둔다.
- [ ] Step 2: 실패 확인 `flutter test test/elum_state_body_test.dart`
- [ ] Step 3: 구현

```dart
class ElumStateBody extends StatelessWidget {
  const ElumStateBody({super.key, required this.child});
  const ElumStateBody.loading({super.key})
      : child = const CircularProgressIndicator();

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 높이를 모르는 자리(바깥이 스크롤)면 가운데를 잡을 기준이 없다 — 그냥 둔다.
        if (!constraints.hasBoundedHeight) return Center(child: child);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
```

- [ ] Step 4: 통과 확인, 커밋

### Task 2: `showElumToast` 와 7곳 교체

**Files:**
- Create: `client/lib/core/widgets/elum_toast.dart`
- Modify: `link_status_screen.dart:96`, `profile_switch_screen.dart:48`, `invite_enter_screen.dart:261`, `guardians_screen.dart:118`, `pin_change_screen.dart:185`, `image_style_settings_screen.dart:66`, `today_routine_section.dart:467`
- Test: `client/test/elum_toast_test.dart`

**Interfaces:**
- Produces: `void showElumToast(BuildContext context, String message)`, `void showElumToastOn(ScaffoldMessengerState? messenger, String message)`

- [ ] Step 1: 테스트 — 연달아 두 번 → 프레임 진행 뒤 `find.byType(SnackBar)` 1개이고 두 번째 문구, messenger 없는 트리(`WidgetsApp` 만)에서 호출해도 예외 없음, `SnackBar.behavior == null`(테마 따름).
- [ ] Step 2: 실패 확인
- [ ] Step 3: 구현

```dart
void showElumToast(BuildContext context, String message) =>
    showElumToastOn(ScaffoldMessenger.maybeOf(context), message);

void showElumToastOn(ScaffoldMessengerState? messenger, String message) {
  if (messenger == null) {
    debugPrint('[화면] 토스트를 띄울 자리가 없어 건너뜀: $message');
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
```

화면을 옮기기 전에 messenger 를 잡던 곳은 `final messenger = ScaffoldMessenger.maybeOf(context);` 로 바꾸고 이동 뒤 `showElumToastOn(messenger, text)`.
- [ ] Step 4: 7곳 교체, `grep -rn "showSnackBar" lib` 가 `elum_toast.dart`·`dev_tools_overlay.dart` 만 남는지 확인, 관련 테스트 통과, 커밋

### Task 3: 본문 전체 상태에 `ElumStateBody` 적용

**Files:**
- Modify: `link_status_screen.dart` (build, `_failed`, `_empty`, `_loaded`), `profile_switch_screen.dart` (build, `_content`), `draft_routines_screen.dart` (loading/error/empty 분기)
- Test: `client/test/state_placement_test.dart`

- 연결 상태: `status.when` 결과가 로딩/실패/빈 상태면 `ElumStateBody`, 기기가 있을 때만 `SingleChildScrollView(Column[SizedBox(40.h), _loaded])`. `_failed`·`_empty` 의 `Padding(top: 80.h)` 와 로딩의 `Padding(top: 120.h)` 를 없앤다.
- 이룸이 바꾸기: 실패·로딩·0건이면 `ElumStateBody`, 목록일 때만 `SingleChildScrollView(Padding(top: 40.h))`.
- 임시저장: `Expanded` 안 loading/error/empty 를 `ElumStateBody` 로 감싼다(위치는 지금도 가운데 — 큰 글자 스크롤만 얻는다).

- [ ] Step 1: 테스트 — 연결 상태 화면을 로딩 상태로 띄워 스피너 중심 y 를 재고, 실패로 바꿔 실패 위젯 중심 y 가 같은지(±1). 이룸이 바꾸기도 같은 방식.
- [ ] Step 2: 실패 확인 → Step 3: 구현 → Step 4: 통과, 기존 `link_status*`·`profile_switch*`·`draft*` 테스트 통과, 커밋

### Task 4: 카드 생성 실패를 `ElumErrorView` 로

**Files:**
- Modify: `client/lib/core/widgets/elum_error_view.dart` (`actionLabel` 인자 추가), `routine_loading_screen.dart` (`_GenerateError` 삭제)

- `ElumErrorView` 에 `final String? actionLabel;` — 전체 모드 버튼 글자 `actionLabel ?? context.l10n.commonRetry`.
- 실패 분기: `ElumStateBody(child: ElumErrorView(message: title, description: 서버문구 ?? hint, errorCode: flow.errorCode, onRetry: retry 가능 ? () => _retry() : () => context.go(Routes.guardian), actionLabel: retry 가능 ? routineLoadingRetry : routineLoadingHome))`.

- [ ] Step 1: 기존 카드 생성 실패 테스트(`grep -rln "routineLoadingGenerateFailed\|다시 하기" test`) 실행해 기준 확보
- [ ] Step 2: 구현 → 같은 테스트 통과(문구·버튼·코드 동일), 커밋

### Task 5: 구역 상태 맞추기

**Files:**
- Modify: `today_routine_section.dart:308` (오늘 일과 실패를 `_GreyTileShell(height: _errorShellHeight)` 안으로), `guardians_screen.dart` (실패·빈 상태 compact 를 `_Loading` 과 같은 `Padding(vertical: 24.h)` 로)

- [ ] Step 1: 테스트 — 오늘 일과 실패 위젯이 `routineTileBg` 색 상자 안에 있다.
- [ ] Step 2: 구현 → 통과, 보호자 홈 골든·figma_conformance 결과 확인(깨지면 실패 상태 골든만 의도된 변경인지 보고 갱신), 커밋

### Task 6: 전체 검증과 시뮬레이터 실측

- [ ] `flutter analyze` 0건, `flutter test` 전체
- [ ] 이 작업 전용 iOS 시뮬레이터에서 토스트 7곳을 밟아 기본 모양이 나오는 곳이 있는지 캡처로 확인. 있으면 원인을 고치고 테스트를 더한다
- [ ] 오프라인으로 연결 상태·이룸이 바꾸기·임시저장 실패 위치 캡처
