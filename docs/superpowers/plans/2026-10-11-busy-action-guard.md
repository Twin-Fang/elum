# 서버 요청 버튼 진행 중 표시·중복 방지 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 누르면 서버로 가는 동작을 누르는 즉시 잠그고 진행 중임을 보여주며, 같은 요청은 한 번만 보낸다.

**Architecture:** core 에 공통 부품 4개(`SingleFlight`·`BusyStateMixin`·`ElumButton.loading`·`SettingsTile.loading`)와
팝업 버튼 1회 닫기를 두고, 각 화면의 손으로 만든 플래그를 이것으로 바꾼다.

**Tech Stack:** Flutter, Riverpod 3, flutter_test

**Spec:** `docs/superpowers/specs/2026-10-11-busy-action-guard-design.md`

## Global Constraints

- 서버 API·저장 키·에러 코드는 바꾸지 않는다 (운영 중인 앱).
- 스피너 표준: `ElumSpinner(size: 22.w, color: colors.buttonDisabledText)`, 버튼 오른쪽 안쪽 여백 `24.w`.
- 예외를 삼키지 않는다. 화면의 기존 `showFailure`(에러 코드 포함)가 그대로 받는다.
- 주석은 로직의 이유만, 이슈 번호·과거 경위 없이 짧게.
- 화면 문구 새로 만들지 않는다 (l10n 키 추가 없음).
- 병렬 작업자는 시험을 돌리지 않는다(analyze 만). 전체 시험은 마지막 1회.

## Review Focus

- 진행 중 화면이 닫힘(뒤로가기·성공 후 이동) → `setState` 예외가 나지 않아야 한다 → Task 2 시험.
- 실패 뒤 다시 누름 → 잠금이 풀려 다시 실행돼야 한다 → Task 1·2 시험.
- 목록 항목별 잠금: A 삭제 중 B 삭제는 막지 않는다(서로 다른 key) → Task 2 시험.
- 팝업 버튼 연타 → 팝업만 닫히고 아래 화면은 남아야 한다 → Task 4 시험.
- 카드확인 저장 연타 → `confirm` 1번, 실패 팝업 없음 → Task 5 시험.

---

### Task 1: `SingleFlight<T>`

**Files:** Create `client/lib/core/state/single_flight.dart`, Test `client/test/single_flight_test.dart`

**Produces:** `class SingleFlight<T> { bool get running; Future<T> run(Future<T> Function() task); }`

- [ ] 실패하는 시험: 동시에 2번 run → task 1번 실행, 같은 결과 / 실패 뒤 다시 run → 새로 실행 / 동기 throw 도 Future 에러로.
- [ ] 구현:

```dart
class SingleFlight<T> {
  Future<T>? _running;
  bool get running => _running != null;

  Future<T> run(Future<T> Function() task) {
    final running = _running;
    if (running != null) return running;
    final future = Future<T>.sync(task);
    _running = future;
    future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    }).ignore();
    return future;
  }
}
```

- [ ] 시험 통과 확인.

### Task 2: `BusyStateMixin`

**Files:** Create `client/lib/core/state/busy_state_mixin.dart`, Test `client/test/busy_state_mixin_test.dart`

**Produces:** `mixin BusyStateMixin<T extends StatefulWidget> on State<T> { bool get busy; bool isBusy(Object key); Future<R?> runBusy<R>(Future<R> Function() task, {Object? key}); }`

규칙: key 없으면 화면 전체 잠금. 전체 잠금 중엔 무엇도 시작하지 않고, 항목 잠금 중엔 같은 key 와 전체만 막는다.

- [ ] 실패하는 시험: 진행 중 재호출 → null·task 1번 / 실패해도 해제·에러 전파 / dispose 뒤 완료 → 예외 없음 / key 다르면 동시 실행.
- [ ] 구현:

```dart
mixin BusyStateMixin<T extends StatefulWidget> on State<T> {
  static const Object _screen = Object();
  final Set<Object> _busyKeys = {};

  bool get busy => _busyKeys.isNotEmpty;
  bool isBusy(Object key) => _busyKeys.contains(key);

  Future<R?> runBusy<R>(Future<R> Function() task, {Object? key}) async {
    final k = key ?? _screen;
    final blocked = _busyKeys.contains(_screen) ||
        _busyKeys.contains(k) ||
        (k == _screen && busy);
    if (blocked || !mounted) return null;
    setState(() => _busyKeys.add(k));
    try {
      return await task();
    } finally {
      if (mounted) {
        setState(() => _busyKeys.remove(k));
      } else {
        _busyKeys.remove(k);
      }
    }
  }
}
```

### Task 3: `ElumButton.loading` · `SettingsTile.loading`

**Files:** Modify `client/lib/core/widgets/elum_button.dart`, `client/lib/core/widgets/settings_tile.dart`, `client/lib/features/feedback/presentation/feedback_screen.dart`(`_SendButton` 제거), Test `client/test/elum_button_loading_test.dart`

- [ ] 시험: `loading: true` → 탭해도 콜백 0번, `ElumSpinner` 1개 / false → 콜백 1번, 스피너 없음. `SettingsTile(loading: true)` → 화살표 대신 스피너, 탭 무시.
- [ ] `ElumButton`: `final bool loading;`(기본 false). `onTap: loading ? null : onPressed`, 비활성 색, `Stack(alignment: centerRight)` 에 스피너.
- [ ] `SettingsTile`: `final bool loading;`. 켜지면 값·화살표 자리에 `ElumSpinner(size: 20.w, color: colors.settingsChevron)`, `onTap` 무시.
- [ ] 의견 보내기 `_SendButton` → `ElumButton(loading: sending)` 로 교체.

### Task 4: 팝업 버튼 한 번만 닫기 — 취소 (닫히는 중 팝업은 이미 터치를 받지 않음을 시험으로 확인)

**Files:** Modify `client/lib/core/widgets/elum_dialog.dart:220`, Test `client/test/elum_dialog_double_tap_test.dart`

- [ ] 시험: 화면 A → push B → B 에서 팝업 → 확인 두 번 탭 → B 는 남아 있다.
- [ ] 구현: `onTap` 에서 `ModalRoute.of(context)?.isCurrent == false` 면 return, 아니면 pop.

### Task 5: 카드확인 저장하기 (위험도 높음)

**Files:** Modify `routine_notifier.dart` `save()`, `card_review_screen.dart` `_save`·버튼, Test `card_review_save_test.dart`

- [ ] 시험: `save()` 두 번 동시 → `confirmCalls == 1`, 두 결과 모두 null.
- [ ] notifier: `final _saving = SingleFlight<AppFailure?>();` → `save() => _saving.run(_save)` (본문은 `_save` 로 이름만 옮김).
- [ ] 화면: `BusyStateMixin`, `_save` 를 `runBusy` 로 감싸고 `ElumButton(loading: busy)`.

### Task 6: 나머지 화면 연결

스펙 §4 표의 나머지 곳. 손으로 만든 `_busy`·`_saving`·`_deletingId` 를 `BusyStateMixin` 으로 바꾸고,
`ElumButton(loading:)`/`SettingsTile(loading:)`/항목 스피너를 연결한다. 각 곳 기존 시험이 쓰는 플래그 이름이 있으면 함께 고친다.

| 묶음 | 파일 |
|---|---|
| A 보호자 홈·일과 | `today_routine_section.dart`(삭제 key=일과 id, 스와이프 잠금+스피너), `draft_routines_screen.dart`, `guardian_home_screen.dart`(`_startRoutine`), `card_edit_sheet.dart` |
| B 설정·계정 | `guardian_settings_screen.dart`, `image_style_settings_screen.dart`, `pin_change_screen.dart`, `consent_screen.dart`(`_leave`), `elumi_settings_screen.dart` |
| C 온보딩·연결·프로필 | `onboarding/.../pin_screen.dart`, `link_status_screen.dart`, `guardians_screen.dart`, `profile_switch_screen.dart` |

- [ ] 묶음마다 `flutter analyze` 0건.

### Task 7: 검증·커밋

- [ ] `flutter analyze` 0건, `flutter test` 전체 1회.
- [ ] iOS 시뮬레이터: 카드확인 저장하기 연타 → 팝업 없음·스피너 보임.
- [ ] `/pro-commit`.
