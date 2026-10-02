# 화면 이동 막다른 길 재발 방지 Implementation Plan (#548)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 어떤 화면에서도 빠져나갈 길을 잃지 않게 하고, 그런 결함을 `flutter test` 가 자동으로 잡게 한다.

**Architecture:** "지금 상태의 홈"·"뒤로가기"·"계정 로컬 정리"·"세션 만료 처리"를 각각 한 곳으로 모은다(공통화). 그 위에 상태 조합 전수 검사(순수 함수)와 나가는 경로 표 테스트(실제 `createRouter`)를 얹고, 인자 없는 `context.pop()` 을 소스 검사로 막는다.

**Tech Stack:** Flutter, go_router 17.3.0, flutter_riverpod 3, flutter_test

**Spec:** `docs/superpowers/specs/2026-10-02-router-dead-end-guard-design.md`

## Global Constraints

- 코드 주석은 한국어, WHY 중심. 화면 문구는 바꾸지 않는다.
- 동작 변경은 "돌아갈 곳이 없을 때"와 상태 조합 검사가 찾은 가드 결함 수정뿐이다. 나머지는 구조만 바꾼다.
- `flutter analyze` 0건. 전체 테스트는 `bash ~/.claude/shared/flutter-test-serial.sh --no-pub` 로 돌린다(다른 세션과 순번).
- 에뮬레이터·시뮬레이터를 띄우지 않는다.
- 기존 실패 2건(`dev_log_file_test` 부하 흔들림, `figma_conformance_test` 보호자 홈 일과를 민 뒤)은 범위 밖이다.

## Review Focus

- 세션 없는 이룸이 휴대폰에서 `popOrHome` → 홈이 연결 화면 자신 → 같은 화면 반복 없이 멈춰야 한다 (Task 2 테스트).
- 저장소 읽기가 예외를 던질 때 `popOrHome` 은 로그인 화면으로 간다 (Task 2 테스트).
- 모드 전환 `?to=guardian` 을 이룸이 휴대폰이 열 때 튕김이 한 번에 끝나야 한다 (Task 5 검사 대상에 포함).
- 보호자 로그아웃이 캐시 삭제를 기다리지 않아도 이전 계정 그림이 새 계정에 보이지 않아야 한다 — 세대 표식이 즉시 올라가는 기존 보장에 기댄다 (Task 3 테스트에서 `clear` 호출 확인).
- 세션 만료가 연달아 두 번 와도 연결 화면이 두 겹으로 쌓이지 않는다 — 기존 `previous/next` 비교를 그대로 둔다 (Task 4에서 판단 함수만 옮김).

---

### Task 1: 지금 상태의 홈 — `app_destination.dart`

**Files:**
- Create: `client/lib/core/router/app_destination.dart`
- Modify: `client/lib/features/onboarding/presentation/splash_screen.dart` (resolveDestination 정의 제거 → export, `_destination` 은 `homeFor`)
- Test: `client/test/app_destination_test.dart`

**Interfaces:**
- Produces: `String resolveDestination({required bool hasSession, required bool onboardingCompleted, required bool isElumiDevice, required String? selectedRole, bool resumeOnElumiScreen = false})` (기존과 동일), `String homeFor(ProviderContainer c)`

- [ ] Step 1: `resolveDestination` 본문을 그대로 `app_destination.dart` 로 옮기고 `homeFor` 를 더한다.

```dart
/// 지금 상태면 어디가 "홈"인가 — 앱 시작과 뒤로가기 안전망이 함께 쓴다 (#548).
String homeFor(ProviderContainer c) {
  final storage = c.read(localStorageProvider);
  return resolveDestination(
    hasSession: c.read(authRepositoryProvider).hasSession,
    onboardingCompleted: storage.isOnboardingCompleted,
    isElumiDevice: storage.isElumiDevice,
    selectedRole: storage.selectedRole,
    resumeOnElumiScreen: storage.resumeOnElumiScreen,
  );
}
```

- [ ] Step 2: splash 에 `export '../../../core/router/app_destination.dart' show resolveDestination;` 를 두고 `_destination()` 을 `homeFor(ProviderScope.containerOf(context))` 로 바꾼다.
- [ ] Step 3: `app_destination_test.dart` — `homeFor` 가 저장값(세션 없음 → 로그인, 이룸이 휴대폰+세션 → /child, 보호자 온보딩 완료 → /guardian)을 반영하는지 3건.
- [ ] Step 4: `flutter test --no-pub test/app_destination_test.dart test/splash_skip_test.dart test/splash_resume_elumi_screen_test.dart` 통과.

### Task 2: 뒤로가기 안전망 — `popOrHome`

**Files:**
- Create: `client/lib/core/router/pop_or_home.dart`, `client/test/pop_or_home_test.dart`, `client/test/no_raw_pop_test.dart`
- Modify: 인자 없는 `context.pop()` 을 쓰는 `lib/` 의 모든 파일 (스펙 §3-3 의 "그대로 둔다" 제외)

**Interfaces:**
- Consumes: `homeFor` (Task 1)
- Produces: `extension PopOrHome on BuildContext { void popOrHome(); }`

- [ ] Step 1: 실패 테스트 `pop_or_home_test.dart` — 가드 없는 최소 라우터에 `/a` 만 `go` 로 연 뒤 `popOrHome` → 홈(세션 없음 → `/login`)으로 간다 / push 로 쌓였으면 pop / 홈이 지금 화면이면 그대로 / 저장소가 예외면 `/login`.
- [ ] Step 2: 구현.

```dart
extension PopOrHome on BuildContext {
  /// 돌아갈 화면이 있으면 돌아가고, 없으면 지금 상태의 홈으로 간다 (#548).
  void popOrHome() {
    final router = GoRouter.of(this);
    if (router.canPop()) {
      router.pop();
      return;
    }
    String home;
    try {
      home = homeFor(ProviderScope.containerOf(this, listen: false));
    } catch (e) {
      // 상태를 못 읽으면 누구나 들어갈 수 있는 로그인 화면이 안전하다
      AppLogger.error('뒤로가기 홈 판단', e);
      home = Routes.login;
    }
    final here = router.routerDelegate.currentConfiguration.last.matchedLocation;
    if (here == home) return; // 같은 화면을 다시 띄우지 않는다
    debugPrint('[화면] 돌아갈 곳이 없어 홈으로: $here → $home');
    router.go(home);
  }
}
```

- [ ] Step 3: `grep -rn "context.pop()" lib` 의 각 자리를 `context.popOrHome()` 으로, `() => context.pop()` 은 `context.popOrHome` 로, `if (context.canPop()) context.pop();` 은 `context.popOrHome();` 로. `role_select_screen` 의 `context.canPop() ? context.pop : null` 은 둔다(인자 없는 호출식이 아니다).
- [ ] Step 4: `no_raw_pop_test.dart` — `lib/**/*.dart` 를 읽어 정규식 `context\.pop\(\)` 이 있으면 파일:줄 목록과 함께 실패. 허용 목록 `const _allowed = <String, String>{};`(경로 → 사유).
- [ ] Step 5: 관련 테스트 + analyze 통과.

### Task 3: 계정 로컬 정리 공통화 — `wipeLocalAccount`

**Files:**
- Create: `client/lib/core/storage/account_wipe.dart`
- Modify: `auth_repository.dart`(logout·deleteAccount), `device_link_repository.dart`(disconnectThisPhone)
- Test: `client/test/account_wipe_test.dart`

**Interfaces:**
- Produces: `Future<void> wipeLocalAccount({required TokenStore tokens, required LocalStorage storage, CardImageDiskCache? imageCache})`

- [ ] Step 1: 구현 — 토큰 지우기 → `storage.clearAll()` → `await imageCache?.clear()` (로그아웃이 끝났을 때 사진이 남아 있으면 안 된다 — 기존 개인정보 테스트 E22~E26 계약).
- [ ] Step 2: 세 자리에서 이 함수를 부른다.
- [ ] Step 3: 테스트 — 토큰·표식·역할이 지워지고 캐시 `clear` 가 불린다, 캐시 삭제가 끝난 뒤에 돌아온다. 위젯 테스트는 `test/helpers/no_disk_cache.dart` 로 디스크를 쓰지 않는다.

### Task 4: 세션 만료 처리 공통화 — `handleSessionExpired`

**Files:**
- Modify: `client/lib/features/link/application/link_reset.dart` (함수 추가), `client/lib/app.dart` (listener 가 호출)

**Interfaces:**
- Produces: `Future<void> handleSessionExpired({required GoRouter router, required ProviderContainer container})` — 이룸이 휴대폰이면 `endElumiLinkAfterSessionLoss`, 아니면 `router.go(Routes.login)`.

- [ ] Step 1: 함수로 옮기고 `app.dart` 는 `previous/next` 비교 뒤 이 함수만 부른다. 동작 변경 없음.
- [ ] Step 2: Task 6 표 테스트가 이 함수를 부른다.

### Task 5: 실제 라우터 도우미 + 상태 조합 검사

**Files:**
- Create: `client/test/helpers/real_router.dart`, `client/test/router_invariants_test.dart`

**Interfaces:**
- Produces: `Future<GoRouter> pumpRealRouter(WidgetTester t, {required InMemoryStorage storage, required InMemoryTokenStore tokens, required String start, Dio? dio, List overrides = const []})`, `String topOf(GoRouter r)`

- [ ] Step 1: `real_router.dart` — #542 의 `elumi_exit_no_dead_end_test` 의 `pumpApp` 을 옮긴다(시작 화면 이동을 끝낸 뒤 `go(start)`, 동작 줄이기 켜기·끄기 포함).
- [ ] Step 2: `router_invariants_test.dart` — 48 상태(+ 보호자 휴대폰이 이룸이 화면에서 꺼졌는가) × (등록 경로 + `/mode-switch?to=child|guardian`) 에 대해 스펙 §4 의 1~4 를 검사. 실패 메시지에 상태·경로를 적는다.
- [ ] Step 3: 통과 확인. 실패하는 조합이 나오면 규칙 결함인지 판단해 규칙을 고치거나 사유를 적고 제외.

### Task 6: 나가는 경로 표 테스트

**Files:**
- Create: `client/test/exit_paths_matrix_test.dart`
- Delete: `client/test/elumi_exit_no_dead_end_test.dart` (표로 흡수 — 연결 화면 빈 스택·역할 선택 #212 행도 옮긴다)

- [ ] Step 1: 스펙 §5 표의 6행 + 연결 화면 빈 스택 2행 + #212 행. 보호자 설정은 `guardian_settings_test` 와 같은 override(약관·버전·연결 상태)를 쓴다.
- [ ] Step 2: 통과 확인.

### Task 7: 문서·검증·마무리

- [ ] `client/CLAUDE.md` 에 스펙 §6 세 줄.
- [ ] 되돌림 확인: `linkEnterBackTarget` 을 역할 선택 고정으로 바꾸면 Task 5·6 이 실패, 화면 하나를 `context.pop()` 으로 바꾸면 Task 2 검사가 실패 — 확인 후 원복.
- [ ] analyze 0건, 전체 테스트(순번 스크립트).
- [ ] `/pro-commit` → develop 푸시 → main 병합 확인 → `/pro-changelog-deploy` → `/pro-report` → 라벨 `작업완료`.
