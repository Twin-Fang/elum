# 일과관리 코치마크 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 일과관리 칸 첫 진입 때 누르기 · 길게 누르기 · 보낸 뒤 ✓ · 묶음 만들기를 시범 연출로 안내한다.

**Architecture:** 홈 코치마크의 `CoachMarkOverlay` / `CoachMarkStep` 을 그대로 쓰고, 단계에 `demoBuilder`(시범 층) 한 칸만 더한다. 시작 조건·진행·"봤음" 저장은 `HomeCoachNotifier` 와 같은 규칙의 `RoutineManageCoachNotifier` 가 맡는다. 시범은 오버레이 안에서만 그리고 서버·일과 데이터를 건드리지 않는다.

**Tech Stack:** Flutter, Riverpod(`Notifier`), flutter_screenutil, `AppMotion`(client/docs/motion.md), ARB l10n.

**Spec:** `docs/superpowers/specs/2026-10-19-routine-manage-coach-mark-design.md` (이슈 #832)

## Global Constraints

- 구현은 worktree `…-Worktree/20261019_832_…` 의 `client/` 에서만. `main` 직접 커밋 금지, push 는 사용자가 요청할 때만, 커밋은 `/pro-commit`, 커밋 메시지에 Co-Authored-By 금지
- 새 오버레이·Lottie·외부 패키지 금지. 시간·곡선은 `AppMotion` 만 (`copyWith(fontSize:)`, 색·간격 하드코딩 금지: `context.colors` / `context.space` / `context.typo`)
- 문구는 `lib/l10n/app_ko.arb` 에만 추가 후 `cd client && flutter gen-l10n`, 생성 파일 함께 커밋, `dart run tool/check_hangul_literals.dart lib` 0줄
- 해요체, 용어 `이룸이` `일과` `묶음`, `아이` 금지. 보여주는 문구는 시안 문구를 그대로 쓴다 (아래 Task 4 표)
- 화면 위젯은 `ConsumerWidget` 우선, 파일 300줄 초과 금지, 창 크기는 `context.sizeClass` 로만 읽음
- 저장을 못 읽으면 "봤다"고 친다. 같은 실행에서 두 번 뜨지 않는다 (`_shownThisRun`)
- 시범 중 서버 호출 0건. 시범 층은 `ExcludeSemantics` 가 아니라 낭독 문구를 말풍선이 담당

## Review Focus

1. 코치마크가 떠 있는 동안 목록이 새로고침돼 대상 칸이 사라지거나 순서가 바뀜 → 그 단계는 건너뛰고 앱은 안 죽는다 (Task 4)
2. 태블릿 넓은 격자·가로 모드·글자 크기 최대에서 막이 화면 전체를 덮고 말풍선이 잘리지 않는다 (Task 4)
3. 첫 칸이 일과가 아니라 묶음일 때 "첫 일과 칸"을 가리킨다 (묶음 칸을 가리키지 않는다) (Task 4)
4. 뒤로가기·✕·마지막 탭 어느 쪽으로 닫아도 "봤음"이 저장되고 다시 안 뜬다 (Task 1)
5. 동작 줄이기를 켠 사람은 움직임 없이 정지 그림 + 문구만 본다 (Task 3)

---

## File Structure

| 파일 | 책임 |
|---|---|
| Modify `lib/core/storage/local_storage.dart`, `shared_prefs_storage.dart`, `in_memory_storage.dart` | 봤음 2개 키 (`coach.manageSeen`, `coach.groupSeen`) |
| Create `lib/features/guardian/application/routine_manage_coach_notifier.dart` | 단계 enum · 상태 · 시작 조건 · 진행 · 저장 · 다시 보기 |
| Modify `lib/core/widgets/coach_mark_step.dart`, `coach_mark_overlay.dart` | `demoBuilder` 한 칸 추가와 그리기 |
| Create `lib/features/guardian/presentation/widgets/coach_demo_layers.dart` | 손가락 · 링 · 시트 미리보기 · ✓ 팝 · 끌어서 묶기 연출 |
| Create `lib/features/guardian/presentation/widgets/routine_manage_coach_mark.dart` | 단계를 키 · 글 · 시범에 연결해 오버레이 마운트 |
| Modify `lib/features/guardian/presentation/routine_manage_screen.dart`, `widgets/library_entry_grid.dart` | 대상 `GlobalKey` 연결, 시작 호출 |
| Modify `lib/features/guardian/presentation/guardian_settings_screen.dart` | 사용법 다시 보기 줄 |
| Modify `lib/l10n/app_ko.arb` (+ 생성 파일) | 문구 |
| Test `test/routine_manage_coach_test.dart` (새 파일) | 노티파이어 · 마운트 · 실패 경로 |

---

### Task 1: 봤음 저장 + 코치 노티파이어

**Files:** 위 storage 3개, Create `routine_manage_coach_notifier.dart`, Test `test/routine_manage_coach_test.dart`

**Interfaces:**
- Produces:
  - `LocalStorage`: `bool get isManageCoachSeen` · `Future<void> setManageCoachSeen(bool v)` · `bool get isGroupCoachSeen` · `Future<void> setGroupCoachSeen(bool v)` (`InMemoryStorage` 생성자에 `manageCoachSeen = true`, `groupCoachSeen = true` 기본값)
  - `enum RoutineManageCoachStep { tapRoutine, longPressRoutine, sentBadge, dragToGroup, createGroup }`
  - `class RoutineManageCoachState { const RoutineManageCoachState({this.steps = const [], this.index = 0}); final List<RoutineManageCoachStep> steps; final int index; bool get active; RoutineManageCoachStep? get current; }`
  - `final routineManageCoachProvider = NotifierProvider<RoutineManageCoachNotifier, RoutineManageCoachState>(...)`
  - `bool maybeStart({required int routineCount, required int groupCount, required bool hasFirstRoutineTile})`, `void next()`, `Future<void> finish()`, `void replay({required int routineCount, required int groupCount})`

- [ ] **Step 1: 실패하는 테스트** — `home_coach_test.dart` · `home_coach_storage_test.dart` 의 컨테이너/오버라이드 방식을 그대로 따라 다음을 쓴다
  - `routineCount: 0` → `maybeStart` false, 상태 꺼짐 ("목록 0건에서 안 뜬다")
  - `routineCount: 1, groupCount: 0` → steps = `[tapRoutine, longPressRoutine, sentBadge]`
  - `routineCount: 2, groupCount: 0` → steps 에 `dragToGroup, createGroup` 이 이어 붙는다
  - `routineCount: 2, groupCount: 1` → 묶음 단계 없음
  - `hasFirstRoutineTile: false` → 시작 안 함 (첫 칸이 묶음뿐)
  - 두 번째 `maybeStart` 는 false (`_shownThisRun`), `finish()` 후 저장소 `isManageCoachSeen == true`, 묶음 단계가 있었으면 `isGroupCoachSeen == true`
  - 저장소 읽기가 던지면 `maybeStart` false
  - `replay(...)` 는 봤음이어도 켜지고, 끝내도 봤음 값을 바꾸지 않아도 된다 (이미 true)
- [ ] **Step 2: 실패 확인** — `cd client && flutter test test/routine_manage_coach_test.dart` → FAIL (정의 없음)
- [ ] **Step 3: 구현** — 위 시그니처대로. 시작 조건은 `homeCoachProvider` 와 같은 구조 (읽기 실패 시 봤다고 침, `AppLogger.notifierCall`). 묶음 단계는 `routineCount >= 2 && groupCount == 0 && !isGroupCoachSeen` 일 때만 붙인다. `finish()` 는 포함된 묶음에 해당하는 키만 저장하고 쓰기 실패는 `AppLogger.error` 로 삼킨다
- [ ] **Step 4: 통과 확인** — 같은 명령 → PASS
- [ ] **Step 5: 커밋** — `/pro-commit` (storage 3개 + notifier + test)

### Task 2: 단계에 시범 층 한 칸

**Files:** Modify `coach_mark_step.dart`, `coach_mark_overlay.dart`; Test `test/routine_manage_coach_test.dart`

**Interfaces:**
- Produces: `CoachMarkStep({... Widget Function(BuildContext context, Rect targetRect)? demoBuilder})` — 구멍 위, 말풍선 아래 층에 그려진다. null 이면 지금과 똑같이 동작한다

- [ ] **Step 1: 테스트** — `CoachMarkOverlay` 를 단계 하나(demoBuilder 가 `Key('demo')` 위젯을 돌려줌)로 띄우면 `find.byKey(Key('demo'))` 가 1개. demoBuilder 가 null 인 기존 단계는 영향 없음 (기존 `home_coach_test.dart` 가 그대로 통과)
- [ ] **Step 2: 실패 확인** → FAIL
- [ ] **Step 3: 구현** — 오버레이의 구멍 그리는 곳 위에 `demoBuilder?.call(context, holeRect)` 를 `IgnorePointer` 로 얹는다. 구멍이 이동하는 동안(`_move` < 1)은 그리지 않는다
- [ ] **Step 4: 통과 확인** + `flutter test test/home_coach_test.dart test/coach_scrim_side_bleed_test.dart`
- [ ] **Step 5: 커밋**

### Task 3: 시범 연출 위젯

**Files:** Create `coach_demo_layers.dart`; Test `test/routine_manage_coach_test.dart`

**Interfaces:**
- Produces: `Widget tapDemo(BuildContext, Rect target)`, `longPressDemo`, `sentBadgeDemo`, `dragToGroupDemo(BuildContext, Rect firstTile, Rect secondTile)`, `createGroupDemo(BuildContext, Rect createButton)` — 모두 `Widget Function(BuildContext, Rect)` 형태로 쓸 수 있게 클로저로 감싼다
- 길이: 탭 4s, 꾹 3.6s, ✓ 4s, 끌기 5s 루프 (시안 값). 지속시간은 `AppMotion` 상수로 정의하고 없는 값은 `app_motion.dart` 에 이름 붙여 추가

- [ ] **Step 1: 테스트** — `MediaQuery(disableAnimations: true)` 에서 각 데모가 `AnimationController` 를 돌리지 않고(`tester.pumpAndSettle` 이 끝남) 정지 그림만 그린다. 일반 모드에서는 `pump(1s)` 후에도 예외가 없다. 시범 시트 미리보기는 `LibraryRoutineTile` / 실제 시트 버튼 위젯을 재사용해 `routineLibrarySendToday` · `routineLibraryEditCards` 문구가 보인다
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — 손가락(흰 원, 눌림 때 .82 배), 링(퍼지며 사라짐), 시트 미리보기(아래에서 올라옴: 실제 `_LibraryActions` 가 private 이면 공개 위젯으로 승격해 재사용), ✓ 팝은 `LibrarySentBadge(size:)` 재사용, 끌어서 묶기는 첫 칸 복제본이 둘째 칸 위로 이동하며 줄어들고 2×2 묶음 칸(`LibraryGroupTile` 재사용)이 나타난다. 동작 줄이기는 마지막 장면 한 컷
- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: 커밋**

### Task 4: 기본 3단계 연결

**Files:** Create `routine_manage_coach_mark.dart`; Modify `routine_manage_screen.dart`, `library_entry_grid.dart`, `app_ko.arb`; Test `test/routine_manage_coach_test.dart`, 기존 `test/routine_manage_screen_test.dart` 로 회귀 확인

**Interfaces:**
- Consumes: Task 1 노티파이어, Task 2 `demoBuilder`, Task 3 데모
- Produces: `LibraryEntryGrid({... GlobalKey? firstRoutineTileKey, GlobalKey? secondRoutineTileKey})` — 항목 중 **일과인 첫·둘째** 칸에 키를 단다 (묶음 칸 제외). `RoutineManageCoachMark({required GlobalKey firstRoutineTileKey, required GlobalKey secondRoutineTileKey, required GlobalKey createButtonKey})`
- 문구 (ARB 키 → 값):

| 키 | 값 |
|---|---|
| `routineManageCoachTapMessage` | 일과를 *누르면* 카드를 볼 수 있어요. 카드 고치기와 오늘 보내기를 할 수 있어요 |
| `routineManageCoachLongPressMessage` | *길게 누르면* 메뉴가 열려요. 오늘 보내기 · 이름 바꾸기 · 복사하기 · 지우기 |
| `routineManageCoachSentMessage` | 오늘 보낸 일과에는 *✓* 가 붙어요. 홈의 오늘 일과에 들어가고, 여기 일과는 그대로 남아요 |

- [ ] **Step 1: 테스트** (위젯, `routine_manage_screen_test.dart` 의 가짜 provider 방식)
  - 일과 1개 + 봤음 false → 코치마크가 뜨고 말풍선에 Tap 문구, 탭하면 LongPress → Sent → 닫힘
  - 로딩 중 · 실패 · 0건에서는 안 뜬다
  - 첫 항목이 묶음이어도 가리키는 칸은 첫 **일과** 칸 (Review Focus 3)
  - 단계 도중 목록을 비우면(대상 사라짐) 예외 없이 건너뛴다 (Review Focus 1)
  - 태블릿 폭(1024×768) · 글자 크기 2.0 에서 예외 없고 막이 화면 전체를 덮는다 (Review Focus 2, `coach_scrim_side_bleed_test.dart` 방식)
  - 뒤로가기로 닫고 다시 열면 안 뜬다 (Review Focus 4)
  - 코치마크가 도는 동안 `routineLibraryApi` 가짜의 호출 횟수는 시작 전 그대로 (서버 호출 0)
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현**
  - ARB 3개 키 추가 후 `flutter gen-l10n`
  - 화면에서 `routineLibraryProvider` 가 `AsyncValue(:final value?)` 이고 비어 있지 않을 때, 첫 프레임 뒤(`addPostFrameCallback`)에 `maybeStart(routineCount: …, groupCount: ref.read(routineGroupsProvider).value?.length ?? 0, hasFirstRoutineTile: …)` 를 호출한다. `RoutineManageCoachMark` 는 화면 `Stack` 맨 위에 얹는다 (홈이 `HomeCoachMark` 를 얹는 방식과 같다)
  - 1단계 target = `firstRoutineTileKey`, 시범 = `tapDemo`; 2단계 같은 칸 + `longPressDemo`; 3단계 같은 칸 + `sentBadgeDemo`
- [ ] **Step 4: 통과 확인** — `flutter test test/routine_manage_coach_test.dart test/routine_manage_screen_test.dart test/home_coach_test.dart`
- [ ] **Step 5: 커밋**

### Task 5: 묶음 2단계 연결

**Files:** Modify `routine_manage_coach_mark.dart`, `app_ko.arb`; Test `test/routine_manage_coach_test.dart`

**Interfaces:** 문구

| 키 | 값 |
|---|---|
| `routineManageCoachDragMessage` | 일과를 *꾹 눌러* 다른 일과 위에 놓으면 묶음이 돼요. 묶음 위에 놓으면 그 묶음에 들어가고, 묶음을 보내면 안 일과가 순서대로 한꺼번에 가요 |
| `routineManageCoachCreateGroupMessage` | 끌기가 어려우면 *+ 일과 만들기* 에서도 묶을 수 있어요 |

- [ ] **Step 1: 테스트** — 일과 2개 + 묶음 0개 + 묶음 봤음 false → 기본 3단계 뒤에 Drag, CreateGroup 이 이어서 뜬다. 일과 2개 + 묶음 1개 → 안 뜬다. 일과 1개 → 안 뜬다. 끝내면 `isGroupCoachSeen == true`. 묶음 단계의 target 은 각각 첫 일과 칸(+ `secondRoutineTileKey`), `createButtonKey`
- [ ] **Step 2: 실패 확인** → **Step 3: 구현** (`dragToGroupDemo(first, second)`, `createGroupDemo`) → **Step 4: 통과** → **Step 5: 커밋**

### Task 6: 사용법 다시 보기

**Files:** Modify `guardian_settings_screen.dart`, `app_ko.arb`; Test `test/guardian_settings_test.dart` (기존 파일에 케이스 추가)

**Interfaces:** ARB `guardianSettingsRoutineManageGuide` = `일과관리 사용법 다시 보기`. 줄을 누르면 일과관리 칸으로 이동한 뒤 `replay(...)` 가 불린다 (이동 방법은 `guardianSettingsFeedback` 줄이 다른 화면으로 가는 방식과 하단 바 칸 전환 코드를 따른다)

- [ ] **Step 1: 테스트** — 줄이 보이고, 누르면 일과관리 칸이 열린다. 봤음이어도 코치마크가 뜬다
- [ ] **Step 2~5:** 실패 확인 → 구현(`replay` 를 일과관리 화면이 읽는 `pendingReplay` 신호로 전달하거나, 이동 뒤 호출) → 통과 → 커밋

### Task 7: 실측 검증과 마무리

- [ ] **Step 1:** `flutter analyze` 0건, `dart run tool/check_hangul_literals.dart lib` 0줄, `flutter test --exclude-tags golden` 전체 통과
- [ ] **Step 2:** `/pro-launch` 로 시뮬레이터(아이폰 · 아이패드, 라이트 · 다크)에서 일과 1개 / 2개 / 묶음 있음 / 0개 / 목록 실패 상태를 직접 띄워 캡처. 단계마다 시범이 시안(`coachmark-existing-v3`, `coachmark-group-v4`)과 같은지 눈으로 확인
- [ ] **Step 3:** 이슈에 `@projectops app build <브랜치명>` 댓글 (브랜치를 원격에 먼저 올려야 하므로 push 는 사용자 요청 후), `/pro-report` 로 완료 보고서, 라벨 `작업완료` + 이슈 닫기

## Self-Review

- 스펙 4~6장: 단계 5개(Task 3~5) · 저장 키 2개(Task 1) · 다시 보기(Task 6) · 실패 경로 표(Task 4 테스트) · 테스트 표(Task 1·4) 모두 대응
- 타입: `RoutineManageCoachStep` 값 5개가 Task 1 정의와 Task 4·5 에서 동일, `demoBuilder` 시그니처는 Task 2 와 Task 3 이 같은 `Widget Function(BuildContext, Rect)`
- 열려 있는 가정(실행 전 확인): ① `_LibraryActions` · 메뉴 행이 private 라 Task 3 에서 공개 승격이 필요할 수 있다 ② Task 6 의 "일과관리 칸으로 이동 후 replay" 전달 방식은 하단 바 구조를 읽고 정한다
