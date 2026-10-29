# 카드 검토 코치마크 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카드 검토 화면 첫 진입 때 3단계 코치마크(수정 > 순서 변경 > 저장)를 한 번 띄우고, 상단바 `?` 로 다시 보게 한다.

**Architecture:** 홈 코치마크와 같은 구조. Notifier(단계·봤음 기록) + 루트 오버레이에 `CoachMarkOverlay` 를 그리는 위젯. 카드 검토 화면은 GlobalKey 3개와 시작 조건만 넘긴다.

**Tech Stack:** Flutter, Riverpod, flutter_screenutil, gen-l10n

**Spec:** `docs/superpowers/specs/2026-10-21-card-review-coach-mark-design.md`

## Global Constraints

- 문구(ko): 스펙 3장 표 그대로. `*강조*` 표기, 두 줄 이내.
- 봤음 저장 키: `coach.cardReviewSeen`. 읽기 실패 = 봤음.
- 카드 1장이면 `reorderCards` 단계 제외.
- 코치 중 뒤로가기는 안내만 닫는다 (나가기 팝업 금지).
- 자동 테스트 없음(#848). 검증은 analyze + iOS 시뮬레이터.
- `dart format` 을 디렉토리로 돌리지 않는다.

## Review Focus

- 코치 중 시스템 뒤로가기: 두 `PopScope` 가 모두 불려도 나가기 팝업이 안 떠야 한다.
- 코치 중 화면이 사라짐(알림 탭으로 다른 화면 이동): 상태가 켜진 채 남지 않아야 한다 (dispose 에서 finish).
- 순서 변경 모드 진입 상태·카드 0장: 띄우지 않는다.
- `?` 를 코치 진행 중에 누를 수 없다 (막이 덮음) — 중복 켜기 방어는 `isActive` 검사.
- 글자 크기 최대에서 말풍선이 버튼을 가리지 않는다 (기존 오버레이가 처리, 실측으로만 확인).

---

### Task 1: 봤음 기록 + Notifier

**Files:**
- Modify: `client/lib/core/storage/local_storage.dart`, `shared_prefs_storage.dart`, `in_memory_storage.dart`
- Create: `client/lib/features/guardian/application/card_review_coach_notifier.dart`

**Interfaces:**
- Produces: `bool get isCardReviewCoachSeen`, `Future<void> setCardReviewCoachSeen(bool isSeen)` (resetCoachMarks 에 포함, InMemory 기본 true)
- Produces: `enum CardReviewCoachStep { editCard, reorderCards, save }`, `CardReviewCoachState { steps, index, isActive, current }`, `cardReviewCoachProvider`, `CardReviewCoachNotifier.maybeStart({required int cardCount}) -> bool`, `.replay({required int cardCount})`, `.next()`, `.finish() -> Future<void>`

- [ ] 저장소 3곳에 키 추가 (기존 manage 키 옆)
- [ ] Notifier 작성 (`RoutineManageCoachNotifier` 규칙: `_hasShownThisRun`, 읽기 실패 = 봤음, finish 에서 기록)

### Task 2: 문구

**Files:** `client/lib/l10n/app_{ko,en,ja,zh,es}.arb`, 생성 파일 `app_localizations*.dart`

- [ ] 키 4개: `cardReviewCoachEdit`, `cardReviewCoachReorder`, `cardReviewCoachSave`, `cardReviewHelpLabel`(사용법 보기). ko 에 `@` 설명.
- [ ] `flutter gen-l10n`

### Task 3: 코치마크 위젯 + 화면 연결 + `?`

**Files:**
- Create: `client/lib/features/guardian/presentation/widgets/card_review_coach_mark.dart` — `CardReviewCoachMark({editKey, reorderKey, saveKey, cardCount, canStart})`: 시작 판단(라우트 맨 앞·전환 끝·추적 팝업 끝·canStart) + 오버레이
- Modify: `card_review_parts.dart` (`CardReviewToolRow` 에 `editKey`·`reorderKey`), `card_review_screen.dart` (키 3개, 위젯 배치, `onHelp`, 뒤로가기 가로채기), `routine_flow_scaffold.dart` (`onHelp`, `shouldIgnoreSystemBack`), `routine_flow_top_bar.dart` (`onHelp` 아이콘)

- [ ] 구현
- [ ] `flutter analyze` 바꾼 파일 경고 0

### Task 4: 실측 + 커밋

- [ ] iOS 시뮬레이터 실측 (스펙 7장 목록), 캡처
- [ ] `/pro-commit`
