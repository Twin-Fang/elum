# 화면 이동 막다른 길 재발 방지 설계 (#548)

계기: #542 — 이룸이 휴대폰이 로그아웃 뒤 연결 코드 화면에 갇혔다.

## 1. 목표

사용자가 **어떤 화면에서도 빠져나갈 길을 잃지 않게** 한다. 그리고 그런 결함이 생기면 CI 의 `flutter test` 가
자동으로 잡게 한다.

성공 기준

- #542 수정을 되돌리면 새 테스트(§4 상태 조합 검사, §5 나가는 경로 표)가 실패한다.
- 화면 하나의 뒤로가기를 `context.pop()` 으로 되돌리면 §3 의 검사 테스트가 실패한다.
- 앱 전체 테스트와 `flutter analyze` 가 통과한다.

범위 밖: 실기기 E2E(Maestro)는 #542 의 남은 E2E 와 함께 따로 한다. 서버는 건드리지 않는다.

## 2. 왜 생겼나 (현재 구조의 빈틈)

| 빈틈 | 사실 |
| --- | --- |
| 이동 규칙과 화면 쌓기가 따로 논다 | `goToLinkEnter` 가 깔아 둔 역할 선택을 가드(`resolveRedirect`)가 연결 화면으로 바꿨다 |
| 뒤로가기가 돌아갈 곳을 확인하지 않는다 | 뒤로가기 28곳 중 20곳 이상이 `context.pop()` 만 부른다. 화면이 `go` 로 열리면 go_router 가 `GoError('There is nothing to pop')` 을 던진다. 출시 빌드에서는 버튼이 반응하지 않는 것처럼 보인다 |
| 테스트가 가드 없는 라우터를 쓴다 | 화면 이동 테스트 75개 파일이 직접 만든 `GoRouter` 를 쓰고, 실제 `createRouter` 를 쓰는 파일은 7개다 |
| 대칭 경로를 한 번에 보는 테스트가 없다 | 로그아웃·탈퇴·세션 만료·연결 끊김이 보호자/이룸이에서 어디로 가는지 각자 따로 검증된다 |

## 3. 뒤로가기 안전망

### 3-1. 지금 상태의 홈 — 규칙을 한 곳에

시작 화면(`splash_screen.dart`)의 `resolveDestination` 이 "지금 상태면 어디서 시작하나"를 이미 정한다. 이것을
`lib/core/router/app_destination.dart` 로 옮기고 이름은 그대로 둔다. 시작 화면은 이 파일을 `export` 해 기존
테스트(`splash_skip_test`, `splash_resume_elumi_screen_test`)의 import 를 바꾸지 않는다.

여기에 `homeFor(ProviderContainer)` 를 더한다 — 저장소·토큰에서 값을 읽어 `resolveDestination` 을 부른다.
시작 화면의 `_destination()` 도 이 함수를 쓴다. 같은 판단이 두 곳에 생기지 않는다.

### 3-2. `popOrHome`

`lib/core/router/pop_or_home.dart` 의 `BuildContext` 확장.

```
popOrHome():
  돌아갈 화면이 있다(GoRouter.canPop) → pop
  없다 → 홈 = homeFor(container)
         지금 맨 위 화면이 홈이다 → 아무것도 하지 않는다 (같은 화면 반복 방지)
         아니다 → 로그를 남기고 go(홈)
```

로그는 `AppLogger` 로 `[화면] 돌아갈 곳이 없어 홈으로: {현재} → {홈}` 을 남긴다. 막다른 길이 어디서 생겼는지
나중에 추적하기 위해서다.

### 3-3. 적용 범위 — 유연하게

| 바꾼다 | 그대로 둔다 (사유) |
| --- | --- |
| 인자 없는 `context.pop()` 전부 — `onBack` 의 `() => context.pop()`, 저장 뒤 돌아가기, `돌아가기` 버튼 등 | `Navigator.of(context).pop(...)` — 시트·다이얼로그·약관 문서처럼 Navigator 로 직접 띄운 화면이다 |
| `if (context.canPop()) context.pop();` | `context.pop(값)` — 결과를 기다리는 쪽이 있다. 항상 push 로 열린다 |
| | `leaveRoutineFlow` — 이미 "없으면 보호자 홈"을 갖고 있다 |
| | 연결 화면 `_back` — #542 의 `linkEnterBackTarget` 규칙. 세션이 없는 이룸이 휴대폰의 홈이 연결 화면 자신이라 `popOrHome` 으로는 나갈 수 없다 |

`role_select_screen` 의 `context.canPop() ? context.pop : null`(돌아갈 곳이 없으면 버튼을 숨김)은 의도가 다르다 —
약관 다음 첫 화면이라 뒤로 갈 곳이 없는 것이 정상이다. 그대로 둔다.

### 3-4. 되돌림 방지 검사 테스트

`test/no_raw_pop_test.dart` — `lib/` 의 `.dart` 파일을 읽어 인자 없는 `context.pop()` 이 있으면 실패한다.
예외는 파일 경로 + 사유를 적은 허용 목록으로 둔다(처음에는 비어 있어야 한다). 새로 쓰는 사람에게 실패 메시지가
"`context.popOrHome()` 을 쓰거나 허용 목록에 사유를 적어라"를 알려 준다.

## 4. 모든 상태 조합 라우터 검사

`test/router_invariants_test.dart` — 순수 함수만 부른다(위젯 없음).

상태: 로그인 여부(2) × 이룸이 휴대폰 여부(2) × 역할(없음·보호자·이룸이, 3) × 온보딩 완료(2) = 24.
경로: `createRouter().configuration.routes` 에서 읽은 모든 `GoRoute.path` + 모드 전환의 `to=child|guardian`.
**새 화면을 라우터에 등록하면 자동으로 검사된다.**

각 (상태, 경로) 에 대해

1. `resolveRedirect` 가 돌려준 곳이 null 이거나 **등록된 경로**다.
2. 돌려준 곳을 다시 넣으면 null 이다 — 튕김이 한 번에 끝난다(반복·순환 없음).
3. 그 상태의 홈(`resolveDestination`)은 가드에 걸리지 않는다.
4. 화면 아래에 깔아 두는 곳(`linkEnterBackTarget`)은 가드에 걸리지 않는다 — #542 자리.

실제로 생길 수 없는 조합(예: 이룸이 휴대폰인데 역할이 보호자)도 검사한다. 저장소가 어긋난 상태로 앱이 켜질 수
있으므로 그때도 규칙이 갇히지 않아야 한다. 검사가 그런 조합에서 실패하면 규칙을 고치거나, 사유를 적고
그 조합만 제외한다.

## 5. 나가는 경로 표 테스트

`test/exit_paths_matrix_test.dart` — 실제 `createRouter` 를 저장소·토큰과 묶어 띄운다(#542 의
`elumi_exit_no_dead_end_test` 를 넓혀 대체한다).

| 경로 | 도착 | 뒤로가기 | 앱 재시작 |
| --- | --- | --- | --- |
| 보호자 설정 → 로그아웃 | 로그인 | 그대로 로그인(스택 비움) | 로그인 |
| 보호자 설정 → 회원탈퇴 | 로그인 | 그대로 로그인 | 로그인 |
| 보호자 세션 만료 | 로그인 | 그대로 로그인 | 로그인 |
| 이룸이 설정 → 로그아웃 | 로그인 | 그대로 로그인 | 로그인 |
| 이룸이 설정 → 회원탈퇴 | 로그인 | 그대로 로그인 | 로그인 |
| 이룸이 세션 만료(보호자가 끊음) | 연결 화면 + `연결이 끊어졌어요` | 로그인 | 연결 화면 → 뒤로가기 로그인 |

각 행은 남은 저장값(토큰·이룸이 표식·역할)도 확인한다.

세션 만료는 지금 `app.dart` 의 `ref.listen(sessionExpiryProvider, ...)` 안에 있어 `ElumApp` 전체를 띄워야만
밟을 수 있다. 판단 부분을 `handleSessionExpired({router, container})`(`lib/features/link/application/link_reset.dart`
옆 `session_expiry.dart`)로 떼어 `app.dart` 와 테스트가 같은 함수를 부르게 한다. 동작은 바꾸지 않는다.

공용 도우미 `test/helpers/real_router.dart` — `pumpRealRouter(tester, storage:, tokens:, start:)`. 시작 화면의
자동 이동을 끝낸 뒤 시작점으로 옮기고(#542 에서 겪은 함정), 맨 위 화면을 `currentConfiguration.last.matchedLocation`
으로 읽는 `topOf(router)` 를 함께 준다(`uri` 는 push 로 쌓은 화면을 반영하지 않는다).

## 6. 규칙 문서

`client/CLAUDE.md` 에 추가한다.

- 화면 이동(가드·뒤로가기·로그아웃 도착지) 테스트는 `test/helpers/real_router.dart` 로 실제 라우터를 띄운다.
  가드 없는 가짜 `GoRouter` 로는 가드와의 충돌이 보이지 않는다(#542).
- 뒤로가기·돌아가기는 `context.popOrHome()`. 인자 없는 `context.pop()` 은 검사 테스트가 막는다.
- 새 경로를 추가하면 상태 조합 검사가 자동으로 돈다. 실패하면 규칙을 고친다.

## 7. 실패 경로

| 상황 | 동작 |
| --- | --- |
| `popOrHome` 에서 저장소를 읽다 예외 | 로그를 남기고 로그인 화면으로 간다 — 어떤 상태든 들어갈 수 있는 화면이다 |
| 홈이 지금 화면과 같다 | 아무것도 하지 않는다(무한 반복 없음). 로그는 남긴다 |
| 라우터를 못 찾는다(테스트 등) | 예외를 삼키지 않고 로그를 남긴 뒤 아무것도 하지 않는다 |

## 8. 검증

- §3-4·§4·§5 의 테스트가 지금 코드에서 통과한다.
- #542 수정(`linkEnterBackTarget`)을 역할 선택 고정으로 되돌리면 §4·§5 가 실패한다.
- 화면 하나를 `context.pop()` 으로 되돌리면 §3-4 가 실패한다.
- 전체 `flutter test`(공유 순번 스크립트), `flutter analyze` 0건.
