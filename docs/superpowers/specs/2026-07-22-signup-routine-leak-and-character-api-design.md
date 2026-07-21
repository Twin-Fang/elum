# 회원가입 직후 일과 노출 버그(#91) · 캐릭터 선택 API 연동(#89) 설계

- 이슈: [#91](https://github.com/Twin-Fang/elum/issues/91) · [#89](https://github.com/Twin-Fang/elum/issues/89)
- 작성일: 2026-07-22
- 범위: `client/` 프론트엔드만. **서버는 수정하지 않는다** — 이미 배포된 계약에 프론트를 맞춘다.

---

## #91 회원가입 직후 홈에 등록하지 않은 일과가 노출됨 (버그)

### 증상
온보딩(회원가입)을 마치고 홈에 처음 진입하면, 만든 적 없는 일과가 이미 하나 등록된 것처럼 "오늘 일과"에 노출된다.

### 원인 (코드로 확정)
홈 목록은 `homeRoutinesProvider`가 두 소스를 병합한다.
- `routineFlowProvider.routine` — 방금 만든 일과 (메모리 상태)
- `myRoutinesProvider` — 서버 `GET /api/routines` 조회 결과

서버는 정상이다. `getMyRoutines`는 `findAllByMemberId(memberId)`로 **그 회원의 일과만** 반환하고, 회원 탈퇴(`withdraw`) 시 `routineRepository.deleteAll(routines)`로 일과를 함께 지운다. 신규 회원에게는 0건이어야 한다.

문제는 **클라이언트가 계정 경계에서 메모리 상태를 초기화하지 않는 것**이다. 개발자 도구의 회원삭제(`dev_tools_overlay.dart`)는:
```dart
await ref.read(authRepositoryProvider).deleteAccount(); // storage.clearAll()
ref.invalidate(onboardingProvider);                     // 온보딩만 초기화
```
만 수행한다. `routineFlowProvider`는 `NotifierProvider`(autoDispose 아님)라 앱 세션 내내 살아있고, 이전에 만든 `routine`이 메모리에 그대로 남는다. `myRoutinesProvider`(`FutureProvider`)의 캐시도 무효화되지 않는다.

**재현 경로:** 일과 생성 → 회원삭제 → 재가입(온보딩) → 홈 진입 시 잔여 `routine`이 병합되어 노출. 심사자·테스터가 계정을 갈아끼우며 쓰는 실제 흐름이다.

### 해결 (범위: 회원삭제 지점)
`dev_tools_overlay.dart`의 회원삭제 콜백에서 세션 종속 provider를 함께 초기화한다.
```dart
await ref.read(authRepositoryProvider).deleteAccount();
ref.read(routineFlowProvider.notifier).reset(); // 방금 만든 일과 메모리 비움
ref.invalidate(myRoutinesProvider);             // 서버 조회 캐시 무효화
ref.invalidate(onboardingProvider);
```

### 실패 경로
- `reset()`/`invalidate`는 순수 메모리 연산이라 예외가 나지 않는다. `deleteAccount`는 서버 실패 시에도 로컬을 지우고 반환하므로(기존 동작) 이 흐름은 항상 완주한다.

---

## #89 캐릭터 선택 화면 API 연동 (기능추가)

### 문제
온보딩에서 고른 캐릭터가 로컬에만 저장되고 서버로 전송되지 않아, 재설치·기기 변경 시 사라진다. 조사 결과 **캐릭터뿐 아니라 nickname·supportGoals도 현재 서버에 저장되지 않는다** — `MemberRepository`에 `updateNickname`/`updateSupportGoals`가 정의돼 있으나 어디서도 호출되지 않는다.

### 값 체계 불일치 (핵심)
| 항목 | 프론트 `CardCharacter.apiValue` | 서버 `CharacterType` |
|---|---|---|
| 고양이 | `CAT` | `LULU` |
| 여우 | `FOX` | `POPO` |

프론트는 **종류**(CAT/FOX)를, 서버는 **이름**(LULU/POPO)을 값으로 쓴다. 프론트가 `CAT`을 보내면 서버가 역직렬화에 실패한다.

**방침: 서버를 그대로 두고 프론트를 맞춘다.** 서버는 배포·구현 완료 상태다.

### 서버 계약 (확인 완료)
- `PATCH /api/member/character`, body `{"character": "LULU"}` — `CharacterType`(LULU/POPO)
- `PATCH /api/member/nickname`, body `{"nickname": "..."}`
- `PATCH /api/member/support-goals`, body `{"supportGoals": ["STEP_BY_STEP", ...]}`

### 해결
1. **`character.dart`** — `CardCharacter.apiValue`를 서버 enum으로 교체.
   `cat` → `LULU`, `fox` → `POPO`. `displayName`이 이미 '루루'/'포포'라 의미가 일관된다.
   테스트로 값을 고정한다(순서·apiValue 회귀 방지).
2. **`member_repository.dart`** — `updateCharacter(String character)` 추가.
   `PATCH /api/member/character`, body `{"character": character}`. 기존 메서드처럼 **절대 throw하지 않는다** — 실패해도 로컬 값으로 fallback.
3. **`onboarding_notifier.complete()`** — 로컬 저장(기존) 후 서버 연동 추가.
   nickname → `updateNickname`, goals → `updateSupportGoals`, character → `updateCharacter`(선택된 경우만). `MemberRepository`를 provider로 주입한다.
4. 온보딩 완료 화면(`setup_done_screen.dart`)은 이미 `unawaited(complete())`로 저장을 기다리지 않으므로 흐름이 안 끊긴다. 변경 불필요.

### 실패 경로 (docs 원칙 6번 — 데모는 끊기지 않는다)
- 세 PATCH는 모두 `MemberRepository` 안에서 예외를 삼키고(`debugPrint`) 반환한다. 네트워크 실패·타임아웃·400(값 불일치)이 나도 로컬에는 값이 남아 있어 화면은 로컬 fallback으로 동작한다.
- `complete()`는 기존대로 최상위 `try/catch`로 감싸 어떤 저장 실패도 온보딩 완료를 막지 않는다.
- 캐릭터 미선택(`cardCharacter == null`)이면 캐릭터 PATCH는 건너뛴다.

### 테스트
- `character.dart`: `CardCharacter.cat.apiValue == 'LULU'`, `fox.apiValue == 'POPO'`, enum 순서(cat, fox) 고정.
- `onboarding_notifier`: `complete()` 호출 시 주입한 fake `MemberRepository`의 세 메서드가 각각 올바른 값으로 호출되는지. 캐릭터 미선택 시 `updateCharacter` 미호출 확인.
- fallback: repository가 throw해도(실제로는 안 하지만) `complete()`가 예외를 전파하지 않는지.

---

## 작업 순서
1. #91 먼저 — 회원삭제 지점 상태 초기화 + 테스트
2. #89 — 값 체계 정정 → repository 메서드 → complete() 연동 + 테스트
3. `flutter analyze` · `flutter test` 통과 확인 후 커밋
