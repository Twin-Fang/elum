# 카드 완료 상태 오프라인 퍼스트 동기화 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인터넷 없이도 아동 모드에서 카드 체크가 되고 재시작 후 유지되며, 온라인이 되면 서버에 자동 반영된다.

**Architecture:** 클라이언트는 일과별 완료 집합을 `shared_preferences`에 로컬 진실로 저장하고, 서버 반영이 안 끝난 일과 id를 전송 대기열에 둔다. 서버에 `PUT /api/routines/{id}/progress`(완료 집합 통째, 순서 검사 없음, 별은 차이만큼 — 멱등)를 추가하고, 앱 시작·복귀·온라인 전환·카드 조작 시점에 대기열을 직렬로 비운다. 오늘 일과 목록은 마지막 성공 응답을 캐시해 오프라인에서도 보이게 한다.

**Tech Stack:** Flutter 3.38 · Riverpod 3.3 · dio · shared_preferences · connectivity_plus(신규) / Spring Boot 4 · Java 21 · JPA

**Spec:** `docs/superpowers/specs/2026-09-08-offline-first-progress-sync-design.md`

## Global Constraints

- 서버: 모든 REST 엔드포인트에 `@LogMonitoring`, `*ControllerDocs` 인터페이스로 Swagger 문서화. request DTO에 `jakarta.validation` 어노테이션 금지. 예외는 `CustomException + ErrorCode`만.
- 서버: `RoutineResponse`에 `rawInputText`(원문)가 있으므로 `logResult = false`.
- 클라: 주석은 한국어·WHY 중심. `print()` 금지(`debugPrint`). 디자인 토큰 하드코딩 금지. 아동 화면에 빨강·경고 아이콘 금지. `build()` 안에 비즈니스 로직 금지.
- 클라: 새 패키지는 `connectivity_plus` 하나만. `flutter_secure_storage`·코드 생성 패키지 추가 금지.
- 클라: 보호자 입력 원문(`rawInputText`)을 로그에 남기지 않는다. 캐시에는 서버 응답을 그대로 저장하되 로그로 찍지 않는다.
- 커밋은 `git add -A` 금지 — 건드린 경로만 명시. `docs/interview/`·`docs/.DS_Store`는 스테이징하지 않는다.
- 서버 규칙: 일괄 반영 API는 **순서를 검사하지 않는다**(스펙 확정). 클라이언트 순서 제한(`canToggle`)도 제거한다.

---

## 파일 구조

**서버 (생성)**
- `server/src/main/java/com/chuseok22/elumserver/routine/application/dto/request/RoutineProgressSyncRequest.java` — 완료 집합 요청 DTO

**서버 (수정)**
- `server/.../routine/application/service/RoutineService.java` — `syncProgress()` 추가
- `server/.../routine/application/controller/RoutineController.java` — `PUT /{routineId}/progress`
- `server/.../routine/application/controller/RoutineControllerDocs.java` — 문서
- `server/src/test/.../routine/application/service/RoutineServiceTest.java` — 테스트 추가

**클라이언트 (생성)**
- `client/lib/features/child/domain/routine_progress_record.dart` — 일과 하나의 로컬 진행 기록(완료·보상)
- `client/lib/features/child/data/progress_store.dart` — 저장소 직렬화 래퍼 + 대기열
- `client/lib/features/child/application/sync_triggers.dart` — 앱 시작·복귀·온라인 전환 트리거 위젯
- `client/test/progress_store_test.dart`, `client/test/routine_cache_test.dart`

**클라이언트 (수정)**
- `client/lib/core/storage/local_storage.dart` — 진행·대기열·캐시 키 추가 (인터페이스·SharedPrefs·InMemory)
- `client/lib/shared/models/routine.dart` — `toJson()`
- `client/lib/features/guardian/data/routine_repository.dart` — 오늘 일과 캐시 저장/폴백, 저장소 주입
- `client/lib/features/child/data/step_progress_repository.dart` — `syncProgress()` + `SyncOutcome`
- `client/lib/features/child/application/child_routine_notifier.dart` — 로컬 진실·대기열·동기화
- `client/lib/features/child/presentation/child_routine_detail_screen.dart` — 순서 제한 제거
- `client/lib/features/child/presentation/child_home_screen.dart` — `.value`, 진행률
- `client/lib/features/guardian/presentation/widgets/today_routine_section.dart` — `.value`, 진행률
- `client/lib/app.dart` — `SyncTriggers` 부착
- `client/pubspec.yaml` — `connectivity_plus`
- `client/test/child_step_sync_test.dart` — 재작성, `client/test/child_mode_test.dart` — 보상 테스트 갱신

---

### Task 1: 서버 — 완료 집합 일괄 반영 서비스 (`syncProgress`)

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/routine/application/dto/request/RoutineProgressSyncRequest.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineService.java` (cancelStep 아래)
- Test: `server/src/test/java/com/chuseok22/elumserver/routine/application/service/RoutineServiceTest.java`

**Interfaces:**
- Produces: `RoutineResponse RoutineService.syncProgress(String memberId, String routineId, List<String> completedStepIds)` — Task 2가 호출. `RoutineProgressSyncRequest(List<String> completedStepIds)` + `List<String> completedStepIdsOrEmpty()`.

- [ ] **Step 1: 실패하는 테스트 작성** — `RoutineServiceTest.java` 클래스 끝(마지막 `}` 앞)에 추가

```java
  // --- 오프라인 퍼스트 일괄 반영 (이슈 #140) ---

  private Routine confirmedRoutine(Member member, int stepCount) {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setMember(member);
    routine.setStatus(RoutineStatus.CONFIRMED);
    java.util.List<RoutineStep> steps = new java.util.ArrayList<>();
    for (int i = 1; i <= stepCount; i++) {
      RoutineStep step = new RoutineStep();
      step.setId("step-" + i);
      step.setStepOrder(i);
      step.setDescription("단계 " + i);
      step.setCompleted(false);
      steps.add(step);
    }
    routine.setSteps(steps);
    return routine;
  }

  private Member memberWithStars(int stars) {
    Member member = new Member();
    member.setId("member-1");
    member.setTotalStars(stars);
    return member;
  }

  @Test
  @DisplayName("syncProgress: 부분 집합을 보내면 해당 단계만 완료되고 별은 늘어난 수만큼 오른다")
  void syncProgress_partialSet_marksOnlyThoseAndAddsStars() {
    Member member = memberWithStars(0);
    Routine routine = confirmedRoutine(member, 3);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    RoutineResponse response = routineService.syncProgress("member-1", "routine-1", List.of("step-1", "step-2"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(true, true, false);
    assertThat(routine.getSteps().get(0).getCompletedAt()).isNotNull();
    assertThat(routine.getSteps().get(2).getCompletedAt()).isNull();
    assertThat(member.getTotalStars()).isEqualTo(2);
    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(response.progressPercent()).isEqualTo(66);
  }

  @Test
  @DisplayName("syncProgress: 전부 보내면 COMPLETED가 되고 completedAt이 찍힌다")
  void syncProgress_allSteps_completesRoutine() {
    Routine routine = confirmedRoutine(memberWithStars(0), 2);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of("step-1", "step-2"));

    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.COMPLETED);
    assertThat(routine.getCompletedAt()).isNotNull();
  }

  @Test
  @DisplayName("syncProgress: 완료였던 단계를 집합에서 빼면 해제되고 별이 그만큼 내려가며 CONFIRMED로 돌아온다")
  void syncProgress_removingSteps_uncompletesAndSubtractsStars() {
    Member member = memberWithStars(3);
    Routine routine = confirmedRoutine(member, 3);
    routine.getSteps().forEach(step -> {
      step.setCompleted(true);
      step.setCompletedAt(java.time.LocalDateTime.now());
    });
    routine.setStatus(RoutineStatus.COMPLETED);
    routine.setCompletedAt(java.time.LocalDateTime.now());
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of("step-1"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(true, false, false);
    assertThat(routine.getSteps().get(1).getCompletedAt()).isNull();
    assertThat(member.getTotalStars()).isEqualTo(1);
    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(routine.getCompletedAt()).isNull();
  }

  @Test
  @DisplayName("syncProgress: 같은 집합을 두 번 보내도 별이 더 오르지 않는다 (멱등)")
  void syncProgress_sameSetTwice_isIdempotent() {
    Member member = memberWithStars(0);
    Routine routine = confirmedRoutine(member, 2);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of("step-1"));
    routineService.syncProgress("member-1", "routine-1", List.of("step-1"));

    assertThat(member.getTotalStars()).isEqualTo(1);
  }

  @Test
  @DisplayName("syncProgress: 순서를 건너뛴 집합도 그대로 받아들인다")
  void syncProgress_outOfOrderSet_isAccepted() {
    Routine routine = confirmedRoutine(memberWithStars(0), 3);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of("step-3"));

    assertThat(routine.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(false, false, true);
  }

  @Test
  @DisplayName("syncProgress: 별이 0인 상태에서 해제 요청이 와도 음수가 되지 않는다")
  void syncProgress_neverGoesBelowZeroStars() {
    Member member = memberWithStars(0);
    Routine routine = confirmedRoutine(member, 1);
    routine.getSteps().get(0).setCompleted(true);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.syncProgress("member-1", "routine-1", List.of());

    assertThat(member.getTotalStars()).isZero();
  }

  @Test
  @DisplayName("syncProgress: 승인 전 일과면 ROUTINE_INVALID_STATUS를 던진다")
  void syncProgress_pendingReview_throws() {
    Routine routine = confirmedRoutine(memberWithStars(0), 1);
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.syncProgress("member-1", "routine-1", List.of("step-1")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.ROUTINE_INVALID_STATUS));
  }

  @Test
  @DisplayName("syncProgress: 이 일과에 없는 단계 id가 섞이면 ROUTINE_STEP_NOT_FOUND를 던진다")
  void syncProgress_unknownStepId_throws() {
    Routine routine = confirmedRoutine(memberWithStars(0), 1);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.syncProgress("member-1", "routine-1", List.of("step-1", "ghost")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.ROUTINE_STEP_NOT_FOUND));
  }
```

- [ ] **Step 2: 실패 확인**

Run: `cd server && ./gradlew test --tests '*RoutineServiceTest*syncProgress*' -q 2>&1 | tail -5`
Expected: 컴파일 에러 — `syncProgress` 메서드 없음

- [ ] **Step 3: 요청 DTO 생성**

```java
package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "일과 진행 상태 일괄 반영 요청 (오프라인 퍼스트 동기화)")
public record RoutineProgressSyncRequest(

  @Schema(
    description = "완료 상태여야 하는 단계 id 전체 집합. 여기 없는 단계는 미완료로 되돌린다. 비우면 전부 미완료.",
    example = "[\"step-1\", \"step-2\"]"
  )
  List<String> completedStepIds
) {

  // 본문이 비어 오면(null) 빈 집합으로 본다 — 클라이언트가 전부 해제한 상태를 보낸 것과 같다.
  public List<String> completedStepIdsOrEmpty() {
    return completedStepIds == null ? List.of() : completedStepIds;
  }
}
```

- [ ] **Step 4: 서비스 구현** — `RoutineService.java`의 `cancelStep` 메서드 바로 아래에 추가. import에 `java.util.HashSet`, `java.util.Set`, `java.util.stream.Collectors` 추가 (없으면).

```java
  // 오프라인 퍼스트 클라이언트가 "이 일과의 완료 집합은 이것이다"를 통째로 보낸다.
  // 단계별 complete/cancel과 달리 **순서를 검사하지 않고** 최종 상태로 맞춘다 —
  // 오프라인 재전송에서 요청 하나가 거부돼 뒤가 연쇄로 무너지는 문제(이슈 #139)를
  // 구조적으로 없애기 위함. 별은 완료 수의 차이만큼만 움직여 같은 요청을 여러 번
  // 보내도 결과가 같다(멱등).
  @Transactional
  public RoutineResponse syncProgress(String memberId, String routineId, List<String> completedStepIds) {
    Routine routine = getOwnedRoutine(memberId, routineId);
    if (routine.getStatus() != RoutineStatus.CONFIRMED && routine.getStatus() != RoutineStatus.COMPLETED) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }

    List<RoutineStep> steps = routine.getSteps();
    Set<String> target = new HashSet<>(completedStepIds);
    Set<String> known = steps.stream().map(RoutineStep::getId).collect(Collectors.toSet());
    if (!known.containsAll(target)) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND);
    }

    LocalDateTime now = LocalDateTime.now();
    int before = countCompleted(steps);
    for (RoutineStep step : steps) {
      boolean shouldComplete = target.contains(step.getId());
      boolean isCompleted = Boolean.TRUE.equals(step.getCompleted());
      if (shouldComplete && !isCompleted) {
        step.setCompleted(true);
        step.setCompletedAt(now);
      } else if (!shouldComplete && isCompleted) {
        step.setCompleted(false);
        step.setCompletedAt(null);
      }
      // 이미 완료였고 여전히 완료면 completedAt을 건드리지 않는다 — 처음 완료한 시각이 기록이다.
    }
    int after = countCompleted(steps);

    Member member = routine.getMember();
    member.setTotalStars(Math.max(0, member.getTotalStars() + (after - before)));

    boolean allCompleted = !steps.isEmpty() && after == steps.size();
    if (allCompleted) {
      if (routine.getStatus() != RoutineStatus.COMPLETED) {
        routine.setStatus(RoutineStatus.COMPLETED);
        routine.setCompletedAt(now);
      }
    } else {
      routine.setStatus(RoutineStatus.CONFIRMED);
      routine.setCompletedAt(null);
    }

    return RoutineResponse.from(routine);
  }

  private int countCompleted(List<RoutineStep> steps) {
    return (int) steps.stream().filter(step -> Boolean.TRUE.equals(step.getCompleted())).count();
  }
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd server && ./gradlew test -q 2>&1 | tail -5`
Expected: 출력 없음(전체 통과). `Member` import는 `RoutineService`에 이미 있다.

- [ ] **Step 6: 커밋**

```bash
git add server/src/main/java/com/chuseok22/elumserver/routine/application/dto/request/RoutineProgressSyncRequest.java server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineService.java server/src/test/java/com/chuseok22/elumserver/routine/application/service/RoutineServiceTest.java
git commit -m "카드 완료 상태 오프라인 퍼스트 동기화 : feat : 완료 집합을 통째로 받아 순서 검사 없이 멱등 반영하는 RoutineService.syncProgress 추가(별은 완료 수 차이만큼, 상태 전이 포함) https://github.com/Twin-Fang/elum/issues/140"
```

---

### Task 2: 서버 — `PUT /api/routines/{routineId}/progress` 엔드포인트 + 문서

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/application/controller/RoutineController.java` (cancelStep 아래)
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/application/controller/RoutineControllerDocs.java` (completeStep 문서 위)

**Interfaces:**
- Consumes: Task 1의 `syncProgress`, `RoutineProgressSyncRequest`
- Produces: `PUT /api/routines/{routineId}/progress` — body `{"completedStepIds":[...]}` → `RoutineResponse`. 클라이언트 Task 5가 호출.

- [ ] **Step 1: Docs 인터페이스에 메서드 추가** — `RoutineControllerDocs.java`에서 `completeStep` 선언의 `@Operation` 바로 위에 삽입. 파일 상단 import에 `com.chuseok22.elumserver.routine.application.dto.request.RoutineProgressSyncRequest` 추가.

```java
  @Operation(
    summary = "일과 진행 상태 일괄 반영 (오프라인 퍼스트 동기화)",
    description = """
      아동 모드가 기기에 저장해 둔 "완료 단계 집합"을 통째로 받아 서버 상태를 그대로 맞춥니다.

      **처리 로직**
      1. 본인 소유 일과인지, CONFIRMED/COMPLETED 상태인지 확인합니다.
      2. 집합에 이 일과의 단계가 아닌 id가 있으면 404를 반환합니다.
      3. 집합에 있는 단계는 완료, 없는 단계는 미완료로 맞춥니다. 처음 완료되는 단계에만 완료 시각을 찍습니다.
      4. 별(totalStars)은 완료 수의 **차이만큼만** 움직입니다. 같은 요청을 여러 번 보내도 결과가 같습니다(멱등).
      5. 전부 완료면 COMPLETED, 아니면 CONFIRMED로 상태를 맞춥니다.

      **주의사항**
      - 단계별 완료 API와 달리 **순서를 검사하지 않습니다.** 오프라인에서 쌓인 변경을 한 번에 반영하기 위한 것입니다.
      - 화면 표시는 클라이언트 로컬 저장소가 진실이고, 이 API는 서버를 따라오게 만드는 용도입니다.
      """
  )
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "반영 성공. 반영 후 일과 전체 상태를 반환합니다.",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "403",
      description = "본인 소유가 아닌 일과에 접근",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    ),
    @ApiResponse(
      responseCode = "404",
      description = "존재하지 않는 일과이거나, 집합에 이 일과의 단계가 아닌 id가 섞인 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_STEP_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 단계입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "409",
      description = "보호자 승인 전(PENDING_REVIEW) 일과",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_INVALID_STATUS\",\"errorMessage\":\"현재 상태에서는 처리할 수 없습니다.\"}"
        )
      )
    )
  })
  ResponseEntity<RoutineResponse> syncProgress(
    Authentication authentication, String routineId, RoutineProgressSyncRequest request
  );
```

> `Authentication` import가 Docs 파일에 이미 있는지 확인한다(다른 메서드가 같은 파라미터를 쓴다).

- [ ] **Step 2: 컨트롤러 구현** — `RoutineController.java`의 `cancelStep` 메서드 아래. import에 `RoutineProgressSyncRequest`, `org.springframework.web.bind.annotation.PutMapping` 추가 (`RequestBody`는 이미 있음).

```java
  // 오프라인 퍼스트 동기화 — 완료 집합을 통째로 받아 멱등 반영한다 (이슈 #140).
  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PutMapping("/{routineId}/progress")
  public ResponseEntity<RoutineResponse> syncProgress(
    Authentication authentication,
    @PathVariable String routineId,
    @RequestBody RoutineProgressSyncRequest request
  ) {
    RoutineResponse response = routineService.syncProgress(
      authentication.getName(), routineId, request.completedStepIdsOrEmpty()
    );
    return ResponseEntity.ok(response);
  }
```

- [ ] **Step 3: 컴파일·테스트**

Run: `cd server && ./gradlew test -q 2>&1 | tail -5`
Expected: 출력 없음(통과). 컨트롤러가 Docs 인터페이스를 `implements`하므로 시그니처가 다르면 컴파일 에러로 드러난다.

- [ ] **Step 4: 커밋**

```bash
git add server/src/main/java/com/chuseok22/elumserver/routine/application/controller/RoutineController.java server/src/main/java/com/chuseok22/elumserver/routine/application/controller/RoutineControllerDocs.java
git commit -m "카드 완료 상태 오프라인 퍼스트 동기화 : feat : PUT /api/routines/{routineId}/progress 엔드포인트와 Swagger 문서 추가 https://github.com/Twin-Fang/elum/issues/140"
```

---

### Task 3: 클라이언트 — 로컬 진행 기록 저장소 (`RoutineProgressRecord` · `LocalStorage` 확장 · `ProgressStore`)

**Files:**
- Create: `client/lib/features/child/domain/routine_progress_record.dart`
- Create: `client/lib/features/child/data/progress_store.dart`
- Modify: `client/lib/core/storage/local_storage.dart` (인터페이스·SharedPrefsStorage·InMemoryStorage)
- Test: `client/test/progress_store_test.dart`

**Interfaces:**
- Produces:
  - `RoutineProgressRecord({Set<String> completed, Set<String> rewarded})` + `copyWith` + `toJson()/fromJson()`
  - `LocalStorage`: `String? getRoutineProgressJson(String routineId)`, `Future<void> setRoutineProgressJson(String routineId, String json)`, `Future<void> removeRoutineProgress(String routineId)`, `List<String> get pendingSyncRoutineIds`, `Future<void> setPendingSyncRoutineIds(List<String> ids)`, `String? get cachedTodayRoutinesJson`, `Future<void> setCachedTodayRoutinesJson(String json)`
  - `ProgressStore(LocalStorage)`: `RoutineProgressRecord? load(String routineId)`, `Future<void> save(String routineId, RoutineProgressRecord record)`, `Future<void> remove(String routineId)`, `Set<String> get pending`, `Future<void> setPending(Set<String> ids)`; provider `progressStoreProvider`
  - Task 4는 `cachedTodayRoutinesJson`, Task 6은 `ProgressStore`를 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성** — `client/test/progress_store_test.dart`

```dart
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/child/data/progress_store.dart';
import 'package:elum/features/child/domain/routine_progress_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// 아동 카드 진행 상태의 로컬 영속 (이슈 #140).
///
/// 앱을 다시 열어도 체크가 남아야 하고, 서버 반영이 안 끝난 일과는 대기열에 남아야 한다.
/// 저장소가 이걸 잃어버리면 오프라인 퍼스트가 성립하지 않는다.
void main() {
  group('RoutineProgressRecord', () {
    test('JSON으로 왕복해도 완료·보상 집합이 보존된다', () {
      const record = RoutineProgressRecord(
        completed: {'c1', 'c2'},
        rewarded: {'c1'},
      );

      final restored = RoutineProgressRecord.fromJson(record.toJson());

      expect(restored.completed, {'c1', 'c2'});
      expect(restored.rewarded, {'c1'});
    });

    test('빈 JSON에서도 죽지 않는다', () {
      final restored = RoutineProgressRecord.fromJson(const {});

      expect(restored.completed, isEmpty);
      expect(restored.rewarded, isEmpty);
    });
  });

  group('ProgressStore', () {
    late InMemoryStorage storage;
    late ProgressStore store;

    setUp(() {
      storage = InMemoryStorage();
      store = ProgressStore(storage);
    });

    test('저장한 기록을 같은 일과 id로 다시 읽는다', () async {
      await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));

      expect(store.load('r1')?.completed, {'c1'});
    });

    test('없는 일과는 null이다', () {
      expect(store.load('ghost'), isNull);
    });

    test('remove하면 읽히지 않는다', () async {
      await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));
      await store.remove('r1');

      expect(store.load('r1'), isNull);
    });

    test('대기열은 집합으로 왕복한다', () async {
      await store.setPending({'r1', 'r2'});

      expect(store.pending, {'r1', 'r2'});
    });

    test('clearAll이 진행 기록·대기열·캐시를 함께 지운다', () async {
      // 온보딩 초기화(계정 전환) 후 이전 아이의 체크가 남으면 안 된다.
      await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));
      await store.setPending({'r1'});
      await storage.setCachedTodayRoutinesJson('[]');

      await storage.clearAll();

      expect(store.load('r1'), isNull);
      expect(store.pending, isEmpty);
      expect(storage.cachedTodayRoutinesJson, isNull);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd client && flutter test test/progress_store_test.dart 2>&1 | tail -3`
Expected: 컴파일 에러 — `progress_store.dart` 없음

- [ ] **Step 3: `RoutineProgressRecord` 생성** — `client/lib/features/child/domain/routine_progress_record.dart`

```dart
/// 일과 하나의 로컬 진행 기록 — 기기가 진실이다 (이슈 #140).
///
/// 서버 `completed`는 참고값이고, 이 기록이 있으면 이것이 화면 기준이다.
/// 오프라인에서 체크한 내용이 서버에 아직 없어도 화면은 이 기록을 보여준다.
///
/// Freezed를 쓰지 않는 이유: 필드 두 개짜리 값 객체라 코드 생성이 더 비싸다.
class RoutineProgressRecord {
  const RoutineProgressRecord({
    this.completed = const {},
    this.rewarded = const {},
  });

  /// 완료로 표시한 카드 id. 해제하면 빠진다.
  final Set<String> completed;

  /// 보상을 이미 보여준 카드 id. **해제해도 남는다** — 재체크 때 또 축하하지 않는다.
  final Set<String> rewarded;

  RoutineProgressRecord copyWith({
    Set<String>? completed,
    Set<String>? rewarded,
  }) {
    return RoutineProgressRecord(
      completed: completed ?? this.completed,
      rewarded: rewarded ?? this.rewarded,
    );
  }

  Map<String, dynamic> toJson() => {
        'completed': completed.toList(),
        'rewarded': rewarded.toList(),
      };

  /// 저장소가 깨져 있어도 죽지 않는다 — 필드가 없으면 빈 집합.
  factory RoutineProgressRecord.fromJson(Map<String, dynamic> json) {
    return RoutineProgressRecord(
      completed: _stringSet(json['completed']),
      rewarded: _stringSet(json['rewarded']),
    );
  }

  static Set<String> _stringSet(Object? value) => switch (value) {
        final List<dynamic> list => list.map((e) => e.toString()).toSet(),
        _ => const {},
      };
}
```

- [ ] **Step 4: `LocalStorage` 인터페이스 확장** — `local_storage.dart`의 `Future<void> clearAll();` 바로 위에 추가

```dart
  // --- 아동 카드 진행 (오프라인 퍼스트, 이슈 #140) ---
  // 일과별 완료·보상 기록과 서버 반영 대기열, 오늘 일과 캐시.
  // JSON 문자열로만 주고받는다 — core가 feature 모델(RoutineProgressRecord)을
  // 알면 의존 방향이 뒤집힌다. 직렬화는 feature 쪽 ProgressStore가 한다.

  String? getRoutineProgressJson(String routineId);
  Future<void> setRoutineProgressJson(String routineId, String json);
  Future<void> removeRoutineProgress(String routineId);

  /// 서버 반영이 아직 안 끝난 일과 id 목록.
  List<String> get pendingSyncRoutineIds;
  Future<void> setPendingSyncRoutineIds(List<String> ids);

  /// 마지막으로 성공한 `/api/routines/today` 응답. 오프라인에서 목록을 띄우는 데 쓴다.
  String? get cachedTodayRoutinesJson;
  Future<void> setCachedTodayRoutinesJson(String json);
```

- [ ] **Step 5: `SharedPrefsStorage` 구현** — 키 상수 3개를 `_kAccessToken` 아래에 추가하고, `clearAccessToken` 아래에 메서드 추가, `clearAll`을 수정

```dart
  static const _kProgressPrefix = 'progress.';
  static const _kPendingSync = 'progress.pending';
  static const _kCachedToday = 'cache.todayRoutines';
```

```dart
  @override
  String? getRoutineProgressJson(String routineId) =>
      _prefs.getString('$_kProgressPrefix$routineId');

  @override
  Future<void> setRoutineProgressJson(String routineId, String json) {
    // 카드 id 집합뿐이라 로그에 남겨도 원문은 없다
    AppLogger.storageWrite('$_kProgressPrefix$routineId', json);
    return _prefs.setString('$_kProgressPrefix$routineId', json);
  }

  @override
  Future<void> removeRoutineProgress(String routineId) {
    AppLogger.storageDelete('$_kProgressPrefix$routineId');
    return _prefs.remove('$_kProgressPrefix$routineId');
  }

  @override
  List<String> get pendingSyncRoutineIds =>
      _prefs.getStringList(_kPendingSync) ?? const [];

  @override
  Future<void> setPendingSyncRoutineIds(List<String> ids) {
    AppLogger.storageWrite(_kPendingSync, ids);
    return _prefs.setStringList(_kPendingSync, ids);
  }

  @override
  String? get cachedTodayRoutinesJson => _prefs.getString(_kCachedToday);

  @override
  Future<void> setCachedTodayRoutinesJson(String json) {
    // 서버 응답에는 보호자 원문(rawInputText)이 들어 있다 — 값은 로그에 찍지 않는다 (docs 원칙 5번).
    AppLogger.storageWrite(_kCachedToday, '${json.length}B');
    return _prefs.setString(_kCachedToday, json);
  }
```

`clearAll`의 for 루프 뒤에 추가:

```dart
    // 진행 기록은 일과 id마다 키가 생기므로 접두사로 찾아 지운다.
    // 계정 전환 후 이전 아이의 체크·대기열·캐시가 남으면 안 된다.
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith(_kProgressPrefix) || k == _kCachedToday,
    )) {
      await _prefs.remove(key);
    }
```

> `_kPendingSync`는 `progress.` 접두사라 위 루프에 포함된다.

- [ ] **Step 6: `InMemoryStorage` 구현** — 필드 3개와 메서드 추가, `clearAll`에서 함께 초기화

```dart
  final Map<String, String> _progress = {};
  List<String> _pendingSync = const [];
  String? _cachedToday;
```

```dart
  @override
  String? getRoutineProgressJson(String routineId) => _progress[routineId];

  @override
  Future<void> setRoutineProgressJson(String routineId, String json) async =>
      _progress[routineId] = json;

  @override
  Future<void> removeRoutineProgress(String routineId) async =>
      _progress.remove(routineId);

  @override
  List<String> get pendingSyncRoutineIds => _pendingSync;

  @override
  Future<void> setPendingSyncRoutineIds(List<String> ids) async =>
      _pendingSync = ids;

  @override
  String? get cachedTodayRoutinesJson => _cachedToday;

  @override
  Future<void> setCachedTodayRoutinesJson(String json) async =>
      _cachedToday = json;
```

`clearAll` 끝에:

```dart
    _progress.clear();
    _pendingSync = const [];
    _cachedToday = null;
```

- [ ] **Step 7: `ProgressStore` 생성** — `client/lib/features/child/data/progress_store.dart`

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../domain/routine_progress_record.dart';

/// 아동 카드 진행 기록의 저장소 래퍼 (이슈 #140).
///
/// [LocalStorage]는 JSON 문자열만 다루므로 직렬화·역직렬화를 여기서 한다.
/// notifier가 저장 형식을 몰라야 저장 방식을 바꿔도 화면 로직이 안 흔들린다.
class ProgressStore {
  ProgressStore(this._storage);

  final LocalStorage _storage;

  /// 저장된 기록. 없거나 깨져 있으면 null — 화면은 서버 값으로 폴백한다.
  RoutineProgressRecord? load(String routineId) {
    final json = _storage.getRoutineProgressJson(routineId);
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      return RoutineProgressRecord.fromJson(decoded);
    } catch (_) {
      // 깨진 기록 한 건 때문에 아이 화면이 죽으면 안 된다 (docs 원칙 6번)
      return null;
    }
  }

  Future<void> save(String routineId, RoutineProgressRecord record) =>
      _storage.setRoutineProgressJson(routineId, jsonEncode(record.toJson()));

  Future<void> remove(String routineId) =>
      _storage.removeRoutineProgress(routineId);

  /// 서버 반영이 안 끝난 일과 id.
  Set<String> get pending => _storage.pendingSyncRoutineIds.toSet();

  Future<void> setPending(Set<String> ids) =>
      _storage.setPendingSyncRoutineIds(ids.toList());
}

final progressStoreProvider = Provider<ProgressStore>(
  (ref) => ProgressStore(ref.watch(localStorageProvider)),
);
```

- [ ] **Step 8: 테스트 통과 확인**

Run: `cd client && flutter test test/progress_store_test.dart test/local_storage_test.dart 2>&1 | tail -3`
Expected: `All tests passed!`

- [ ] **Step 9: 커밋**

```bash
git add client/lib/features/child/domain/routine_progress_record.dart client/lib/features/child/data/progress_store.dart client/lib/core/storage/local_storage.dart client/test/progress_store_test.dart
git commit -m "카드 완료 상태 오프라인 퍼스트 동기화 : feat : 일과별 완료·보상 기록과 전송 대기열, 오늘 일과 캐시를 로컬 저장소에 영속하는 ProgressStore 추가 https://github.com/Twin-Fang/elum/issues/140"
```

---

### Task 4: 클라이언트 — 오늘 일과 캐시 (`Routine.toJson` · 저장소 폴백)

**Files:**
- Modify: `client/lib/shared/models/routine.dart` (`fromJson` 위)
- Modify: `client/lib/features/guardian/data/routine_repository.dart` (`RoutineRepositoryImpl` 생성자·`getTodayRoutines`·provider)
- Test: `client/test/routine_cache_test.dart`

**Interfaces:**
- Consumes: Task 3의 `LocalStorage.cachedTodayRoutinesJson` / `setCachedTodayRoutinesJson`
- Produces: `Map<String, dynamic> Routine.toJson()`; `RoutineRepositoryImpl({Dio? dio, LocalStorage? storage})`

- [ ] **Step 1: 실패하는 테스트 작성** — `client/test/routine_cache_test.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// 오늘 일과 목록의 오프라인 캐시 (이슈 #140).
///
/// 인터넷이 끊기면 `/api/routines/today`가 실패한다. 마지막 성공 응답을 저장해 두고
/// 그걸 보여줘야 아동 모드가 오프라인에서도 비지 않는다.
void main() {
  late _StubAdapter adapter;
  late InMemoryStorage storage;
  late RoutineRepositoryImpl repo;

  setUp(() {
    // 실서버 경로를 타야 캐시가 동작한다. mock이면 요청 자체를 안 한다.
    dotenv.loadFromString(envString: 'ELUM_USE_MOCK=false');
    adapter = _StubAdapter();
    storage = InMemoryStorage();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    repo = RoutineRepositoryImpl(dio: dio, storage: storage);
  });

  const serverBody = [
    {
      'id': 'r1',
      'title': '비 오는 날 학교 가기',
      'status': 'CONFIRMED',
      'steps': [
        {'id': 'c1', 'description': '옷을 입어요', 'stepOrder': 1, 'completed': true},
        {'id': 'c2', 'description': '우산을 챙겨요', 'stepOrder': 2, 'completed': false},
      ],
      'completedStepCount': 1,
      'totalStepCount': 2,
      'progressPercent': 50,
    },
  ];

  test('성공 응답을 캐시에 저장한다', () async {
    adapter.stubJson(200, serverBody);

    await repo.getTodayRoutines();

    final cached = jsonDecode(storage.cachedTodayRoutinesJson!) as List<dynamic>;
    expect(cached, hasLength(1));
    expect((cached.first as Map)['id'], 'r1');
  });

  test('네트워크가 끊기면 캐시를 돌려준다', () async {
    adapter.stubJson(200, serverBody);
    await repo.getTodayRoutines();
    adapter.fail = true;

    final routines = await repo.getTodayRoutines();

    expect(routines.map((r) => r.id), ['r1']);
    expect(routines.first.steps.first.completed, isTrue);
  });

  test('캐시가 없으면 기존 폴백(빈 목록)으로 간다', () async {
    adapter.fail = true;

    final routines = await repo.getTodayRoutines();

    expect(routines, isEmpty);
  });

  test('Routine.toJson은 fromJson과 왕복한다', () {
    const routine = Routine(
      id: 'r1',
      title: '제목',
      rawInputText: '원문',
      sanitizedInputText: '<이름> 원문',
      status: 'CONFIRMED',
      steps: [ActionCard(id: 'c1', description: '설명', stepOrder: 1, completed: true)],
      completedStepCount: 1,
      totalStepCount: 1,
      progressPercent: 100,
    );

    final restored = Routine.fromJson(routine.toJson());

    expect(restored, routine);
  });
}

/// 응답을 미리 정해두거나 연결 실패를 흉내내는 어댑터.
class _StubAdapter implements HttpClientAdapter {
  int _status = 200;
  Object _body = const [];
  bool fail = false;

  void stubJson(int status, Object body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (fail) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString(
      jsonEncode(_body),
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd client && flutter test test/routine_cache_test.dart 2>&1 | tail -3`
Expected: 컴파일 에러 — `storage` 파라미터 없음, `toJson` 없음

- [ ] **Step 3: `Routine.toJson()` 추가** — `routine.dart`의 `factory Routine.fromJson` 바로 위

```dart
  /// 오프라인 캐시 저장용 — [fromJson]과 대칭이어야 한다 (이슈 #140).
  /// 원문(rawInputText)도 포함되므로 **이 결과를 로그에 찍지 않는다** (docs 원칙 5번).
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'rawInputText': rawInputText,
        'sanitizedInputText': sanitizedInputText,
        'status': status,
        'steps': steps.map((s) => s.toJson()).toList(),
        'completedStepCount': completedStepCount,
        'totalStepCount': totalStepCount,
        'progressPercent': progressPercent,
      };
```

- [ ] **Step 4: 저장소 주입 + 캐시 로직** — `routine_repository.dart`

import 추가:

```dart
import 'dart:convert';

import '../../../core/storage/local_storage.dart';
import '../../onboarding/application/onboarding_notifier.dart';
```

생성자·필드 교체:

```dart
class RoutineRepositoryImpl implements RoutineRepository {
  RoutineRepositoryImpl({Dio? dio, LocalStorage? storage})
      : _dio = dio ?? DioClient.create(),
        _storage = storage;

  final Dio _dio;

  /// 오늘 일과 캐시용. null이면 캐시 없이 동작한다(기존 테스트 호환).
  final LocalStorage? _storage;
```

`getTodayRoutines` 전체 교체:

```dart
  @override
  Future<List<Routine>> getTodayRoutines() async {
    AppLogger.repositoryCall('RoutineRepository', 'getTodayRoutines');

    if (AppConfig.useMock) {
      AppLogger.repositorySuccess('RoutineRepository', 'getTodayRoutines', '모의 데이터');
      return const [];
    }

    try {
      final res = await _dio.get<List<dynamic>>('/api/routines/today');
      final body = res.data;
      if (body != null) {
        final routines = body
            .whereType<Map<String, dynamic>>()
            .map(Routine.fromJson)
            .toList();
        AppLogger.repositorySuccess(
          'RoutineRepository', 'getTodayRoutines', '${routines.length}개 오늘 일과 조회됨');
        // 성공한 응답을 캐시해 둔다 — 다음에 오프라인이면 이걸 보여준다 (이슈 #140)
        await _storage?.setCachedTodayRoutinesJson(
          jsonEncode(routines.map((r) => r.toJson()).toList()),
        );
        return routines;
      }
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'getTodayRoutines', e);
    }

    // 오프라인이거나 서버가 죽었다 — 마지막 성공 응답이 있으면 그걸 쓴다.
    final cached = _readCachedToday();
    if (cached != null) {
      AppLogger.repositorySuccess(
        'RoutineRepository', 'getTodayRoutines (캐시)', '${cached.length}개 오프라인 캐시 사용');
      return cached;
    }

    // 캐시도 없으면 전체 조회로 폴백. 승인 여부 필터는 화면 provider가 한 번 더 거른다 (docs 원칙 3번).
    AppLogger.repositorySuccess(
      'RoutineRepository', 'getTodayRoutines (폴백)', '전체 일과 조회로 대체');
    return getMyRoutines();
  }

  /// 캐시가 깨져 있으면 null — 폴백으로 넘긴다. 캐시 한 건 때문에 화면이 죽으면 안 된다.
  List<Routine>? _readCachedToday() {
    final json = _storage?.cachedTodayRoutinesJson;
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return null;
      return decoded.whereType<Map<String, dynamic>>().map(Routine.fromJson).toList();
    } catch (_) {
      return null;
    }
  }
```

provider 교체:

```dart
final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepositoryImpl(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
  ),
);
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd client && flutter test test/routine_cache_test.dart test/routine_server_failure_test.dart 2>&1 | tail -3`
Expected: `All tests passed!`

- [ ] **Step 6: 커밋**

```bash
git add client/lib/shared/models/routine.dart client/lib/features/guardian/data/routine_repository.dart client/test/routine_cache_test.dart
git commit -m "카드 완료 상태 오프라인 퍼스트 동기화 : feat : 오늘 일과 마지막 성공 응답을 캐시하고 네트워크 실패 시 캐시로 목록을 띄우도록 RoutineRepository 보강, Routine.toJson 추가 https://github.com/Twin-Fang/elum/issues/140"
```

---

### Task 5: 클라이언트 — `StepProgressRepository.syncProgress`

**Files:**
- Modify: `client/lib/features/child/data/step_progress_repository.dart` (전체 교체)

**Interfaces:**
- Consumes: Task 2의 `PUT /api/routines/{routineId}/progress`
- Produces: `enum SyncOutcome { accepted, rejected, unreachable }`, `Future<SyncOutcome> StepProgressRepository.syncProgress({required String routineId, required Set<String> completedStepIds})`. Task 6이 호출. 기존 `complete`/`cancel`은 **삭제**한다(호출부는 Task 6에서 함께 바뀐다).

- [ ] **Step 1: 파일 전체 교체**

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';

/// 서버가 완료 집합을 받아들였는가.
///
/// - [accepted]: 반영됨. 대기열에서 빼도 된다.
/// - [rejected]: 서버가 이 상태를 거부했다(승인 전 일과, 삭제된 단계 등). 로컬 기록을
///   버리고 서버 값으로 돌아가야 한다.
/// - [unreachable]: 네트워크·서버 장애. 로컬 기록을 유지하고 다음에 다시 보낸다.
enum SyncOutcome { accepted, rejected, unreachable }

/// 아동 카드 진행 상태를 서버에 반영한다 (이슈 #140).
///
/// 단계별 complete/cancel을 쓰지 않고 **완료 집합을 통째로** `PUT /progress`에 보낸다.
/// 서버가 순서를 검사하지 않고 멱등으로 맞추므로, 오프라인에서 쌓인 변경을 몇 번을
/// 보내도 결과가 같다. 출처: server/.../RoutineControllerDocs.java (syncProgress)
///
/// **절대 throw하지 않는다.** 결과를 [SyncOutcome]으로 돌려주고 판단은 notifier가 한다.
class StepProgressRepository {
  StepProgressRepository({Dio? dio}) : _dio = dio ?? DioClient.create();

  final Dio _dio;

  Future<SyncOutcome> syncProgress({
    required String routineId,
    required Set<String> completedStepIds,
  }) async {
    // 로컬 카드(mock)는 서버에 없다. 보낼 곳이 없으므로 반영된 것으로 본다.
    if (AppConfig.useMock) return SyncOutcome.accepted;

    try {
      await _dio.put<dynamic>(
        '/api/routines/$routineId/progress',
        data: {'completedStepIds': completedStepIds.toList()},
      );
      return SyncOutcome.accepted;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // 4xx 중 서버가 "이 상태는 안 된다"고 답한 것만 거부로 본다.
      // 401은 인터셉터가 토큰을 재발급하므로 여기까지 오면 일시 장애로 취급한다.
      if (status != null && const {400, 403, 404, 409}.contains(status)) {
        debugPrint('[sync] 서버가 진행 상태를 거부함 ($status): $routineId');
        return SyncOutcome.rejected;
      }
      debugPrint('[sync] 서버에 닿지 못함, 다음에 재시도: $routineId ($e)');
      return SyncOutcome.unreachable;
    } catch (e) {
      debugPrint('[sync] 예상 못 한 실패, 다음에 재시도: $routineId ($e)');
      return SyncOutcome.unreachable;
    }
  }
}

final stepProgressRepositoryProvider = Provider<StepProgressRepository>(
  (ref) => StepProgressRepository(dio: ref.watch(dioProvider)),
);
```

- [ ] **Step 2: 컴파일 확인** — 호출부(notifier)가 아직 옛 메서드를 부르므로 분석에서 에러가 나는 것이 정상이다. Task 6에서 함께 해소한다.

Run: `cd client && flutter analyze lib/features/child/data/step_progress_repository.dart 2>&1 | tail -3`
Expected: 이 파일 자체에는 에러 없음

- [ ] **Step 3: 커밋은 Task 6과 함께 한다** (호출부가 깨진 상태로 커밋하지 않는다)

---

### Task 6: 클라이언트 — `ChildRoutineNotifier` 오프라인 퍼스트 재설계 + 테스트

**Files:**
- Modify: `client/lib/features/child/application/child_routine_notifier.dart` (전체 교체)
- Test: `client/test/child_step_sync_test.dart` (전체 교체)
- Modify: `client/test/child_mode_test.dart` (보상 조건 그룹)

**Interfaces:**
- Consumes: Task 3 `ProgressStore`/`RoutineProgressRecord`, Task 5 `SyncOutcome`/`syncProgress`, `todayRoutinesProvider`/`myRoutinesProvider`
- Produces (Task 7·8이 쓴다):
  - `ChildRoutineState { Map<String, RoutineProgressRecord> progress; Set<String> pending; }` + `bool isChecked(String routineId, ActionCard card)` + `bool hasRewarded(String routineId, String cardId)`
  - `ChildRoutineNotifier`: `Future<void> hydrate()`, `bool toggle({required Routine routine, required ActionCard card})`, `void syncPending()`, `void reset()`

- [ ] **Step 1: 테스트 전체 교체** — `client/test/child_step_sync_test.dart`

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/data/progress_store.dart';
import 'package:elum/features/child/data/step_progress_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카드 완료 체크의 오프라인 퍼스트 동기화 (이슈 #140).
///
/// 기기가 진실이다. 탭하면 즉시 저장되고, 서버 반영은 뒤에서 따라온다.
/// - 서버에 못 닿으면 기록과 대기열을 유지하고 다음에 다시 보낸다
/// - 서버가 거부하면 로컬 기록을 버리고 서버 값으로 돌아간다
/// - 앱을 다시 열면 저장된 기록이 복원된다
void main() {
  const c1 = ActionCard(id: 'c1', description: '옷을 입어요', stepOrder: 1);
  const c2 = ActionCard(id: 'c2', description: '우산을 챙겨요', stepOrder: 2);
  const c3 = ActionCard(id: 'c3', description: '신발을 신어요', stepOrder: 3);
  const routine = Routine(
    id: 'r1',
    title: '비 오는 날 학교에 가요',
    status: 'CONFIRMED',
    steps: [c1, c2, c3],
  );

  ({ProviderContainer container, _FakeSyncRepo repo, InMemoryStorage storage})
      setUp({SyncOutcome outcome = SyncOutcome.accepted, InMemoryStorage? storage}) {
    final repo = _FakeSyncRepo(outcome: outcome);
    final mem = storage ?? InMemoryStorage(onboardingCompleted: true);
    final container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(mem),
        stepProgressRepositoryProvider.overrideWithValue(repo),
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo, storage: mem);
  }

  Future<void> drain() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('체크는 즉시 로컬에 반영되고 서버에는 집합으로 간다', () {
    test('아무 순서로나 체크할 수 있다', () async {
      final (:container, :repo, storage: _) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      notifier.toggle(routine: routine, card: c3);
      notifier.toggle(routine: routine, card: c1);
      await drain();

      final state = container.read(childRoutineProvider);
      expect(state.isChecked('r1', c3), isTrue);
      expect(state.isChecked('r1', c1), isTrue);
      expect(state.isChecked('r1', c2), isFalse);
      expect(repo.lastSent, {'c3', 'c1'});
    });

    test('서버 완료 카드를 해제하면 집합에서 빠져서 전송된다', () async {
      const serverDone = ActionCard(id: 'c1', description: '옷을 입어요', stepOrder: 1, completed: true);
      const resumed = Routine(id: 'r1', status: 'CONFIRMED', steps: [serverDone, c2, c3]);
      final (:container, :repo, storage: _) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      expect(container.read(childRoutineProvider).isChecked('r1', serverDone), isTrue);
      notifier.toggle(routine: resumed, card: serverDone);
      await drain();

      expect(container.read(childRoutineProvider).isChecked('r1', serverDone), isFalse);
      expect(repo.lastSent, isEmpty);
    });

    test('탭할 때마다 저장소에 기록된다', () async {
      final (:container, repo: _, :storage) = setUp();
      container.read(childRoutineProvider.notifier).toggle(routine: routine, card: c1);
      await drain();

      expect(ProgressStore(storage).load('r1')?.completed, {'c1'});
    });
  });

  group('오프라인 — 서버에 못 닿아도 기록은 남는다', () {
    test('unreachable이면 체크가 유지되고 대기열에 남는다', () async {
      final (:container, :repo, :storage) = setUp(outcome: SyncOutcome.unreachable);
      container.read(childRoutineProvider.notifier).toggle(routine: routine, card: c1);
      await drain();

      final state = container.read(childRoutineProvider);
      expect(state.isChecked('r1', c1), isTrue);
      expect(state.pending, contains('r1'));
      expect(ProgressStore(storage).pending, contains('r1'));
    });

    test('온라인 복귀 후 syncPending이 대기열을 비운다', () async {
      final (:container, :repo, storage: _) = setUp(outcome: SyncOutcome.unreachable);
      final notifier = container.read(childRoutineProvider.notifier);
      notifier.toggle(routine: routine, card: c1);
      await drain();
      expect(container.read(childRoutineProvider).pending, contains('r1'));

      repo.outcome = SyncOutcome.accepted;
      notifier.syncPending();
      await drain();

      expect(container.read(childRoutineProvider).pending, isEmpty);
      expect(repo.lastSent, {'c1'});
      // 반영됐어도 로컬 기록은 남는다 — 다음 오프라인 때 보여줄 값이다
      expect(container.read(childRoutineProvider).isChecked('r1', c1), isTrue);
    });
  });

  group('서버 거부 — 로컬을 버리고 서버 값으로 돌아간다', () {
    test('rejected면 기록과 대기열이 사라진다', () async {
      final (:container, repo: _, :storage) = setUp(outcome: SyncOutcome.rejected);
      container.read(childRoutineProvider.notifier).toggle(routine: routine, card: c1);
      await drain();

      final state = container.read(childRoutineProvider);
      expect(state.progress.containsKey('r1'), isFalse);
      expect(state.pending, isEmpty);
      expect(ProgressStore(storage).load('r1'), isNull);
      // 로컬이 없으니 서버 값(미완료)으로 보인다
      expect(state.isChecked('r1', c1), isFalse);
    });
  });

  group('재시작 — hydrate로 복원한다', () {
    test('저장된 기록과 대기열이 상태로 돌아온다', () async {
      final storage = InMemoryStorage(onboardingCompleted: true);
      final store = ProgressStore(storage);
      await store.save('r1', const RoutineProgressRecord(completed: {'c1', 'c2'}, rewarded: {'c1'}));
      await store.setPending({'r1'});

      final (:container, repo: _, storage: _) = setUp(outcome: SyncOutcome.unreachable, storage: storage);
      await container.read(childRoutineProvider.notifier).hydrate();
      await drain();

      final state = container.read(childRoutineProvider);
      expect(state.isChecked('r1', c2), isTrue);
      expect(state.hasRewarded('r1', 'c1'), isTrue);
      expect(state.pending, contains('r1'));
    });

    test('hydrate 직후 대기열 동기화를 시도한다', () async {
      final storage = InMemoryStorage(onboardingCompleted: true);
      final store = ProgressStore(storage);
      await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));
      await store.setPending({'r1'});

      final (:container, :repo, storage: _) = setUp(storage: storage);
      await container.read(childRoutineProvider.notifier).hydrate();
      await drain();

      expect(repo.lastSent, {'c1'});
      expect(container.read(childRoutineProvider).pending, isEmpty);
    });
  });

  group('동기화 중 추가 조작', () {
    test('전송 중에 또 체크하면 대기열이 유지되고 최신 집합이 다시 간다', () async {
      final (:container, :repo, storage: _) = setUp();
      repo.hold = true;
      final notifier = container.read(childRoutineProvider.notifier);

      notifier.toggle(routine: routine, card: c1); // 전송 시작(대기)
      await drain();
      notifier.toggle(routine: routine, card: c2); // 전송 중 추가
      repo.releaseAll();
      await drain();
      repo.releaseAll();
      await drain();

      expect(repo.sent.last, {'c1', 'c2'});
      expect(container.read(childRoutineProvider).pending, isEmpty);
    });
  });

  group('보상 규칙', () {
    test('처음 체크하면 보상, 해제 후 재체크는 보상 없음', () async {
      final (:container, repo: _, storage: _) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      expect(notifier.toggle(routine: routine, card: c1), isTrue);
      expect(notifier.toggle(routine: routine, card: c1), isFalse);
      expect(notifier.toggle(routine: routine, card: c1), isFalse);
      await drain();

      expect(container.read(childRoutineProvider).hasRewarded('r1', 'c1'), isTrue);
    });
  });
}

/// 서버 대신 전송된 집합을 기록하는 가짜 저장소.
class _FakeSyncRepo extends StepProgressRepository {
  _FakeSyncRepo({required this.outcome}) : super(dio: Dio());

  SyncOutcome outcome;
  bool hold = false;
  final sent = <Set<String>>[];
  final _pending = <Completer<void>>[];

  Set<String>? get lastSent => sent.isEmpty ? null : sent.last;

  @override
  Future<SyncOutcome> syncProgress({
    required String routineId,
    required Set<String> completedStepIds,
  }) async {
    sent.add(Set.of(completedStepIds));
    if (hold) {
      final c = Completer<void>();
      _pending.add(c);
      await c.future;
    }
    return outcome;
  }

  void releaseAll() {
    for (final c in _pending) {
      if (!c.isCompleted) c.complete();
    }
    _pending.clear();
  }
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd client && flutter test test/child_step_sync_test.dart 2>&1 | tail -3`
Expected: 컴파일 에러 — `hydrate`, `syncPending`, `isChecked(String, ActionCard)` 없음

- [ ] **Step 3: notifier 전체 교체** — `child_routine_notifier.dart`

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';
import '../../guardian/data/routine_repository.dart';
import '../data/progress_store.dart';
import '../data/step_progress_repository.dart';
import '../domain/routine_progress_record.dart';

/// 아이 모드에서 보는 일과 진행 상태 (오프라인 퍼스트, 이슈 #140).
///
/// **기기가 진실이다.** [progress]에 기록이 있는 일과는 서버 `completed`를 무시하고
/// 기록을 보여준다. 기록이 없는 일과만 서버 값을 쓴다. 서버 반영이 안 끝난 일과는
/// [pending]에 남아 있다가 다음 기회에 다시 전송된다.
class ChildRoutineState {
  const ChildRoutineState({
    this.progress = const {},
    this.pending = const {},
  });

  /// routineId → 로컬 진행 기록.
  final Map<String, RoutineProgressRecord> progress;

  /// 서버 반영이 아직 안 끝난 routineId.
  final Set<String> pending;

  ChildRoutineState copyWith({
    Map<String, RoutineProgressRecord>? progress,
    Set<String>? pending,
  }) {
    return ChildRoutineState(
      progress: progress ?? this.progress,
      pending: pending ?? this.pending,
    );
  }

  /// 화면에 체크로 보이는가. 로컬 기록이 있으면 그것이, 없으면 서버 값이 기준이다.
  bool isChecked(String routineId, ActionCard card) {
    final record = progress[routineId];
    if (record == null) return card.completed;
    return record.completed.contains(card.id);
  }

  bool hasRewarded(String routineId, String cardId) =>
      progress[routineId]?.rewarded.contains(cardId) ?? false;
}

final childRoutineProvider =
    NotifierProvider<ChildRoutineNotifier, ChildRoutineState>(
  ChildRoutineNotifier.new,
);

class ChildRoutineNotifier extends Notifier<ChildRoutineState> {
  /// 서버 전송 체인. 한 번에 하나씩, 큐에 넣은 순서대로 보낸다.
  Future<void> _syncChain = Future<void>.value();

  /// 체인에 이미 들어가 대기 중인 routineId. 같은 일과를 연타해도 한 번만 줄 선다 —
  /// 전송 시점에 최신 집합을 읽으므로 한 번이면 충분하다.
  final Set<String> _queued = {};

  @override
  ChildRoutineState build() => const ChildRoutineState();

  ProgressStore get _store => ref.read(progressStoreProvider);

  /// 앱 시작 시 저장된 기록·대기열을 복원하고 곧바로 동기화를 시도한다.
  Future<void> hydrate() async {
    final pending = _store.pending;
    final progress = <String, RoutineProgressRecord>{};
    for (final id in pending) {
      final record = _store.load(id);
      if (record != null) progress[id] = record;
    }
    state = state.copyWith(progress: progress, pending: pending);
    syncPending();
  }

  /// 카드 체크를 토글하고, **보상을 띄워야 하면 true**를 돌려준다.
  ///
  /// 순서 제한은 없다 — 서버 일괄 반영 API가 순서를 검사하지 않는다(스펙 확정).
  /// 즉시 로컬에 반영·저장하고 서버 전송은 뒤에서 따라온다.
  ///
  /// 보상은 "처음 완료로 바뀔 때" 한 번만이다. 해제했다 다시 체크해도 안 준다.
  bool toggle({required Routine routine, required ActionCard card}) {
    final current = state.progress[routine.id] ?? _fromServer(routine);
    final wasChecked = current.completed.contains(card.id);

    final completed = Set<String>.from(current.completed);
    wasChecked ? completed.remove(card.id) : completed.add(card.id);

    final shouldReward = !wasChecked && !current.rewarded.contains(card.id);
    final record = current.copyWith(
      completed: completed,
      rewarded: shouldReward ? {...current.rewarded, card.id} : current.rewarded,
    );

    final isServerRoutine = routine.id.isNotEmpty && routine.id != 'local';
    state = state.copyWith(
      progress: {...state.progress, routine.id: record},
      pending: isServerRoutine ? {...state.pending, routine.id} : state.pending,
    );

    // 저장은 기다리지 않는다 — 아동이 누르는 즉시 화면이 바뀌어야 한다
    unawaited(_persist(routine.id, record));
    if (isServerRoutine) _enqueue(routine.id);

    return shouldReward;
  }

  /// 대기열 전체를 다시 전송한다. 앱 시작·복귀·온라인 전환 시 호출된다.
  void syncPending() {
    for (final id in state.pending) {
      _enqueue(id);
    }
  }

  /// 로컬 기록이 없을 때의 출발점 — 서버가 준 완료 상태를 그대로 옮긴다.
  RoutineProgressRecord _fromServer(Routine routine) => RoutineProgressRecord(
        completed: routine.steps.where((s) => s.completed).map((s) => s.id).toSet(),
      );

  Future<void> _persist(String routineId, RoutineProgressRecord record) async {
    await _store.save(routineId, record);
    await _store.setPending(state.pending);
  }

  void _enqueue(String routineId) {
    if (!_queued.add(routineId)) return;
    _syncChain = _syncChain.then((_) => _sync(routineId));
  }

  Future<void> _sync(String routineId) async {
    _queued.remove(routineId);
    final record = state.progress[routineId];
    if (record == null) {
      await _clearPending(routineId);
      return;
    }

    // 전송한 집합을 기억해 둔다. 응답을 기다리는 동안 또 체크됐으면 그건 아직
    // 서버에 없는 것이므로 대기열에서 빼지 않는다.
    final sent = Set<String>.from(record.completed);
    final outcome = await ref
        .read(stepProgressRepositoryProvider)
        .syncProgress(routineId: routineId, completedStepIds: sent);

    // 응답을 기다리는 동안 provider가 내려갔을 수 있다(테스트 teardown 등).
    if (!ref.mounted) return;

    switch (outcome) {
      case SyncOutcome.accepted:
        final latest = state.progress[routineId]?.completed ?? const <String>{};
        if (setEquals(latest, sent)) {
          await _clearPending(routineId);
        } else {
          // 전송 중 바뀌었다 — 최신 집합을 다시 보낸다
          _enqueue(routineId);
        }
        _refreshLists();
      case SyncOutcome.rejected:
        // 서버가 이 상태를 거부했다(승인 전·삭제 등). 기기 기록을 버리고 서버 값으로 돌아간다.
        debugPrint('[sync] 서버 거부 — 로컬 기록 폐기: $routineId');
        final progress = Map<String, RoutineProgressRecord>.from(state.progress)..remove(routineId);
        state = state.copyWith(progress: progress);
        await _store.remove(routineId);
        await _clearPending(routineId);
        _refreshLists();
      case SyncOutcome.unreachable:
        // 그대로 둔다. 다음 트리거(복귀·온라인 전환·조작)에서 다시 보낸다.
        debugPrint('[sync] 서버에 닿지 못함 — 대기열 유지: $routineId');
    }
  }

  Future<void> _clearPending(String routineId) async {
    if (!state.pending.contains(routineId)) return;
    state = state.copyWith(pending: {...state.pending}..remove(routineId));
    await _store.setPending(state.pending);
  }

  /// 목록이 서버 진실(진행률·별)을 다시 읽게 한다.
  void _refreshLists() {
    ref.invalidate(todayRoutinesProvider);
    ref.invalidate(myRoutinesProvider);
  }

  /// 새 일과를 시작할 때 화면 상태만 초기화한다. 저장소는 건드리지 않는다.
  void reset() => state = const ChildRoutineState();
}
```

- [ ] **Step 4: `child_mode_test.dart` 보상 조건 그룹 갱신** — `'보상 조건'` 그룹 안의 두 테스트만 수정

`'해제해도 보상 이력은 남는다'`의 검증 두 줄을:

```dart
      final state = container.read(childRoutineProvider);
      expect(state.isChecked('local', c1), isFalse);
      expect(state.hasRewarded('local', 'c1'), isTrue);
```

`'새 일과를 시작하면 초기화된다'`의 첫 검증을:

```dart
      expect(container.read(childRoutineProvider).progress, isEmpty);
```

- [ ] **Step 5: 화면 컴파일이 깨진 상태이므로 Task 7까지 한 뒤에 테스트를 돌린다.** 여기서는 notifier·테스트 파일만 analyze한다.

Run: `cd client && flutter analyze lib/features/child/application/child_routine_notifier.dart test/child_step_sync_test.dart 2>&1 | tail -3`
Expected: 이 두 파일에 에러 없음 (`setEquals`는 `package:flutter/foundation.dart`에 있다)

- [ ] **Step 6: 커밋은 Task 7과 함께**

---

### Task 7: 클라이언트 — 화면 정리 (순서 제한 제거, `.value` 깜빡임 수정)

**Files:**
- Modify: `client/lib/features/child/presentation/child_routine_detail_screen.dart`
- Modify: `client/lib/features/child/presentation/child_home_screen.dart`
- Modify: `client/lib/features/guardian/presentation/widgets/today_routine_section.dart`

**Interfaces:**
- Consumes: Task 6 `ChildRoutineState.isChecked(routineId, card)`

- [ ] **Step 1: `today_routine_section.dart`**

`homeRoutinesProvider`의 `fetched` 줄을 교체 — 재조회 중에도 이전 목록을 유지한다:

```dart
  // `.value`는 재조회(invalidate) 중에도 직전 값을 준다. `asData`를 쓰면 동기화 뒤
  // 목록을 다시 읽는 동안 화면이 순간 비어 보인다 (이슈 #140).
  final fetched = ref.watch(myRoutinesProvider).value ?? const <Routine>[];
```

`routineProgress` 함수 본문:

```dart
double routineProgress(Routine routine, ChildRoutineState progress) {
  if (routine.steps.isEmpty) return 0;
  final done = routine.steps.where((s) => progress.isChecked(routine.id, s)).length;
  return done / routine.steps.length;
}
```

`_ExpandedRoutine`의 `_CardRow` 호출:

```dart
              isDone: progress.isChecked(routine.id, card),
```

- [ ] **Step 2: `child_home_screen.dart`** — `childRoutinesProvider`의 `fetched` 줄 교체

```dart
  final fetched =
      ref.watch(todayRoutinesProvider).value ?? const <Routine>[];
```

- [ ] **Step 3: `child_routine_detail_screen.dart`** — 순서 제한 제거

`_isCardChecked` 교체:

```dart
  /// [card]가 지금 체크된 상태인지. 기기 기록이 서버 값보다 우선한다.
  bool _isCardChecked(ActionCard card) =>
      ref.read(childRoutineProvider).isChecked(widget.routine.id, card);
```

`_toggle` 안의 "순서 규칙에 걸려 아무것도 바뀌지 않았다" 주석과 `if (_isCardChecked(card) == wasChecked) return;` 두 줄을 **삭제**한다 (이제 토글은 항상 바뀐다).

`build()`에서 `final notifier = ref.read(childRoutineProvider.notifier);` 줄을 **삭제**하고, `_CheckButton` 호출에서 `isEnabled:` 인자와 그 위 주석 두 줄을 **삭제**한다:

```dart
              return _CheckButton(
                isChecked: progress.isChecked(routine.id, current),
                confettiController: _confetti,
                onTap: () => _toggle(current),
              );
```

`_CheckButton`에서 `isEnabled` 필드·생성자 인자·주석을 삭제하고, `AnimatedOpacity` 래핑을 풀어 `return Stack(` 으로 되돌린다 (닫는 괄호도 `],\n    );` 로).

- [ ] **Step 4: 포맷·분석·테스트**

Run:
```bash
cd client && dart format lib/features/child lib/features/guardian/presentation/widgets/today_routine_section.dart lib/features/guardian/data/routine_repository.dart lib/core/storage/local_storage.dart lib/shared/models/routine.dart test/child_step_sync_test.dart test/child_mode_test.dart test/progress_store_test.dart test/routine_cache_test.dart
flutter analyze 2>&1 | grep -E "child_|progress_store|routine_cache|routine_repository|local_storage|today_routine_section|routine.dart" ; echo "(없으면 OK)"
flutter test test/child_step_sync_test.dart test/child_mode_test.dart test/progress_store_test.dart test/routine_cache_test.dart test/guardian_home_screen_test.dart 2>&1 | tail -3
```
Expected: analyze에 변경 파일 에러 없음, `All tests passed!`

- [ ] **Step 5: 커밋 (Task 5·6·7 묶음)**

```bash
git add client/lib/features/child/data/step_progress_repository.dart client/lib/features/child/application/child_routine_notifier.dart client/lib/features/child/presentation/child_routine_detail_screen.dart client/lib/features/child/presentation/child_home_screen.dart client/lib/features/guardian/presentation/widgets/today_routine_section.dart client/test/child_step_sync_test.dart client/test/child_mode_test.dart
git commit -m "카드 완료 상태 오프라인 퍼스트 동기화 : feat : 아동 카드 체크를 기기 기록 기준으로 바꾸고 완료 집합을 PUT /progress로 직렬 전송(못 닿으면 대기열 유지·거부되면 서버 값 복귀), 순서 제한 제거, 재조회 중 목록 깜빡임 수정 https://github.com/Twin-Fang/elum/issues/140"
```

---

### Task 8: 클라이언트 — 동기화 트리거 (`connectivity_plus` · 앱 시작·복귀·온라인 전환)

**Files:**
- Modify: `client/pubspec.yaml`
- Create: `client/lib/features/child/application/sync_triggers.dart`
- Modify: `client/lib/app.dart`
- Test: `client/test/sync_triggers_test.dart`

**Interfaces:**
- Consumes: Task 6 `hydrate()`, `syncPending()`
- Produces: `SyncTriggers({required Widget child})` 위젯

- [ ] **Step 1: 의존성 추가**

Run: `cd client && flutter pub add connectivity_plus 2>&1 | tail -3 && cd ios && pod install 2>&1 | tail -2`
Expected: `pubspec.yaml`에 `connectivity_plus: ^<버전>` 추가, `Podfile.lock` 갱신. build hook 경고가 나면 [트러블슈팅 "build_runner AOT 컴파일 실패"](../../client/docs/troubleshooting.md)를 확인한다.

- [ ] **Step 2: 실패하는 테스트 작성** — `client/test/sync_triggers_test.dart`

```dart
import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/application/sync_triggers.dart';
import 'package:elum/features/child/data/progress_store.dart';
import 'package:elum/features/child/data/step_progress_repository.dart';
import 'package:elum/features/child/domain/routine_progress_record.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 동기화 트리거 (이슈 #140) — 앱 시작 시 복원·전송, 복귀 시 재전송.
///
/// 온라인 전환(connectivity_plus)은 플랫폼 채널이라 위젯 테스트로 고정하지 않는다.
/// 대신 이벤트 발생 시 호출되는 경로가 복귀 경로와 같음을 코드로 보장한다.
void main() {
  testWidgets('시작하면 저장된 대기열을 복원하고 전송한다', (tester) async {
    final storage = InMemoryStorage(onboardingCompleted: true);
    final store = ProgressStore(storage);
    await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));
    await store.setPending({'r1'});
    final repo = _CountingRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          stepProgressRepositoryProvider.overrideWithValue(repo),
          todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        ],
        child: const SyncTriggers(child: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.calls, 1);
    final container = ProviderScope.containerOf(tester.element(find.byType(SyncTriggers)));
    expect(container.read(childRoutineProvider).pending, isEmpty);
  });

  testWidgets('백그라운드에서 돌아오면 대기열을 다시 전송한다', (tester) async {
    final storage = InMemoryStorage(onboardingCompleted: true);
    final store = ProgressStore(storage);
    await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));
    await store.setPending({'r1'});
    final repo = _CountingRepo(outcome: SyncOutcome.unreachable);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          stepProgressRepositoryProvider.overrideWithValue(repo),
          todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        ],
        child: const SyncTriggers(child: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, 1); // 시작 시 1회 — 실패해서 대기열 유지

    repo.outcome = SyncOutcome.accepted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
  });
}

class _CountingRepo extends StepProgressRepository {
  _CountingRepo({this.outcome = SyncOutcome.accepted}) : super(dio: Dio());

  SyncOutcome outcome;
  int calls = 0;

  @override
  Future<SyncOutcome> syncProgress({
    required String routineId,
    required Set<String> completedStepIds,
  }) async {
    calls++;
    return outcome;
  }
}
```

- [ ] **Step 3: 실패 확인**

Run: `cd client && flutter test test/sync_triggers_test.dart 2>&1 | tail -3`
Expected: 컴파일 에러 — `sync_triggers.dart` 없음

- [ ] **Step 4: `SyncTriggers` 생성** — `client/lib/features/child/application/sync_triggers.dart`

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'child_routine_notifier.dart';

/// 카드 진행 동기화를 언제 다시 시도할지 정하는 위젯 (이슈 #140).
///
/// 화면 트리 최상단에 한 번만 둔다. 세 시점에 [ChildRoutineNotifier.syncPending]을 부른다.
/// 1. 앱 시작 — 저장된 기록을 복원([hydrate])하고 곧바로 전송
/// 2. 백그라운드에서 돌아올 때
/// 3. 네트워크가 오프라인 → 온라인으로 바뀔 때 (짧은 debounce로 이벤트 폭주 방어)
///
/// 카드 조작 직후 전송은 notifier 안에서 하므로 여기서 다루지 않는다.
class SyncTriggers extends ConsumerStatefulWidget {
  const SyncTriggers({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<SyncTriggers>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _debounce;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 첫 프레임 뒤에 복원한다 — build 중 provider 상태를 바꾸면 안 된다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(childRoutineProvider.notifier).hydrate());
    });

    // 위젯 테스트에는 플랫폼 채널이 없어 스트림이 열리지 않는다 — 실패해도 앱은 뜬다.
    try {
      _connectivity = Connectivity().onConnectivityChanged.listen(_onConnectivity);
    } catch (_) {
      _connectivity = null;
    }
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!isOnline) {
      _wasOffline = true;
      return;
    }
    // 온라인이 됐을 때만, 그것도 오프라인을 거친 뒤에만 보낸다.
    // 시작 직후 온라인 이벤트는 hydrate가 이미 처리한다.
    if (!_wasOffline) return;
    _wasOffline = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) ref.read(childRoutineProvider.notifier).syncPending();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(childRoutineProvider.notifier).syncPending();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

- [ ] **Step 5: `app.dart`에 부착** — `builder` 안에서 `DevToolsOverlay`를 감싼다

import 추가: `import 'features/child/application/sync_triggers.dart';`

```dart
        builder: (context, child) => SyncTriggers(
          // 동기화 트리거는 라우터·오버레이와 무관하므로 가장 바깥에 둔다 (이슈 #140)
          child: DevToolsOverlay(
            onNavigate: _router.go,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `cd client && flutter test test/sync_triggers_test.dart 2>&1 | tail -3`
Expected: `All tests passed!`. 위젯 테스트에서 `Connectivity()`가 `MissingPluginException`을 던지면 try/catch가 흡수한다 — 그래도 실패하면 `_connectivity` 구독을 `WidgetsBinding.instance.addPostFrameCallback` 안으로 옮기고 다시 확인한다.

- [ ] **Step 7: 커밋**

```bash
git add client/pubspec.yaml client/pubspec.lock client/ios/Podfile.lock client/lib/features/child/application/sync_triggers.dart client/lib/app.dart client/test/sync_triggers_test.dart
git commit -m "카드 완료 상태 오프라인 퍼스트 동기화 : feat : 앱 시작·복귀·온라인 전환 시 대기열을 재전송하는 SyncTriggers 추가 (connectivity_plus) https://github.com/Twin-Fang/elum/issues/140"
```

> `ios/Podfile.lock`은 `pod install`이 바뀐 경우에만 스테이징한다. Android `build.gradle`·`Info.plist` 변경은 필요 없다(connectivity_plus는 권한이 없다).

---

### Task 9: 전체 검증 · 문서 · 마무리

**Files:**
- Modify: `client/docs/troubleshooting.md` (이슈 #139 항목의 "근본 구조 개선" 문장)
- Modify: `client/CLAUDE.md` (`/api/routines` 계약 표에 한 줄)

- [ ] **Step 1: 전체 테스트**

Run:
```bash
cd server && ./gradlew test -q 2>&1 | tail -3
cd ../client && flutter test 2>&1 | tail -2
```
Expected: 서버 출력 없음(통과). 클라이언트는 기존 결함 4건(`app_transitions`·`pin_screen`·`setup_done_screen` 로드 실패, `design_token` 색 하드코딩)만 실패하고 **새 실패가 없어야** 한다. 새 실패가 있으면 그 파일을 고친다.

- [ ] **Step 2: 로컬 iOS 빌드로 새 패키지가 빌드를 깨지 않는지 확인**

Run: `cd client && flutter build ios --release --no-codesign 2>&1 | tail -3`
Expected: `✓ Built build/ios/iphoneos/Runner.app`

- [ ] **Step 3: 문서 갱신**

`client/CLAUDE.md`의 `/api/routines` 계약 표 마지막 행 아래에:

```markdown
| PUT | `/api/routines/{id}/progress` | **완료 집합 통째 반영** (오프라인 퍼스트 동기화, 멱등) |
```

`client/docs/troubleshooting.md` 이슈 #139 항목의 마지막 줄 `- 근본 구조 개선(...)은 이슈 #140에서 다룬다`를 다음으로 교체:

```markdown
- 근본 구조 개선은 이슈 #140에서 완료했다 — 기기 기록이 진실, 완료 집합을 `PUT /progress`로 멱등 반영, 대기열로 오프라인 재전송. 순서 제한(`canToggle`)은 서버 규칙 완화와 함께 제거됐다.
```

- [ ] **Step 4: 커밋**

```bash
git add client/CLAUDE.md client/docs/troubleshooting.md
git commit -m "docs: 오프라인 퍼스트 동기화 API 계약과 트러블슈팅 후속 기록 갱신 (#140)"
```

- [ ] **Step 5: 이후 파이프라인** — 푸시 → main 최신화 → `/pro-changelog-deploy` → 배포 후 서버 로그로 `PUT /progress` 200 확인 → `/pro-report` 보고서 댓글 → 라벨 `작업완료`. (이 단계는 계획 실행자가 아니라 세션 파이프라인이 수행한다.)

---

## Self-Review

**Spec coverage**
- 서버 PUT progress 멱등·별 차이·상태 전이·순서 무관·404/409 → Task 1·2 ✅
- 로컬 진행 기록·대기열·캐시 저장 → Task 3 ✅ / 오늘 일과 캐시 폴백 → Task 4 ✅
- `SyncOutcome` 3분기 → Task 5·6 ✅ / hydrate·syncPending·직렬 전송·전송 중 변경 처리 → Task 6 ✅
- 순서 제한 제거·`.value` 깜빡임 → Task 7 ✅ / 트리거 4종(시작·복귀·온라인·조작) → Task 8(+Task 6 조작) ✅
- 실패 경로 표(오프라인 체크·재시작·5xx·404/409·캐시 없음) → Task 4·6 테스트로 고정 ✅

**Type consistency**
- `isChecked(String routineId, ActionCard card)` — Task 6 정의, Task 7 사용 ✅
- `SyncOutcome.accepted/rejected/unreachable` — Task 5 정의, Task 6·8 테스트 사용 ✅
- `ProgressStore.load/save/remove/pending/setPending` — Task 3 정의, Task 6·8 사용 ✅
- `RoutineRepositoryImpl({dio, storage})` — Task 4 정의·테스트 ✅
