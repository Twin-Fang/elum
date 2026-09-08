# 카드 완료 상태 오프라인 퍼스트 동기화 설계

- 작성일: 2026-09-08
- 이슈: #140 (배경: #139 — 서버 거부를 삼켜 화면 100% / 서버 57% 불일치)
- 대상: `client/` (Flutter) + `server/` (Spring Boot)

## 목표

1. 인터넷이 없어도 아동 모드가 동작한다 — 오늘 일과 목록이 보이고, 카드를 체크할 수 있고, 앱을 다시 열어도 체크가 남는다.
2. 온라인이 되면 사람이 아무것도 하지 않아도 서버에 반영된다.
3. 서버는 "최종 상태"를 멱등으로 수용한다 — 같은 요청을 몇 번 보내도 결과(별 개수 포함)가 같다.

## 확정된 결정

| 결정 | 선택 | 이유 |
|---|---|---|
| 온라인 복귀 감지 | `connectivity_plus` 추가 + 앱 시작·복귀·조작 시점 재시도 | 복귀 즉시 반영. 이벤트 폭주는 debounce로 방어 |
| 서버 순서 규칙 | 일괄 반영 API는 **순서 검사 없음** (어떤 완료 집합이든 수용) | 오프라인 재전송에서 부분 실패 연쇄를 없앤다 |
| 클라이언트 순서 제한 | **제거** (`canToggle`·버튼 흐림 삭제) | 서버가 완화됐는데 화면만 막으면 일관성 없음 |
| 충돌 정책 | 기기 하나 전제, **마지막 전송이 이김** | 보호자·아동이 같은 기기를 쓴다 |
| 로컬 저장 | `shared_preferences` (기존 `LocalStorage` 확장) | 새 DB 도입 없이 충분한 크기 |

## 서버

### `PUT /api/routines/{routineId}/progress`

요청: `{ "completedStepIds": ["<stepId>", ...] }` — 이 일과에서 **완료 상태여야 하는 단계의 전체 집합**.

처리 (`RoutineService.syncProgress`):

1. 소유 확인(기존 `getOwnedRoutine`). 상태가 CONFIRMED/COMPLETED가 아니면 `ROUTINE_INVALID_STATUS`(409).
2. 집합에 이 일과의 단계가 아닌 id가 있으면 `ROUTINE_STEP_NOT_FOUND`(404).
3. 단계마다 `completed = id ∈ 집합`. 새로 완료되는 단계는 `completedAt = now`, 해제되는 단계는 `null`, 이미 완료였던 단계는 기존 `completedAt` 유지.
4. 별: `delta = 반영 후 완료 수 − 반영 전 완료 수`, `member.totalStars = max(0, totalStars + delta)`.
5. 전부 완료면 `COMPLETED` + `completedAt = now`(이미 COMPLETED면 유지), 아니면 `CONFIRMED` + `completedAt = null`.
6. `RoutineResponse` 반환.

- `RoutineControllerDocs`에 문서화, `@LogMonitoring(logParameters=true, logResult=false)`.
- 요청 DTO `RoutineProgressSyncRequest(List<String> completedStepIds)` — 검증 어노테이션 없음(프로젝트 규칙). null은 빈 집합으로 본다.
- 기존 `complete`/`cancel` 엔드포인트는 유지한다(호환). 클라이언트는 더 이상 쓰지 않는다.

### 서버 테스트 (`RoutineServiceTest`)

- 부분 집합 반영: 3단계 중 {1,2} → 1·2 완료, 3 미완료, 별 +2, 상태 CONFIRMED
- 전체 반영: {1,2,3} → COMPLETED, completedAt 설정
- 해제 반영: 완료 {1,2,3} 상태에서 {1} → 2·3 해제, 별 −2, 상태 CONFIRMED, completedAt null
- 멱등: 같은 집합 두 번 → 두 번째 delta 0, 별 불변
- 순서 무관: {3}만 보내도 수용
- 미승인 일과 → ROUTINE_INVALID_STATUS, 없는 id → ROUTINE_STEP_NOT_FOUND
- 별 하한: totalStars 0에서 해제 요청이 와도 음수가 되지 않음

## 클라이언트

### 저장 (`LocalStorage` 확장 · `InMemoryStorage` 동일 구현)

| 메서드 | 저장 내용 |
|---|---|
| `getRoutineProgress(routineId)` / `setRoutineProgress(routineId, RoutineProgressRecord)` / `removeRoutineProgress(routineId)` | 일과별 `{ completed: [...], rewarded: [...] }` JSON |
| `getPendingSyncRoutineIds()` / `setPendingSyncRoutineIds(list)` | 서버 반영이 안 끝난 일과 id 목록 |
| `getCachedTodayRoutines()` / `setCachedTodayRoutines(list<json>)` | 마지막으로 성공한 `/today` 응답 |

키는 `progress.<routineId>`, `progress.pending`, `cache.todayRoutines`. `clearAll()`이 함께 지운다.

### 모델

- `Routine.toJson()` 추가 (캐시 저장용, `fromJson`과 대칭). `ActionCard.toJson`은 이미 있다.

### 저장소

- `RoutineRepository.getTodayRoutines()`: 성공 시 캐시에 저장 → 실패 시 **캐시가 있으면 캐시 반환**, 없으면 기존 폴백(`getMyRoutines`).
- `StepProgressRepository.syncProgress(routineId, completedStepIds) → SyncOutcome` — `accepted` / `rejected`(4xx, 서버가 상태를 거부) / `unreachable`(네트워크·5xx). `complete`/`cancel`은 삭제하고 이 메서드 하나로 대체한다.

### 상태 (`ChildRoutineNotifier`)

```
ChildRoutineState {
  Map<String, RoutineProgressRecord> progress   // routineId → 로컬 진실 (있으면 서버 값보다 우선)
  Set<String> pending                            // 서버 반영 대기 중인 routineId
}
RoutineProgressRecord { Set<String> completed; Set<String> rewarded; }
```

- `isChecked(routineId, card)`: `progress[routineId]`가 있으면 그 집합 기준, 없으면 `card.completed`.
- `toggle(routine, card)`: 순서 제한 없음. 현재 체크 집합(로컬 없으면 서버 값에서 유도)에서 토글 → 저장 → `pending`에 추가 → 동기화 큐에 넣음. 보상 규칙(처음 완료 시 1회)은 그대로, `rewarded`도 저장.
- `hydrate()`: 앱 시작 시 `pending`과 각 일과의 progress를 저장소에서 복원.
- `syncPending()`: `pending`의 일과를 직렬로 `syncProgress`.
  - `accepted` → pending 제거. progress는 유지(서버와 같음, 오프라인 표시용). 목록 provider 무효화.
  - `rejected` → progress·pending 제거(서버 진실로 복귀). 목록 provider 무효화.
  - `unreachable` → pending 유지. 다음 트리거에서 재시도.
- 동시 실행 방지: `syncPending`은 한 번에 하나만 돈다(진행 중이면 "한 번 더" 플래그).

### 동기화 트리거 (`SyncTriggers` — `app.dart`에 부착)

1. 앱 시작: `hydrate()` 후 `syncPending()`
2. `AppLifecycleState.resumed`
3. `connectivity_plus`가 오프라인→온라인 전환을 알릴 때 (500ms debounce)
4. 카드 조작 직후 (`toggle` 내부)

### 화면

- `child_routine_detail_screen.dart`: `canToggle`·`isEnabled`·흐림 제거. `_isCardChecked`는 `isChecked(routineId, card)`.
- `child_home_screen.dart` / `today_routine_section.dart`: `routineProgress(routine, state)`가 `state.isChecked(routine.id, step)`를 쓴다.
- `childRoutinesProvider` / `homeRoutinesProvider`: `asData?.value` → `.value`로 바꿔 재조회 중에도 이전 목록을 유지한다(동기화 후 목록이 순간 비는 깜빡임 제거).

### 클라이언트 테스트

- `child_step_sync_test.dart` 재작성: 오프라인(unreachable)에서 체크가 유지되고 pending에 남는다 / 온라인 복귀(`syncPending`) 시 전체 집합이 한 번 전송되고 pending이 비워진다 / rejected면 로컬이 폐기된다 / 재시작(hydrate)으로 복원된다 / 보상 1회 규칙 유지 / 순서 무관 체크
- `local_storage_test.dart`: progress·pending·캐시 round-trip
- `routine_repository` 캐시 폴백: 네트워크 실패 시 캐시 반환

## 실패 경로

| 상황 | 동작 |
|---|---|
| 오프라인에서 체크 | 즉시 체크·저장, pending 유지. 화면에 아무 경고 없음(아동 모드 규칙) |
| 오프라인에서 앱 재시작 | 캐시 목록 + 복원된 progress로 그대로 보임 |
| 복귀 후 서버 5xx | pending 유지, 다음 트리거에서 재시도 |
| 서버 404/409 (일과 삭제·미승인 등) | 로컬 폐기, 서버 값으로 복귀 |
| `/today` 실패 + 캐시 없음 | 기존 폴백(전체 조회) → 그것도 실패면 빈 상태 화면 + `E-CHLIST` |

## 범위 밖 (의도적으로)

- 다중 기기 충돌 해소, 오래된 로컬 항목 정리, 보호자 모드의 오프라인 편집
