# Cloudflare 카드 그림 제공자 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카드 그림 제공자에 Cloudflare Workers AI klein-4b 를 더하고, 그 경로의 만화 그림은 캐릭터 대신 성별 중립 만화 아이로 그린다 (#1258).

**Architecture:** 기존 FLUX(fal) "영어 장면" 경로를 `EnglishSceneImageClient` 인터페이스로 일반화해 FLUX·CLOUDFLARE 가 같이 쓴다. 그릴 인물은 `CardImageSubject` 한 지점에서 정하고 생김새는 DB 지시문으로 관리한다. 실패하면 기존대로 그 카드만 OpenAI.

**Tech Stack:** Spring Boot 3, Java 21, RestClient(`AiRestClientFactory`), JUnit5 + Mockito, PostgreSQL(Flyway 변경 없음)

**Spec:** `docs/superpowers/specs/2026-11-11-cloudflare-card-image-provider-design.md`

## Global Constraints

- 모델 기본값 `@cf/black-forest-labs/flux-2-klein-4b`, 크기 512x376, 참조 그림 없음
- 단가 기본값 `0.0011462` USD/장
- 아이 생김새 기본값: `a simple cartoon child with a round head, short black bowl-cut hair, dot eyes, rosy cheeks, a plain orange hoodie and gray long pants`, 장면 주어 `child`
- 설정·지시문은 DB 기본값 시딩만 (yml·.env·Flyway 변경 없음, 기존 값 덮지 않음)
- 토큰·Account ID 를 로그·예외 메시지·응답에 싣지 않는다
- 주석은 한국어 한 줄 요약·단계 머리글, 로그는 영어 `[cloudflare image]` 접두사
- 테스트는 바꾼 코드를 겨누는 것만 마지막에 한 번 (`./gradlew test --tests ...`)

## Review Focus

1. 4006(하루 한도 초과) 응답 뒤 같은 날 카드: Cloudflare 를 부르지 않고 바로 OpenAI (Task 3 테스트)
2. Cloudflare 경로가 OpenAI 로 넘어간 카드: 캐릭터(LULU) 없이 그린다 (Task 4 테스트)
3. 제공자를 OPENAI 로 되돌리면 기존 동작(캐릭터 포함) 그대로 (Task 4 기존 테스트 유지)
4. 토큰 없음: 관리자 선택 막기(`available()` false) + 카드는 OpenAI (Task 3·4)
5. 실패 예외 메시지에 토큰이 들어가지 않는다 (Task 3 테스트)

---

### Task 1: 제공자·설정·비용 키

**Files:**
- Modify: `ai/core/ImageProvider.java`, `ai/core/AiProvider.java`, `ai/core/AiCallType.java`, `systemconfig/core/ConfigKey.java`, `ai/application/service/AiCallLogService.java`
- Test: `ai/application/service/AiCallLogServiceTest.java` (있으면 추가, 없으면 생성)

**Interfaces:**
- Produces: `ImageProvider.CLOUDFLARE("Cloudflare (klein-4b)", ConfigKey.PRICE_CLOUDFLARE_IMAGE_PER_IMAGE)`, `boolean ImageProvider.usesEnglishScene()` (FLUX, CLOUDFLARE true), `AiProvider.CLOUDFLARE("Cloudflare")`, `AiCallType.CLOUDFLARE_IMAGE("Cloudflare 이미지", CARD_IMAGE, CLOUDFLARE)`, `ConfigKey.CLOUDFLARE_ACCOUNT_ID`(STRING, ""), `CLOUDFLARE_API_TOKEN`(SECRET, ""), `CLOUDFLARE_IMAGE_MODEL`(STRING, 모델 기본값), `PRICE_CLOUDFLARE_IMAGE_PER_IMAGE`(DECIMAL, "0.0011462")
- `IMAGE_PROVIDER_SELECTED` 선택지에 `CLOUDFLARE`, 기본값 `CLOUDFLARE` (새 DB 만 영향)

- [ ] Step 1: 테스트 `cloudflareImage_usesPerImagePrice`: `PRICE_CLOUDFLARE_IMAGE_PER_IMAGE` 가 0.0011462 일 때 `CLOUDFLARE_IMAGE` 성공 기록의 `estimatedCostUsd == 0.0011462`
- [ ] Step 2: 테스트 `usesEnglishScene`: FLUX·CLOUDFLARE true, GEMINI·OPENAI false
- [ ] Step 3: enum·ConfigKey 추가, `estimateCostUsd` 에 `case CLOUDFLARE_IMAGE`
- [ ] Step 4: 관리자 설정 편집 화면이 ConfigKey 를 그룹별로 나열하는 목록이 따로 있으면(`SettingsEditorServiceTest` 가 전체 키 노출을 검사) 새 키 4개를 IMAGE_PROVIDER·PRICING 묶음에 더한다
- [ ] Step 5: 컴파일 `./gradlew compileJava compileTestJava`

### Task 2: 그릴 인물(CardImageSubject)과 생김새 지시문

**Files:**
- Create: `ai/core/CardImageSubject.java`
- Modify: `ai/core/PromptKey.java`, `ai/core/PromptDefaults.java`, `ai/core/MultilingualPromptDefaults.java`(switch 누락 시), `ai/infrastructure/client/FluxPromptBuilder.java`, `admin/application/service/AdminPromptService.java`(switch 2곳)
- Test: `ai/infrastructure/client/FluxPromptBuilderTest.java`, `ai/core/CardImageSubjectTest.java`

**Interfaces:**
- Produces: `enum CardImageSubject { CHILD(PromptKey.CARD_IMAGE_SUBJECT_CHILD, "child") }` 필드 `appearanceKey`, `subjectEn`; `static CardImageSubject forProfileCharacter(CharacterType characterType)` (지금은 항상 CHILD, 캐릭터별 인물을 더할 자리)
- `PromptKey.CARD_IMAGE_SUBJECT_CHILD("카드 그림 인물: 만화 아이 (영어 생김새)", false)`, 기본값 = Global Constraints 의 생김새
- `FluxPromptBuilder.build(String prefix, String sceneEn, String appearance, String subjectEn)`; 기존 `build(prefix, scene, CharacterType)` 은 이것에 위임

- [ ] Step 1: 테스트 `build_withSubject_replacesCharacterWithChild`: `build("Style.", "The character brushes the teeth.", "a kid", "child")` == `"Style. Only one character: a kid. The child brushes the teeth."`
- [ ] Step 2: 테스트 `forProfileCharacter_alwaysChild`: LULU·POPO·null 모두 CHILD
- [ ] Step 3: 구현. AdminPromptService preview: `CARD_IMAGE_SUBJECT_CHILD` 는 저장된 `FLUX_ROUTINE_IMAGE_PREFIX` + content(생김새) + 샘플 장면으로 조립; test: Task 5 의 Cloudflare 시험 경로로 그린다
- [ ] Step 4: `PromptDefaultsTest`·`PromptKeyTest`·`PromptTemplateSeederTest` 가 새 키를 받아들이는지 Task 6 에서 함께 실행

### Task 3: CloudflareImageClient

**Files:**
- Create: `ai/infrastructure/client/EnglishSceneImageClient.java`, `ai/infrastructure/client/CloudflareImageClient.java`
- Modify: `ai/infrastructure/client/FluxImageClient.java` (implements EnglishSceneImageClient, 동작 변화 없음)
- Test: `ai/infrastructure/client/CloudflareImageClientTest.java`

**Interfaces:**
- Produces: `interface EnglishSceneImageClient extends ImageGenerationClient { GeneratedImage generate(String sceneEn, CharacterType characterType, Integer seed); GeneratedImage generateRealistic(String sceneEn, Integer seed); GeneratedImage generateForTest(String prefix, String sceneEn, CharacterType characterType); default boolean drawsProfileCharacter() { return true; } }`
- `CloudflareImageClient`: `provider()=CLOUDFLARE`, `available()` = 토큰 SECRET 과 Account ID 둘 다 있음, `supportsCharacterReference()=false`, `drawsProfileCharacter()=false`, `generate` 는 characterType 을 무시하고 `CardImageSubject.forProfileCharacter(characterType)` 의 생김새로 조립
- 요청: `POST https://api.cloudflare.com/client/v4/accounts/{accountId}/ai/run/{model}`, `Authorization: Bearer {token}`, multipart 필드 `prompt`, `width=512`, `height=376`, `seed`(있을 때). 응답 JSON `result.image`(base64) > `GeneratedImage(bytes, "png")` (실측 결과 PNG)
- 패키지 전용 `MultiValueMap<String, Object> requestParts(String prompt, Integer seed)` 와 `Clock` 주입(생성자 오버로드)으로 테스트
- 한도: 응답 본문에 code `4006` 이 있으면 다음 00:00 UTC 까지 `quotaExhaustedUntil` 기록, 그 전 호출은 HTTP 없이 `IllegalStateException("cloudflare daily free allocation used up")`
- 호출 기록 `AiCallType.CLOUDFLARE_IMAGE`, 실패 메시지에는 HTTP 상태와 Cloudflare 오류 code 만 (토큰·URL 의 accountId 제외)

- [ ] Step 1: 테스트 `parts_sizeSeedPrompt`: width 512, height 376, seed, prompt 그대로
- [ ] Step 2: 테스트 `generate_usesChildNotProfileCharacter`: LULU 를 넘겨도 프롬프트에 LULU 영어 생김새("kitten")가 없고 아이 생김새와 "The child" 가 있다 (PromptTemplateService mock 이 prefix·생김새 반환, 프롬프트는 `buildPrompt` 패키지 메서드로 확인)
- [ ] Step 3: 테스트 `quota4006_skipsUntilNextUtcMidnight`: 2026-11-11T08:00Z 에 4006 표시 > 23:59Z 에 `isQuotaExhausted` true, 2026-11-12T00:00Z 에 false
- [ ] Step 4: 테스트 `available_needsTokenAndAccount`: 둘 중 하나라도 비면 false
- [ ] Step 5: 테스트 `failureMessage_hasNoSecret`: 실패 기록 메시지에 토큰·accountId 문자열 없음
- [ ] Step 6: 구현

### Task 4: CardImageGenerator 를 영어 장면 제공자 공통으로

**Files:**
- Modify: `ai/application/service/CardImageGenerator.java`, `ai/infrastructure/client/ImageClientRouter.java`
- Test: `ai/application/service/CardImageGeneratorTest.java`, `CardImageGeneratorLocaleTest.java`, `ai/infrastructure/client/ImageClientRouterTest.java`

**Interfaces:**
- Consumes: Task 1 `usesEnglishScene()`, Task 3 `EnglishSceneImageClient`
- Produces: `Optional<EnglishSceneImageClient> ImageClientRouter.englishScene(ImageProvider provider)`; `CardImageGenerator(ImageClientRouter, GeminiTextClient)` (FluxImageClient 의존 제거)

- [ ] Step 1: 기존 테스트 생성자·mock 을 `englishScene(FLUX)` 로 바꾼다 (기존 FLUX 단언은 그대로)
- [ ] Step 2: 테스트 `cloudflare_usesEnglishScene`: selected=CLOUDFLARE, `imagePromptEn` 있으면 cloudflare.generate(scene, LULU, seed) 호출, 번역 안 부름
- [ ] Step 3: 테스트 `cloudflareFailure_fallsBackToOpenAiWithoutCharacter`: cloudflare.generate 가 던지면 openAi.generateCardImage(any, isNull())
- [ ] Step 4: 테스트 `cloudflareUnavailable_fallsBackToOpenAi`, `cloudflareRealistic_usesTranslatedScene`
- [ ] Step 5: 구현: `selected().usesEnglishScene()` 분기, 클라이언트는 `router.englishScene(selected)`, fallback 에서 `!client.drawsProfileCharacter()` 면 characterType null 로 새 request. 주석의 "FLUX" 를 "영어 장면 제공자"로 맞춘다

### Task 5: 관리자 화면

**Files:**
- Modify: `admin/application/service/AdminPromptService.java`, `admin/application/controller/AdminConfigController.java`(필요 시), `templates/admin/settings-ai.html`(필요 시)
- Test: `admin/application/service/AdminPromptServiceTest.java`

- [ ] Step 1: 테스트 `fluxPrefixTest_usesCloudflareWhenSelected`: selected=CLOUDFLARE 면 `FLUX_ROUTINE_IMAGE_PREFIX` 시험이 cloudflare.generateForTest 로
- [ ] Step 2: `promptTestImageClient()` 의 FLUX 비교를 `usesEnglishScene()` 으로
- [ ] Step 3: 제공자 카드(`imageProviderViews`)·비용 화면은 enum 순회라 자동 노출: 로컬 서버 화면에서 확인 (Task 6)

### Task 6: 문서, 검증

- [ ] Step 1: `docs/03-screens.md`, `docs/01-overview.md`, `docs/08-design-principles.md`, `docs/00-one-pager.md` 의 카드 그림·캐릭터 문장 수정, `server/tool/prompt-eval/cloudflare/README.md` 최종 생김새로
- [ ] Step 2: `./gradlew compileJava compileTestJava`
- [ ] Step 3: 관련 테스트 1회: `./gradlew test --tests '*CardImageGenerator*' --tests '*CloudflareImageClient*' --tests '*FluxImageClient*' --tests '*FluxPromptBuilder*' --tests '*ImageClientRouter*' --tests '*AdminPromptService*' --tests '*AiCallLogService*' --tests '*PromptDefaults*' --tests '*PromptKey*' --tests '*PromptTemplateSeeder*' --tests '*SettingsEditorService*' --tests '*SystemConfigOverview*' --tests '*CardImageSubject*' --tests '*RoutineAiPipeline*' --tests '*RoutineStepImageFiller*'`
- [ ] Step 4: 로컬 DB 리허설: develop 기동 > 새 코드 기동, 새 설정 4개·지시문 1개 시딩, 기존 값 보존 확인
- [ ] Step 5: 로컬 실호출: 관리자 화면에 시험 토큰 입력 > 제공자 CLOUDFLARE > 일과 1개 생성, 카드 그림·호출 기록·비용 확인
- [ ] Step 6: `/pro-commit`
