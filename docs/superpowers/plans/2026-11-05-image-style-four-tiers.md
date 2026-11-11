# 카드 그림 방식 4가지 + Pro 혜택 목록 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그림 방식을 이모지(Free)·기호(Free)·캐릭터(Pro)·실사(Pro) 4가지로 바꾸고, Free가 Pro 방식을 누르면 Pro 혜택 전체를 보여 주는 요금제 화면으로 보낸다.

**Architecture:** 서버는 `ImageStyle`에 `EMOJI`를 더하고, 일과·카드 생성 직전에 요금제를 보고 "실제로 쓸 방식"을 한 곳에서 정한다. AI가 고르는 그림 목록은 방식에 따라 Mulberry 또는 Twemoji 카탈로그를 `AiCallContext`로 실어 보낸다(세 텍스트 제공자가 같은 입력 조립을 공유). 앱은 4개 방식을 그리고, Pro 잠금은 `PlanAccess`로 판단해 `openPlanPaywall(highlight:)`로 보낸다.

**Tech Stack:** Spring Boot (Java 21), Flutter (Riverpod), Python 3 (카탈로그 생성 스크립트)

**Spec:** `docs/superpowers/specs/2026-11-05-image-style-four-tiers-design.md`

## Global Constraints

- 서버 enum 값 문자열 `PHOTO_ONLY` · `CARTOON` · `REALISTIC`는 바꾸지 않는다. 새 값은 `EMOJI` 하나. DB 마이그레이션 없음.
- 이모지 id 형식 `emoji_` + 영어 이름 snake_case. 카드의 `pictogramId` 칸(길이 100)에 그대로 저장.
- 카탈로그 입력 버전 고정: `@twemoji/svg@15.0.0`, `emojibase-data@15.3.0`.
- AI 입력 키 이름 `pictogramCatalog`와 스키마 설명은 바꾸지 않는다(운영 DB 프롬프트 보호).
- 화면 문구(ko): 이모지 그림 / 그림 기호 / 캐릭터 그림 / 사진 같은 그림. 설명 줄은 스펙 §3.2 그대로. en: Emoji / Picture symbols / Character / Realistic.
- 앱 코드에 한글 리터럴 금지(ARB로) — `tool/check_hangul_literals.dart`. `core/widgets`는 `features`를 import하지 않는다 — `tool/check_layer_imports.dart`. 색·간격 리터럴 금지 — `tool/check_design_rules.dart`.
- 주석은 한국어, 한 줄 요약·단계 머리글. 로그는 영어 + 기능 접두사.
- 실제 AI·그림 호출 금지. 서버 테스트는 바꾼 곳만 `./gradlew test --tests '...'`. 앱 테스트는 두지 않는다(#848) — `flutter analyze` + `tool/check_*`.
- 약관 본문(`consent_documents.dart`)은 손대지 않는다.
- 운영 Free `AI 맞춤 삽화` 설정은 코드에서 바꾸지 않는다(배포 날 관리자 화면에서, 사용자 확인 후).

## Review Focus

1. **Free + 저장값 CARTOON인 기존 계정이 일과를 만든다** → 실패하지 않고 그림 기호(PHOTO_ONLY 동작)로 만든다. 저장값은 그대로. (Task 3 테스트)
2. **이모지 방식에서 AI가 Mulberry id나 없는 id를 준다** → 이모지 카탈로그의 fallbackId로 바뀐다. (Task 2 테스트)
3. **옛 앱이 `emoji_*` id 카드를 받는다** → 허용 id 검사에서 걸러 폴백·기본 카드. 서버 쪽 작업은 없고, 새 앱은 SVG가 없어도 죽지 않는다. (Task 7 단계)
4. **이모지 카탈로그 파일이 없는 서버** → 빈 카탈로그 경고 + 이모지 방식은 Mulberry로 대체해 고른다. (Task 2 테스트)
5. **요금제 화면에서 결제 없이 닫음** → 고른 값 그대로, 팝업 없음. 결제 후 닫음 → 누른 Pro 방식이 골라짐. (Task 5 단계, 실측)

---

### Task 1: 이모지 카탈로그 생성 스크립트와 결과물

**Files:**
- Create: `server/tool/emoji/build_emoji_catalog.py`
- Create: `server/tool/emoji/README.md` (실행법 3줄)
- Create (생성물): `server/src/main/resources/emoji/catalog.json`
- Create (생성물): `client/assets/emoji/catalog.json`, `client/assets/emoji/{id}.svg`, `client/assets/emoji/LICENSE.txt`
- Create (생성물): `client/lib/shared/pictogram/emoji_ids.dart`
- Modify: `client/pubspec.yaml` (assets에 `assets/emoji/` 추가)

**Interfaces:**
- Produces: `catalog.json` 형식 = Mulberry와 같음 `{source, license, attribution, fallbackId, symbols:[{id, label, category, verb:false}]}` + 이모지 전용 `codepoint`.
- Produces: `emoji_ids.dart`의 `const Set<String> emojiIds` (Mulberry `pictogram_ids.dart`와 같은 모양).

- [ ] **Step 1: 스크립트 작성** — 인자 `--cache-dir`(다운로드 위치, 기본 스크래치), `--repo-root`. jsDelivr에서 고정 버전 두 개를 받아:
  - 단일 이모지만(skins·ZWJ·국기·기호·component 제외), 그룹은 스펙 §3.6 범위, 얼굴은 `emotion`·`face-smiling`·`face-concerned`·`face-sleepy`·`face-unwell`만, `person-fantasy`·`place-religious`·`family`·`heart` 제외. 목표 700~900개.
  - id = `emoji_` + label을 영어 snake_case(영숫자만, 중복이면 `_2`).
  - SVG는 Twemoji 파일을 **그대로** 복사(변형 없음), 파일명 `{id}.svg`.
  - fallbackId = `emoji_star`가 있으면 그것.
  - 서버·앱 catalog.json을 같은 바이트로 쓰고, `emoji_ids.dart`를 생성(파일 맨 위 "생성 파일, 손대지 말 것" 주석).
  - LICENSE.txt에 CC BY 4.0 고지 + 출처(Twemoji by Twitter/X, https://github.com/jdecked/twemoji).
- [ ] **Step 2: 실행 후 자체 점검** — 스크립트 끝에서 확인하고 실패 시 exit 1: 개수 700~900, 모든 id에 SVG 존재, 두 catalog 바이트 동일, Mulberry catalog id와 겹침 0.
  Run: `python3 -I server/tool/emoji/build_emoji_catalog.py --repo-root .`
  Expected: `[emoji catalog] ok : symbols=NNN fallback=emoji_star`
- [ ] **Step 3: 앱 에셋 크기 확인** — `du -sh client/assets/emoji` 가 3MB 이하인지 본다. 넘으면 범위를 줄인다.
- [ ] **Step 4: Commit** (`/pro-commit`, 이 경로들만)

### Task 2: 서버 — EMOJI 방식과 방식별 그림 카탈로그

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/member/infrastructure/entity/ImageStyle.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/ai/application/service/PictogramCatalog.java` (경로 지정 생성 정적 메서드만 공개)
- Create: `server/src/main/java/com/chuseok22/elumserver/ai/application/service/PictogramCatalogs.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/ai/core/AiCallContext.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/ai/infrastructure/client/GeminiTextClient.java` (`:48`, `:124`, `:223`, `:336`)
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/ai/RoutineAiPipeline.java` (`:64`, `:220-235`, `:307`)
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/application/service/PictogramPicker.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/ai/application/service/CardImageGenerator.java` (`:80`)
- Modify: `server/src/main/java/com/chuseok22/elumserver/expertroutine/application/service/ExpertRoutineInputRules.java` (Mulberry 고정 주입으로)
- Modify: `server/src/main/java/com/chuseok22/elumserver/member/application/controller/MemberControllerDocs.java` (`:299` 표에 EMOJI 줄)
- Test: `server/src/test/java/com/chuseok22/elumserver/ai/application/service/PictogramCatalogsTest.java` (새)
- Test: 기존 `PictogramPickerTest`, `RoutineAiPipelineTest`, `GeminiTextClientPictogramTest`에 케이스 추가

**Interfaces:**
- Produces: `ImageStyle.EMOJI("이모지")`, `boolean drawsAiImages()` (CARTOON, REALISTIC), `PictogramSet pictogramSet()` (EMOJI > EMOJI, 그 외 > MULBERRY).
- Produces: `enum PictogramSet { MULBERRY, EMOJI }` (`ai/core/PictogramSet.java`).
- Produces: `@Component PictogramCatalogs` — `PictogramCatalog of(PictogramSet set)`; 이모지 카탈로그가 비었으면 Mulberry를 돌려준다(경고 로그 1회). `PictogramCatalog mulberry()`.
- Produces: `AiCallContext.setPictogramSet(PictogramSet)`, `PictogramSet currentPictogramSet()` (없으면 MULBERRY), `clear()`에 포함. InheritableThreadLocal(기존 패턴).
- Produces: `PictogramPicker.pick(String memberId, String title, String description, PictogramSet set)` — 가상 스레드 `callModel`에서 set도 다시 세운다.
- Consumes: Task 1의 `emoji/catalog.json`.

- [ ] **Step 1: 실패하는 테스트**
  - `PictogramCatalogsTest.emojiSetLoadsEmojiCatalog`: `of(EMOJI).contains("emoji_toothbrush")` true, `of(MULBERRY).contains("brush_teeth_,_to")` true.
  - `PictogramCatalogsTest.emptyEmojiFallsBackToMulberry`: 빈 이모지 카탈로그로 만든 `PictogramCatalogs`의 `of(EMOJI)`가 Mulberry를 돌려준다.
  - `RoutineAiPipelineTest.emojiStyleResolvesAgainstEmojiCatalog`: EMOJI 방식, 고정 응답 pictogramId `"brush_teeth_,_to"`(Mulberry id) → 결과 pictogramId == 이모지 fallbackId, 그림 생성기 호출 0회.
  - `RoutineAiPipelineTest.emojiStyleKeepsValidEmojiId`: 고정 응답 `"emoji_toothbrush"` → 그대로.
  - `GeminiTextClientPictogramTest.userContentCarriesCatalogOfContextSet`: `AiCallContext.setPictogramSet(EMOJI)` 후 만든 user content의 `pictogramCatalog`에 `emoji_toothbrush` 포함, `brush_teeth_,_to` 미포함.
  - `PictogramPickerTest.pickUsesGivenSet`: EMOJI로 부르면 무효 id가 이모지 fallbackId로.
- [ ] **Step 2: 실행해 실패 확인** — `cd server && ./gradlew test --tests '*PictogramCatalogsTest*' --tests '*PictogramPickerTest*' --tests '*RoutineAiPipelineTest*' --tests '*GeminiTextClientPictogramTest*'` → 컴파일 실패/FAIL
- [ ] **Step 3: 구현**
  - `GeminiTextClient`는 `PictogramCatalog` 대신 `PictogramCatalogs`를 받고, 입력 조립·스키마 판단에 `catalogs.of(AiCallContext.currentPictogramSet())`를 쓴다(OpenAI·Claude는 이 조립을 재사용하므로 따로 고칠 것 없음 — 확인만).
  - `RoutineAiPipeline.generateForCreate`는 방식의 `pictogramSet()`을 컨텍스트에 세우고(호출 뒤 원래 값 복구), `normalizeOrder`의 resolve도 같은 카탈로그로. `PHOTO_ONLY` 비교(`:307`)와 `CardImageGenerator:80`은 `!drawsAiImages()`로.
  - `ExpertRoutineInputRules`는 `catalogs.mulberry()`.
- [ ] **Step 4: 실행해 통과 확인** — 위 명령 → PASS. 이어서 `./gradlew compileJava compileTestJava` → BUILD SUCCESSFUL(다른 테스트의 생성자 변경 반영).
- [ ] **Step 5: Commit**

### Task 3: 서버 — 요금제로 실제 방식 정하기와 막기

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/member/application/service/EffectiveImageStyleResolver.java`
- Modify: `common/infrastructure/exception/ErrorCode.java` (`IMAGE_STYLE_NOT_ALLOWED(HttpStatus.FORBIDDEN)`), `resources/i18n/messages_ko.properties`, `messages_en.properties`
- Modify: `member/application/service/MemberService.java:169`, `member/application/service/OnboardingService.java:50`
- Modify: `routine/application/service/RoutineCreateService.java:170`, `routine/application/service/RoutineStepEditService.java:204,227,258`
- Modify: `systemconfig/core/ConfigKey.java:245-251` (FREE 기본값 `"false"`, 낡은 주석 제거)
- Modify: `member/application/controller/MemberControllerDocs.java` (PATCH 403 예시)
- Test: `member/application/service/EffectiveImageStyleResolverTest.java` (새), 기존 `MemberService`·`OnboardingService`·`RoutineStepEditTest`·`RoutineServiceTest` 관련 테스트에 케이스 추가

**Interfaces:**
- Consumes: `EntitlementService.isAllowed(String memberId, Entitlement)`, Task 2의 `ImageStyle.drawsAiImages()`.
- Produces: `ImageStyle resolve(String memberId, ImageStyle stored)` — `orDefault` 후, `drawsAiImages()`인데 `AI_IMAGE_GENERATION` 꺼짐 > `PHOTO_ONLY`, 아니면 그대로. `boolean isAllowed(String memberId, ImageStyle style)`.
- Produces: 카드 추가 응답의 그림 건너뜀 사유는 실제 방식이 `!drawsAiImages()`면 기존 `IMAGE_STYLE_PHOTO_ONLY`.

- [ ] **Step 1: 실패하는 테스트**
  - `EffectiveImageStyleResolverTest`: Free(권한 꺼짐)+CARTOON > PHOTO_ONLY / Free+EMOJI > EMOJI / Pro+REALISTIC > REALISTIC / null > (권한 켜짐) CARTOON.
  - `MemberService` 테스트 `updateImageStyleRejectsProStyleForFree`: 권한 꺼짐 + CARTOON PATCH > `CustomException(IMAGE_STYLE_NOT_ALLOWED)`, 프로필 값 그대로.
  - `OnboardingService` 테스트 `onboardingStoresEmojiWhenProStyleNotAllowed`: 권한 꺼짐 + REALISTIC > 프로필 EMOJI, 예외 없음.
  - `RoutineStepEditTest.addStepUsesSymbolWhenStoredProStyleNotAllowed`: 저장 CARTOON + 권한 꺼짐 + wantsImage > 사유 `IMAGE_STYLE_PHOTO_ONLY`, 크레딧 예약 0회, 그림 예약 0회.
  - 일과 만들기 테스트 `createUsesResolvedStyle`: 저장 CARTOON + 권한 꺼짐 > 파이프라인에 PHOTO_ONLY 전달.
- [ ] **Step 2: 실행해 실패 확인** — `./gradlew test --tests '*EffectiveImageStyleResolverTest*' --tests '*MemberService*' --tests '*Onboarding*' --tests '*RoutineStepEditTest*' --tests '*RoutineServiceTest*'`
- [ ] **Step 3: 구현** — 이룸이 기기 호출자는 기존 규칙대로 연결해 준 보호자 memberId로 판정(주간 리포트와 같은 `caller.memberId()`). 온보딩 대체는 `log.warn("[image style] onboarding downgraded : {} -> EMOJI", style)`.
- [ ] **Step 4: 실행해 통과 확인** — 같은 명령 PASS + `./gradlew compileJava compileTestJava`
- [ ] **Step 5: Commit**

### Task 4: 앱 — 그림 방식 4가지

**Files:**
- Modify: `client/lib/shared/models/image_style.dart`
- Modify: `client/lib/core/widgets/image_style_option_card.dart` (`:130`, `:162-194`)
- Modify: `client/lib/core/widgets/image_style_credit_bar.dart` (변경 필요 시)
- Modify: `client/lib/core/assets/app_assets.dart` (`:27`, `:234`, `emoji(id)`·`imageStyleEmoji` 추가)
- Modify: `client/lib/l10n/app_ko.arb`, `app_en.arb` (+ `flutter gen-l10n`)
- Modify: 이름 바뀐 enum 사용처 전부(조사 결과: `onboarding_notifier.dart:42-46`, `member_repository.dart:25`, `profile_summary.dart:17`, `auth_repository.dart:390`, `device_link_repository.dart:283`, 저장소 구현, `dev_tools_inspect.dart`)

**Interfaces:**
- Produces: `enum ImageStyle { emoji('EMOJI'), symbol('PHOTO_ONLY'), character('CARTOON'), realistic('REALISTIC') }` — 이 순서가 화면 순서. `onboardingDefault = emoji`. `fromApiValue` 폴백 = `character`(기존 동작 유지). `bool get drawsCardImages`(character, realistic), `bool get isProOnly`(같은 둘).
- Produces: ARB 키 이름 변경 `imageStylePhotoOnly*` → `imageStyleSymbol*`, `imageStyleCartoon*` → `imageStyleCharacter*`, 새 `imageStyleEmojiLabel`·`imageStyleEmojiDescription`, 공용 `planProBadge`("Pro").
- Produces: `ImageStyleOptionCard`에 `bool isLocked`(배지만 표시, 누름은 호출부가 처리)와 `String? badgeLabel` 파라미터.

- [ ] **Step 1: enum·ARB·예시 그림 구현** — 예시 그림은 같은 장면: 이모지 `AppAssets.emoji('emoji_toothbrush')`, 기호 `brush_teeth_,_to`, 캐릭터 고른 캐릭터, 실사 기존 PNG. 설명 줄 높이 예외(`:130`)는 기호에만.
- [ ] **Step 2: 검증** — `cd client && flutter gen-l10n && flutter analyze` → No issues found. `dart run tool/check_hangul_literals.dart && dart run tool/check_layer_imports.dart && dart run tool/check_design_rules.dart` → 모두 통과.
- [ ] **Step 3: Commit**

### Task 5: 앱 — Pro 잠금과 요금제 화면 연결

**Files:**
- Modify: `client/lib/features/member/application/plan_access.dart`, `client/lib/features/member/data/member_repository.dart:178-203`, `client/lib/core/dev/dev_plan_override.dart`
- Create: `client/lib/features/member/application/image_style_choice.dart` (세 화면이 공유하는 Pro 누름 처리)
- Modify: `client/lib/features/onboarding/presentation/image_style_screen.dart:49-65`, `client/lib/features/guardian/presentation/image_style_settings_screen.dart:89-107`, `client/lib/features/profile/presentation/widgets/elumi_choice_sheets.dart:145-189`
- Modify: `client/lib/features/subscription/application/plan_paywall_entry.dart` (`highlight` 인자)
- Modify: 카드 화면의 그림 다시 그리기 노출이 저장 방식을 보는 곳(있으면) → 실제 방식으로

**Interfaces:**
- Consumes: Task 4의 `ImageStyle.isProOnly`, `ImageStyleOptionCard.isLocked/badgeLabel`; Task 6의 `PlanBenefit.aiImageStyles`.
- Produces: `PlanAccess.canUseAiImageStyles` (원본 `entitlements.aiImageGeneration`, 없으면 false); `PlanAccess.free/pro`·`withCanPurchasePro`·`_readPlanAccess`·개발자 도구 흉내에 반영.
- Produces: `Future<void> openPlanPaywall(BuildContext context, WidgetRef ref, {PlanBenefit? highlight})` (기존 호출부 그대로 동작).
- Produces: `List<ImageStyle> visibleImageStyles(PlanAccess access, {required ImageStyle current})` — 살 수 없고 권한도 없으면 Pro 방식 숨김, 단 `current`는 항상 포함. `Future<ImageStyle?> chooseImageStyle(BuildContext, WidgetRef, ImageStyle tapped)` — 고를 수 있으면 `tapped`, Pro 잠김이면 요금제 화면(`highlight: PlanBenefit.aiImageStyles`)을 열고 닫힌 뒤 `canUseAiImageStyles`면 `tapped`, 아니면 null(값 유지).
- Produces: `ImageStyle effectiveImageStyle(ImageStyle stored, PlanAccess access)` — 서버 규칙과 같음(isProOnly && !canUseAiImageStyles > symbol).

- [ ] **Step 1: PlanAccess·파싱·개발자 도구 구현**
- [ ] **Step 2: 세 화면을 `visibleImageStyles`·`chooseImageStyle`로 교체**, Pro 항목에 `badgeLabel: l10n.planProBadge`, `isLocked: !access.canUseAiImageStyles`.
- [ ] **Step 3: 검증** — `flutter analyze` + `tool/check_*` 3종 통과.
- [ ] **Step 4: Commit**

### Task 6: 앱 — 요금제 화면 Pro 혜택 전체 목록

**Files:**
- Modify: `client/lib/features/subscription/domain/plan_benefit.dart`
- Modify: `client/lib/features/subscription/presentation/plan_offer_views.dart:15-37`, `plan_paywall_body.dart`, `plan_paywall_sheet.dart` (highlight 전달)
- Modify: `client/lib/l10n/app_ko.arb`, `app_en.arb`

**Interfaces:**
- Produces: `enum PlanBenefit { aiImageStyles, moreWeeklyCredits, adsRemoved, weeklyReport, routineSchedule, guardianVoice, routineTranslate, expertRoutines, routineMemory, imageRegenerateFree, cardExportWithoutWatermark, cardExportAllThemes }` (이 순서 = 기본 표시 순서).
- Produces: `List<PlanBenefit> orderedPlanBenefits({PlanBenefit? highlight})` — highlight를 맨 앞으로, 나머지 순서 유지.
- Produces: `PlanBenefitsGroup({PlanBenefit? highlight})`, `showPlanPaywall(context, ref, {PlanBenefit? highlight})`.
- 문구는 스펙 §3.7 표 그대로(해당 9줄 + 기존 3줄). `adsRemoved`는 앱에 광고가 실제로 있는지 확인하고 없으면 enum에서 뺀다.

- [ ] **Step 1: 구현**
- [ ] **Step 2: 검증** — `flutter gen-l10n && flutter analyze` + `tool/check_*` 통과.
- [ ] **Step 3: Commit**

### Task 7: 앱 — 이모지 그림 렌더링과 출처 표기

**Files:**
- Modify: `client/lib/shared/pictogram/pictogram_catalog.dart`, `pictogram_svg_loader.dart`, `pictogram_art.dart` (필요 시)
- Modify: `client/lib/features/license/domain/open_source_license.dart`, `data/open_source_license_repository.dart`, `presentation/open_source_licenses_screen.dart`
- Modify: `client/lib/features/guardian/presentation/card_export/print_sheets.dart:93` (+ 출처 ARB)

**Interfaces:**
- Consumes: Task 1의 `emojiIds`, `assets/emoji/{id}.svg`, `assets/emoji/LICENSE.txt`.
- Produces: `PictogramCatalog.parse(String? id)`가 `emoji_`로 시작하면 `emojiIds`로 검사(없으면 null > 기본 카드), 아니면 기존 Mulberry 검사. 에셋 경로 `AppAssets.emoji(id)` = `assets/emoji/$id.svg`.
- Produces: `BundledLicenseKind.twemoji`; 인쇄 장에 이모지 카드가 있으면 Twemoji 출처 줄(`showsEmojiCredit`).

- [ ] **Step 1: 구현** — 이모지 SVG는 원본 그대로 그린다(Mulberry처럼 style 풀기가 필요한지 1장 확인 후 결정). SVG 로드 실패는 기본 카드로(예외 삼키지 말고 기존 로더의 실패 처리 경로를 탄다).
- [ ] **Step 2: 검증** — `flutter analyze` + `tool/check_*` 통과.
- [ ] **Step 3: Commit**

### Task 8: 실측 검증

- [ ] **Step 1: 서버 묶음 테스트** — Task 2·3 명령을 한 번에 다시 실행 → PASS. 전체 스위트는 돌리지 않는다.
- [ ] **Step 2: 로컬 서버 + 시뮬레이터** (`/pro-launch`, 기기 빌려 쓰고 반납): 개발자 도구 요금제 흉내 Free/Pro로 캡처(라이트·다크)
  - 온보딩 그림 방식 화면(Free: Pro 배지, Pro: 배지 없음)
  - Free에서 캐릭터 그림 누름 > 요금제 화면, "캐릭터·사진 같은 그림…" 맨 위, 혜택 전체 목록
  - 결제 없이 닫음 > 값 그대로
  - 이모지 방식으로 일과 만들기 > 카드에 Twemoji (AI 텍스트 호출은 개발 서버 1회, 그림 호출 없음)
  - 오픈소스 라이선스 화면 Twemoji 항목
- [ ] **Step 3: 남는 사본·미실행 항목을 보고에 적는다** (ja·zh·es ARB, 운영 설정 끄기 미실행)
