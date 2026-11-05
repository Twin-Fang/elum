# Pro AI 맞춤 그림 (#1110) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Free 새 카드는 픽토그램만, Pro 는 요청 글·칩으로 "고쳐서 다시 그리기"·"AI 그림 그리기"(후보를 나란히 보고 고름), 기존 가입자에게 기간 한정 Pro 선물.

**Architecture:** 권한 판정은 `Entitlement.AI_IMAGE_GENERATION` 하나(`RoutineAiPicturePolicy` 가 감쌈). 다시 그리기는 2단계로 바꾼다 — 그리기는 후보 열쇠를 `routine_step.image_candidate_path` 에만 저장·정산하고, 보호자가 고르면(apply) 그때 `imagePath` 를 바꾼다. 선물은 `SIGNUP_PRO_EVENT_*` 처럼 조회 시점 계산(`ExistingMemberProGift`), 구독 상태 응답에 `source=PRO_GIFT` + `expiresAt`.

**Tech Stack:** Spring Boot (JUnit5 + Mockito), Flutter (Riverpod), gen-l10n.

**Spec:** `docs/superpowers/specs/2026-11-05-pro-plan-pricing-design.md` (2·5·6절, ConfigKey 주석)

## Global Constraints

- 운영 관리자 값·운영 서버는 건드리지 않는다. 새 설정은 기본 꺼짐(배포만으로 동작 불변).
- 실제 AI 호출 금지 (테스트는 전부 목).
- 이미 만든 AI 그림 조회·이미지 응답은 요금제를 보지 않는다 (변경 없음).
- 이룸이 화면에 결제·잠금·Pro 표시 없음. 후보 그림은 보호자(EDIT 권한)만 받는다.
- 요청 글 60자 이하, 칩 4개: 더 단순하게 · 배경 빼기 · 사람 빼기 · 더 밝게.
- 실패하면 원래 그림 그대로 + 에러 코드 + 크레딧·무료 횟수 반환. 고른 뒤 "원래 그림"이면 반환하지 않음.
- AI 그림 그리기(그림 없는 카드)는 `CreditJobKind.CARD_IMAGE` 단가, 무료 다시 그리기 한도 밖. 사진만 쓰기 방식·보호자 사진·가져온 그림 카드는 제외.
- 새 ErrorCode 는 ko·en 문구 + 클라 `server_error_code.dart` + `ErrorMessageParityTest` 단언.
- 화면 문구는 `app_ko.arb` 만, 해요체·긍정형. 토큰·공통 위젯만 사용.

## Review Focus

- 가입 때 생긴 기본 Free 행(`SIGNUP`·FREE)이 있는 기존 회원도 선물을 받아야 한다 (행 없음만 보면 거의 아무도 못 받음) → Task 1 테스트 `gift_appliesToDefaultSignupRow`.
- 그리는 사이 보호자가 사진으로 바꿈 → 후보 버림 + 반환 (409) → Task 3 `drawCandidate_pictureChangedWhileDrawing_releases`.
- 후보를 고르지 않고 다시 그리기 → 옛 후보 파일 삭제 후 새 후보 → Task 3 `drawCandidate_replacesPreviousCandidate`.
- 이미 반영·버린 후보로 apply → 404 `ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND`, 카드 그대로 → Task 3 `apply_staleCandidate_rejected`.
- Free 가 API 직접 호출 → 예약 전 403 `AI_IMAGE_NOT_ALLOWED` → Task 3 `drawCandidate_free_rejectedBeforeReserve`.

---

### Task 1: 기존 가입자 Pro 선물 + 설정 주석

**Files:**
- Modify: `server/.../systemconfig/core/ConfigGroup.java`, `ConfigKey.java` (FREE_AI_IMAGE_GENERATION 주석·설명 + 새 키 3개)
- Create: `server/.../license/application/service/ExistingMemberProGift.java`
- Modify: `SystemConfigEntitlementService.java`, `SubscriptionStatusService.java`, `license/core/SubscriptionSource.java` (`PRO_GIFT`)
- Test: `ExistingMemberProGiftTest.java`(new), `SystemConfigEntitlementServiceTest.java`, `SubscriptionStatusServiceTest.java`(new)

**Interfaces:**
- Produces: `ConfigKey.EXISTING_MEMBER_PRO_GIFT_ENABLED`(BOOLEAN "false"), `EXISTING_MEMBER_PRO_GIFT_JOINED_BEFORE`(DATETIME ""), `EXISTING_MEMBER_PRO_GIFT_ENDS_AT`(DATETIME ""), group `EXISTING_MEMBER_PRO_GIFT("기존 가입자 Pro 선물")`
- Produces: `Optional<LocalDateTime> ExistingMemberProGift.giftEndsAt(String memberId)` — 켜짐 · 두 시각 있음 · 가입 < 기준 · 지금 < 종료 일 때 종료 시각. 오류는 빈 값 + 경고 로그
- Produces: `SubscriptionSource.PRO_GIFT`; `MemberSubscriptionStatus(PRO, PRO_GIFT, null, endsAt, null, false)`
- 판정 순서: 구독 행이 실제로 Pro → 그 행 / 행 없음 또는 기본 가입 행(SIGNUP·FREE) → 선물 → (행 없음만) 신규가입 이벤트 → Free

- [ ] Tests: `giftEndsAt_insideWindow_returnsEnd`, `giftEndsAt_joinedOnOrAfterCutoff_empty`, `giftEndsAt_afterEnd_empty`, `giftEndsAt_disabledOrBlank_empty`, `giftEndsAt_badDate_empty`; entitlement `gift_appliesWithoutRow`, `gift_appliesToDefaultSignupRow`, `gift_activeProRowWins`, `gift_revokedManualRowDoesNotGetGift`; status `status_gift_showsProGiftAndEnd`
- [ ] Run → fail, implement, run `./gradlew test --tests '*ExistingMemberProGiftTest*' --tests '*SystemConfigEntitlementServiceTest*' --tests '*SubscriptionStatusServiceTest*'` → PASS

### Task 2: Free 새 카드는 그림 건너뜀

**Files:**
- Create: `server/.../routine/application/service/RoutineAiPicturePolicy.java`
- Modify: `RoutineCreateService.java` (Free 면 파이프라인에 `ImageStyle.PHOTO_ONLY` = 그림 호출 없는 기존 경로), `RoutineStepEditService.java` (카드 추가 `imageSkippedReason=AI_IMAGE_NOT_ALLOWED`, 예약·채우기 없음)
- Modify tests that `@InjectMocks` these services: add `@Mock RoutineAiPicturePolicy`
- Test: `RoutineAiPicturePolicyTest`, 생성·카드 추가 Free 케이스

**Interfaces:**
- Produces: `boolean RoutineAiPicturePolicy.shouldSkipAiPicture(String memberId)` (= `!isAllowed(AI_IMAGE_GENERATION)`), `void requireAiPicture(String memberId)` (거절 시 `CustomException(AI_IMAGE_NOT_ALLOWED)`)
- Produces: `RoutineStepEditService.IMAGE_SKIPPED_PLAN = "AI_IMAGE_NOT_ALLOWED"`

- [ ] Tests: `create_free_passesPhotoOnlyToPipeline`, `addStep_free_skipsImageWithPlanReason` (예약 없음), policy 2건
- [ ] Run → fail, implement, run 해당 클래스만 → PASS

### Task 3: 고쳐서 다시 그리기 · AI 그림 그리기 (서버)

**Files:**
- Modify: `ErrorCode.java` (+`AI_IMAGE_NOT_ALLOWED` FORBIDDEN, `ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND` NOT_FOUND), `messages_ko/en.properties`, `ErrorMessageParityTest`
- Modify: `RoutineStep.java` (+`imageCandidatePath`), Create `db/migration/V66__add_routine_step_image_candidate_path.sql`
- Create: `routine/core/ImageRedrawHint.java` (SIMPLER·NO_BACKGROUND·NO_PEOPLE·BRIGHTER + 영어 지시), `routine/core/GuardianImageRequest.java` (`static String compose(String requestText, List<ImageRedrawHint> hints)`; 60자 초과 → `INVALID_INPUT_VALUE`; 둘 다 없으면 null)
- Create: `dto/request/RoutineStepImageRedrawRequest(String requestText, List<ImageRedrawHint> hints)`, `dto/request/RoutineStepImageCandidateApplyRequest(String candidateImagePath)`, `dto/response/RoutineStepImageCandidateResponse(String stepId, String candidateImagePath, boolean isFirstPicture)`
- Modify: `ai/core/CardScene.java`, `GeminiImageAiInput.Scene`, `GeminiRoutineImagePromptBuilder`, `CardImageGenerator` (+`guardianRequest`; JSON 필드 `guardianRequest`, FLUX·실사는 설명 뒤에 덧붙임)
- Modify: `RoutineStepImageRegenerateService.java` → `drawCandidate(Caller, routineId, stepId, RoutineStepImageRedrawRequest)`
- Create: `RoutineStepImageCandidateService.java` (`readCandidate` · `applyCandidate` · `discardCandidate`)
- Modify: `RoutineController.java` + Create `RoutineStepImageDocs.java` (regenerate 문서 이동 + 후보 3개), `RoutineControllerDocs` extends 추가, 컨트롤러 테스트 생성자 4곳
- Test: `RoutineStepImageRegenerateServiceTest`(다시 씀), `RoutineStepImageCandidateServiceTest`(new), `GuardianImageRequestTest`(new), `RoutineImagePromptComposerTest`(guardianRequest 1건)

**API:**
- `POST /api/routines/{rid}/steps/{sid}/image/regenerate` body(선택) `{requestText, hints[]}` → 200 `RoutineStepImageCandidateResponse`. AI 그림 카드는 IMAGE_REGENERATE, 그림 없는 카드는 CARD_IMAGE. 후보 저장과 정산은 한 트랜잭션, 옛 후보 파일은 커밋 뒤 삭제
- `GET .../image/candidate` → 이미지 바이트 (EDIT 권한) / 404 CANDIDATE_NOT_FOUND
- `POST .../image/candidate/apply` `{candidateImagePath}` → 200 `RoutineStepResponse` (열쇠 불일치·없음 404)
- `DELETE .../image/candidate` → 204 (없어도 204)

- [ ] Tests: `drawCandidate_free_rejectedBeforeReserve`, `drawCandidate_aiPicture_reservesRegenerate_keepsImage`, `drawCandidate_noPicture_reservesCardImage`, `drawCandidate_guardianPhoto_notRegeneratable`, `drawCandidate_generationFails_releases`, `drawCandidate_pictureChangedWhileDrawing_releases`, `drawCandidate_replacesPreviousCandidate`, `drawCandidate_passesGuardianRequest`; `apply_swapsAndDeletesOld`, `apply_staleCandidate_rejected`, `discard_clearsAndDeletes`, `read_noCandidate_notFound`; compose 3건
- [ ] Run → fail, implement, run 해당 클래스 + `*ErrorMessageParityTest*` `*CrossStackContractTest*` (클라 코드 반영 뒤) → PASS

### Task 4: 앱

**Files:**
- `core/network/server_error_code.dart` (+2), `subscription/application/plan_paywall_entry.dart` (Pro 거절 7종)
- `member/data/member_repository.dart` + `member/application/plan_access.dart` (`canUseAiPictures` ← `entitlements.aiImageGeneration`)
- `member/domain/member_subscription.dart` (`proGift`), `subscription/domain/plan_status.dart` (`proGift`), `subscription/application/plan_status_providers.dart`
- `guardian/domain/added_card_image_state.dart` (`AI_IMAGE_NOT_ALLOWED` → `basicPictogramStyle`)
- Create `guardian/domain/image_redraw_hint.dart`, `guardian/data/card_image_candidate_api.dart`; modify `card_image_repository.dart` (옛 regenerate 제거), `card_photo_controller.dart`
- `credit/application/image_regenerate_cost.dart` (+`cardImageCredits`)
- Presentation: `card_regenerate_sheet.dart` (요청 글·칩·비용, 결과 `CardRedrawRequest?`), Create `card_image_candidate_sheet.dart` (지금 그림 | 새 그림 나란히, 두 버튼), Create `card_redraw_flow.dart` (시트 > 그리기 > 후보 받기 > 고르기 > 반영/버리기, 실패 코드), `card_photo_block.dart` (칩 3가지: 다시 그리기 · AI 그림 그리기 · Free 면 Pro 안내 칩)
- `l10n/app_ko.arb` + `flutter gen-l10n`
- Verify: `flutter analyze --no-fatal-infos lib/features lib/core`, `dart run tool/check_layer_imports.dart`, `tool/check_design_rules.dart`, `tool/check_hangul_literals.dart lib`

### Task 5: 마무리

- [ ] `./gradlew compileJava compileTestJava` 후 위 테스트만 `--tests`
- [ ] `git fetch origin && git rebase origin/develop`, 충돌은 양쪽 의도 보존
- [ ] 커밋(서버·앱·문서 나눔, 건드린 경로만), `git push origin <branch>`
