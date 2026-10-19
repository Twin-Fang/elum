# 온보딩 예시 일과 Implementation Plan (#803)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 온보딩 목표 화면을 일과 분류 선택으로 바꾸고, 고른 분류의 예시 일과를 AI 없이 실제 일과로 넣는다.

**Architecture:** 예시 원본(분류·문장 ko/en·픽토그램)은 서버 상수 카탈로그 하나. 클라는 분류 코드만 보내고(`POST /api/routines/examples`), 서버가 `duplicate` 선례대로 `CONFIRMED` 일과를 만든다. 클라는 고른 분류를 저장소에 "대기"로 두고 보호자 홈 진입 시 한 곳에서 생성 요청을 보낸다(재시도 1회).

**Tech Stack:** Spring Boot · JPA · Flyway / Flutter · Riverpod · go_router · ARB

**Spec:** `docs/superpowers/specs/2026-10-19-onboarding-example-routines-design.md`

## Global Constraints

- AI·크레딧을 쓰지 않는다. 그림은 Mulberry 픽토그램 id (서버 `pictograms/catalog.json` 에 있어야 함)
- 예시 일과: `CONFIRMED`, 오늘 날짜 + 일과별 시각, `is_example = true`, 다음 날 `지난 일과`로 가는 것은 정상
- 언어: 콘텐츠 언어가 ko 면 ko 문장·`KO`, 그 외는 en 문장·`EN`
- 보유 한도(`ROUTINE_MAX_COUNT`) 검사·집계에서 예시 제외
- 같은 프로필에 예시가 이미 있으면 아무것도 만들지 않고 200 + 빈 목록
- 화면 문구: 해요체, `아이` 금지, 이룸이. 5개 ARB(ko·en·ja·zh·es) 모두 채움
- 예시 생성 실패가 온보딩·홈을 막지 않는다. 실패는 에러 코드 `E-EXAMPLE` 스낵바
- 서버 로그 영어, 기능 접두사 `[routine example]`

## Review Focus

1. 온보딩을 두 번 마치거나 홈을 여러 번 열 때 예시가 두 벌 생김 → 서버 멱등 테스트 + 클라는 성공 시 대기값 삭제 테스트 (Task 3, 6)
2. 오프라인으로 온보딩 완료 → 홈이 로딩에 갇힘 → 실패 시 홈 목록은 그대로, 스낵바만 (Task 6)
3. 앱 업데이트로 분류 코드가 서버와 어긋남(400) → 재시도 없이 대기값 삭제 (Task 6)
4. 건너뛰기 후 생성 요청이 나감 → 대기값 없음 테스트 (Task 5)
5. 이룸이 기기에서 예시 일과가 안 보임(`CONFIRMED`·오늘 날짜 아님) → 서비스 테스트에서 상태·날짜 단언 (Task 3)

---

### Task 1: 서버 예시 카탈로그

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutineExampleCatalog.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutineExampleCatalogTest.java`

**Interfaces:**
- Produces:
  - `enum RoutineExampleCategory { MORNING_EVENING, SCHOOL_STUDY, HOUSE_SELF, OUTSIDE }` (같은 패키지 파일 `RoutineExampleCategory.java`)
  - `record RoutineExample(RoutineExampleCategory category, String titleKo, String titleEn, LocalTime scheduledTime, List<RoutineExampleStep> steps)`
  - `record RoutineExampleStep(String textKo, String textEn, String pictogramId)`
  - `RoutineExampleCatalog.ALL : List<RoutineExample>` (분류 순서 → 예시 순서), `RoutineExampleCatalog.of(RoutineExampleCategory) : List<RoutineExample>`

- [ ] **Step 1: 실패 테스트** — `RoutineExampleCatalogTest`
  - `everyCategoryHasTwoExamples` : 4개 분류 모두 `of(c).size() == 2`
  - `everyPictogramIdExistsInCatalog` : `new PictogramCatalog()` 로 실제 `catalog.json` 을 읽어 모든 `pictogramId` 가 `contains`
  - `noBlankText` : 제목·카드 문장 ko/en 이 비어 있지 않음, 카드 3장 이상
- [ ] **Step 2:** `./gradlew test --tests '*RoutineExampleCatalogTest'` → 컴파일 실패
- [ ] **Step 3: 카탈로그 작성** — 스펙 §4 표의 8개 예시·문장·id 그대로, 시각은 §5.1. 영어 문장은 짧은 현재형 명령문(예: `Fold the blanket`, `Go to the toilet`, `Brush your teeth`)
- [ ] **Step 4:** 같은 테스트 PASS
- [ ] **Step 5: Commit** (`/pro-commit`)

### Task 2: `is_example` 컬럼 · 응답 필드 · 한도 제외

**Files:**
- Create: `server/src/main/resources/db/migration/V42__add_routine_is_example.sql`
- Modify: `routine/infrastructure/entity/Routine.java` (필드 `isExample`), `routine/application/dto/response/RoutineResponse.java` (`Boolean isExample` 를 `language` 뒤에 추가, `from`·`with*` 모두 전달), `routine/infrastructure/repository/RoutineRepository.java`, `routine/application/service/RoutineQuotaGuard.java:122-133`
- Test: 기존 `RoutineQuotaGuard` 테스트 파일에 케이스 추가 (없으면 `RoutineQuotaGuardTest` 생성)

**Interfaces:**
- Produces: `Routine#setIsExample(boolean)`/`getIsExample()`; `RoutineRepository.countByCreatedByAndIsExampleFalse(String)`; `RoutineRepository.existsByProfileIdAndIsExampleTrue(String)`; JSON `isExample: boolean`

- [ ] **Step 1: 실패 테스트** — `ownedCountExcludesExamples`: 한도 1, 예시 2개 + 일반 0개인 보호자가 `guard` 통과 (리포지토리 목은 `countByCreatedByAndIsExampleFalse` 0 반환)
- [ ] **Step 2:** 실행 → 실패
- [ ] **Step 3:** 마이그레이션 `ALTER TABLE routine ADD COLUMN IF NOT EXISTS is_example BOOLEAN NOT NULL DEFAULT FALSE;` (V40 머리 주석 형식), 엔티티 `@Column(name = "is_example", nullable = false, columnDefinition = "boolean not null default false") private Boolean isExample = false;`, 한도 집계 메서드 교체. 테이블명은 엔티티 매핑 확인 후 맞춤
- [ ] **Step 4:** `./gradlew test` 전체 PASS (응답 생성자 시그니처 변경으로 깨지는 테스트 함께 수정)
- [ ] **Step 5: Commit**

### Task 3: 예시 생성 서비스 · API

**Files:**
- Create: `routine/application/service/RoutineExampleService.java`, `routine/application/dto/request/RoutineExampleCreateRequest.java`
- Modify: `RoutineController.java` (엔드포인트), `RoutineCreationDocs.java` (문서 메서드)
- Test: `server/src/test/java/.../routine/application/service/RoutineExampleServiceTest.java`

**Interfaces:**
- Consumes: Task 1 카탈로그, Task 2 리포지토리 메서드
- Produces: `POST /api/routines/examples` 헤더 `X-Profile-Id`, 본문 `{"categories": ["MORNING_EVENING"]}` → `200 List<RoutineResponse>`; `RoutineExampleService.create(Caller, List<String> categoryCodes) : List<RoutineResponse>`

처리: 검증 > 이미 만들었는지 확인 > 분류별 예시 생성 > 응답

- [ ] **Step 1: 실패 테스트** (`RoutineExampleServiceTest`, 기존 `RoutineServiceTest` 의 목 구성 방식 따름)
  - `createsTwoConfirmedExamplesPerCategory` : 분류 2개 → 4개 저장, 모두 `CONFIRMED`, `isExample`, `scheduledAt` 날짜가 오늘, 시각이 카탈로그 값, 카드 순서·`pictogramId` 일치, `createdBy` = 호출자
  - `koreanContentLocaleUsesKoreanText` / `otherContentLocaleUsesEnglishText` (ja 요청 → `EN`·영문)
  - `secondCallCreatesNothing` : `existsByProfileIdAndIsExampleTrue` true → 빈 목록, `save` 호출 없음
  - `rejectsEmptyOrUnknownCategory` : 빈 목록·`"FOO"` → `CustomException(INVALID_INPUT_VALUE)`
  - `duplicateCategoryCodesCreatedOnce` : `["OUTSIDE","OUTSIDE"]` → 2개
  - `noCreditOrQuotaCall` : 크레딧·한도 목과 상호작용 없음
- [ ] **Step 2:** 실행 → 실패
- [ ] **Step 3: 구현** — 프로필은 `profileAccessGuard.profileFor(caller, ProfileAction.MANAGE)`, 언어는 `enabledLocales.resolveContentLocale(CurrentLocale.get())` 결과가 `KO` 면 KO 아니면 EN. 일과 필드는 `RoutineService.duplicate` (74-112) 와 같게 채우고(`rawInputText`·`sanitizedInputText` = 제목), `displayOrder` 는 `maxDisplayOrder + 순번`. 저장 후 `routineStepSpeechQueue.enqueueAfterCommit`. `@Transactional`. 컨트롤러는 `routineAuthorResolver.forCaller` 로 감싸 반환, `@LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)`
- [ ] **Step 4:** `./gradlew test` PASS
- [ ] **Step 5: Commit**

### Task 4: 클라 모델 · 리포지토리 · 분류 enum · 문구

**Files:**
- Create: `client/lib/shared/models/routine_example_category.dart`
- Modify: `client/lib/shared/models/routine.dart` (`@Default(false) bool isExample`, fromJson·toJson), `features/guardian/data/routine_repository.dart` · `routine_repository_impl.dart`, ARB 5개 + `flutter gen-l10n`
- Test: `client/test/routine_example_category_test.dart`, `client/test/routine_model_test.dart`(있으면 추가, 없으면 생성)

**Interfaces:**
- Produces:
  - `enum RoutineExampleCategory { morningEvening('MORNING_EVENING'), schoolStudy('SCHOOL_STUDY'), houseSelf('HOUSE_SELF'), outside('OUTSIDE') }` + `apiValue`, `label`, `hint`, `pictogramId`(카드 아이콘: `brush_teeth_,_to` · `school_bag` · `tidy_up_,_to` · `get_on_bus_,_to`), `static RoutineExampleCategory? fromApiValue(String?)`
  - `RoutineRepository.createExamples(List<String> categoryCodes) : Future<Attempt<List<Routine>>>`
  - ARB 키: `onboardingExampleTitle(name)` "{name}와 어떤 일과부터 해 볼까요?" · `onboardingExampleDescription` "고른 분류의 예시 일과를 넣어 둘게요. 여러 개 골라도 돼요." · `onboardingExampleSkip` "건너뛰기" · `exampleCategoryMorningEvening` "아침·저녁 준비" / `…Hint` "씻기, 옷 입기, 잠자리" · `exampleCategorySchoolStudy` "학교·공부" / "등교 준비, 숙제" · `exampleCategoryHouseSelf` "집안일·스스로 하기" / "정리, 식탁 차리기" · `exampleCategoryOutside` "밖에서 해 보기" / "버스 타기, 물건 사기" · `routineTileExampleBadge` "예시" · `exampleRoutinesFailed` "예시 일과를 넣지 못했어요"
  - 호칭 조사(와/과)는 기존 `onboardingGoalsTitle` 의 처리 방식을 그대로 따른다

- [ ] **Step 1: 실패 테스트** — `fromApiValue` 왕복·모르는 값 null · `Routine.fromJson({'isExample': true})` → true, 없거나 `"yes"` → false, `toJson` 왕복 유지
- [ ] **Step 2:** `flutter test test/routine_example_category_test.dart` → 실패
- [ ] **Step 3:** 구현 (`createExamples` 는 `duplicate` 구현 형식, 응답 리스트 파싱 실패는 `NetworkFault.app`)
- [ ] **Step 4:** PASS + `flutter analyze` 무경고
- [ ] **Step 5: Commit**

### Task 5: 분류 선택 화면 (목표 화면 교체)

**Files:**
- Create: `client/lib/features/onboarding/presentation/example_category_screen.dart`, `widgets/example_category_card.dart`
- Delete: `goals_screen.dart`, `widgets/goal_chip.dart`, `test/goals_screen_test.dart`
- Modify: `core/router/routes.dart` (`onboardingGoals` → `onboardingExampleCategories = '/onboarding/example-categories'`), `routes_entry.dart:65`, `core/dev/dev_tools_inspect.dart:254`, `name_screen.dart:50`, `onboarding/domain/onboarding_profile.dart` (`@Default(<RoutineExampleCategory>{}) Set<RoutineExampleCategory> exampleCategories` + `canProceedFromExampleCategories`), `onboarding_notifier.dart` (`toggleExampleCategory`, `clearExampleCategories`), `core/storage/shared_prefs_storage.dart` (`pendingExampleCategories` get/set, `exampleSeedAttempts` get/set), `test/figma_conformance_test.dart:1210,1421`
- Test: `client/test/example_category_screen_test.dart`

**Interfaces:**
- Produces: 저장소 키 `pendingExampleCategories`(List<String> apiValue), `exampleSeedAttempts`(int). 온보딩 `complete()` 가 상태의 분류를 `pendingExampleCategories` 에 쓰고 `exampleSeedAttempts` 를 0 으로 둔다(로컬 저장 블록 안). 건너뛰기면 빈 목록

- [ ] **Step 1: 실패 테스트**
  - `nextDisabledUntilOneSelected` · `multiSelectKeepsBoth` · `skipGoesToCharacterAndClearsSelection` · `nextGoesToCharacter`
  - `completeStoresPendingCategories` / `completeAfterSkipStoresEmpty` (notifier 테스트)
- [ ] **Step 2:** 실행 → 실패
- [ ] **Step 3:** 화면 구현 — `GoalsScreen` 골격(`ElumScaffold` · `ElumHeader` · `SelectableGroup(multiSelect: true)`) 재사용, 카드에 `PictogramArt` 아이콘 + 이름 + 힌트, 건너뛰기는 헤더 오른쪽 텍스트 버튼. 색·간격은 토큰만
- [ ] **Step 4:** `flutter test` 전체 PASS (골든은 Task 7 에서 갱신)
- [ ] **Step 5: Commit**

### Task 6: 홈 진입 시 예시 생성 · `예시` 표시

**Files:**
- Create: `client/lib/features/guardian/application/example_routine_seeder.dart`
- Modify: `features/guardian/presentation/guardian_home_screen.dart` (첫 프레임 후 1회 호출), `widgets/routine_summary_tile.dart` (제목 옆 `예시` 배지)
- Test: `client/test/example_routine_seeder_test.dart`, `client/test/routine_summary_tile_example_test.dart`

**Interfaces:**
- Consumes: Task 4 `createExamples`, Task 5 저장소 키
- Produces: `exampleRoutineSeederProvider`; `Future<ExampleSeedOutcome> seedPending()` — `enum ExampleSeedOutcome { nothingPending, created, failedWillRetry, failedGaveUp }`

처리: 대기값 없으면 끝 > 요청 > 성공·400 이면 대기값 삭제 > 그 외 실패면 시도 횟수 +1, 2회째면 삭제

- [ ] **Step 1: 실패 테스트**
  - `noPendingMakesNoCall` · `successClearsPendingAndRefreshesHome`(홈 목록 provider invalidate 확인) · `networkFailureKeepsPendingOnce` · `secondFailureGivesUp` · `badRequestGivesUpImmediately` · `emptyResponseCountsAsSuccess`
  - 타일: `isExample` 이면 `예시` 텍스트 보임, 아니면 없음
- [ ] **Step 2:** 실행 → 실패
- [ ] **Step 3:** 구현. 홈은 `failedWillRetry`·`failedGaveUp` 일 때 `ElumToast` 로 `exampleRoutinesFailed` + ` (E-EXAMPLE)` 1회. 세션 중 중복 호출 방지(진행 중 플래그). 배지 색은 기존 토큰(없으면 `colors` 에 `exampleBadgeBg`/`exampleBadgeText` 라이트·다크 추가)
- [ ] **Step 4:** PASS
- [ ] **Step 5: Commit**

### Task 7: 검증

- [ ] `cd server && ./gradlew test` 전체 PASS
- [ ] `cd client && flutter analyze && flutter test` 전체 PASS, 바뀐 골든(`--update-goldens` 대상: 분류 화면, 홈 타일) 갱신 후 이미지 직접 확인
- [ ] 로컬 서버 + 시뮬레이터로 신규 가입 → 분류 2개 → 홈에 예시 4개·`예시` 표시 → 하나 열어 카드 확인 → 건너뛰기 경로 확인 (라이트·다크 캡처)
- [ ] Commit
