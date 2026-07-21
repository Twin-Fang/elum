# 관리자 프롬프트 테스트 — REVISE 이전 루틴 입력 설계

- 날짜: 2026-07-22
- 대상: `server` — `admin/application/dto/request`, `admin/application/service`,
  `admin/application/controller`, `ai/infrastructure/client`,
  `src/main/resources/templates/admin`

## 배경

2026-07-21 "Gemini 호출 구조 개선"(이슈 #81)에서 루틴 생성/수정/추가 질문/이미지 4개 Gemini
호출을 `<text>` 태그 조립 방식에서 작업별 JSON 입력 방식으로 전환했고, `AdminPromptService`의
`preview()`/`test()`도 실제 호출과 동일한 JSON 조립 메서드를 재사용하도록 통합했다. 이 작업은
완료·배포됐다.

다만 관리자 화면(`templates/admin/prompts.html`)의 테스트 입력은 지금도 한 줄짜리
`sample-input` 하나뿐이다. 이 값은 프롬프트 키에 따라 다른 필드로 매핑되는데, REVISE
(`GEMINI_ROUTINE_REVISE_PREFIX`)만 구조적인 공백이 있다.

- CREATE/QUESTION: `sample-input` → `routineText` (한 줄 텍스트로 충분히 표현 가능)
- **REVISE: `sample-input` → `feedback`에만 매핑되고, `previousRoutine`(이전 제목 +
  단계)은 `GeminiTextClient.reviseForTest()` 내부에서 `""`/`List.of()`로 하드코딩되어
  있다.** 관리자가 REVISE 프롬프트를 테스트해도 "기존 루틴을 주고 피드백을 반영해
  최소 변경한다"는 실제 시나리오를 한 번도 재현할 수 없다.
- IMAGE: `sample-input` → 장면 텍스트 (그대로 사용, 문제 없음)

또한 최근 "루틴 단계에 카드 title 필드 추가" 작업으로 각 단계(`RoutineStepDraft.StepDraft`)는
`order`/`title`/`description` 세 값을 모두 가지게 됐고, REVISE 프롬프트(`PromptDefaults`)도
`previousRoutine.steps`에 `title`을 포함하도록 이미 갱신되어 있다. 따라서 관리자 입력 UI도
description뿐 아니라 title까지 받을 수 있어야 실제 데이터 구조와 일치한다.

## 범위

### 할 것

- `PromptSampleRequest`에 `previousTitle`(이전 제목)과 `previousSteps`(이전 단계
  title/description 목록)를 추가한다. REVISE 테스트/미리보기 시에만 사용되고, 다른 3개
  키에서는 무시된다(기존 `character` 필드와 동일한 패턴).
- `AdminPromptService.preview()`/`test()`가 이 값들을 `GeminiTextClient`의
  `buildReviseRoutineUserContent()`/`reviseForTest()`에 그대로 전달하도록 시그니처를
  확장한다. 단계 순번(`order`)은 관리자가 입력한 목록 순서로 1부터 자동 부여한다.
- `GeminiTextClient.reviseForTest()`가 `previousTitle`/`previousSteps`를 파라미터로
  받도록 바꾼다(현재 내부 하드코딩 제거).
- `templates/admin/prompts.html`의 REVISE 카드에 이전 제목 입력창 1개, 이전 단계 제목
  textarea 1개, 이전 단계 설명 textarea 1개를 추가한다(두 textarea는 줄 번호로 매칭).
- 관련 단위테스트(`AdminPromptServiceTest`, `GeminiTextClientTest`)를 추가한다.

### 하지 않을 것

- **CREATE/QUESTION 테스트에 닉네임·도움목표·추가답변 입력 UI 추가** — 이번 요청 범위는
  REVISE의 `previousRoutine` 공백 하나로 한정한다(사용자 확인 완료). 필요해지면 별도
  이슈로 다룬다.
- **`client/`(Flutter) 변경** — 관리자 페이지(Thymeleaf SSR)만 대상이며, 실제 서비스
  API 계약(`RoutineCreateRequest`, `RoutineQuestionResponse` 등)은 이미 완료된 이슈 #81
  범위에서 확정되어 있고 이번 작업과 무관하다.
- **입력값 검증(jakarta validation) 추가** — 프로젝트 컨벤션상 `request DTO`에 검증
  어노테이션을 추가하지 않는다. 관리자 전용 테스트 도구이므로 빈 값/줄 수 불일치도
  그대로 통과시키고, 빈 문자열로 채우는 정도로만 방어한다.
- **단계 추가/삭제 등 동적 UI(행 단위 추가 버튼 등)** — textarea 2개 + 줄바꿈 매칭
  방식으로 충분하다고 판단(사용자 확인 완료). 구조화된 반복 입력 폼은 도입하지 않는다.

## 설계

### 1. `PromptSampleRequest` 확장

```java
public record PromptSampleRequest(
  String content,
  String sampleInput,
  CharacterType character,
  String previousTitle,
  List<PreviousStepInput> previousSteps
) {

  public record PreviousStepInput(String title, String description) {

  }
}
```

- `previousTitle`/`previousSteps`는 REVISE가 아닌 키에서는 요청 바디에 포함되어도 그냥
  무시된다(스위치 분기 자체가 참조하지 않음).
- `previousSteps`가 `null`이면 빈 목록으로 취급한다.

### 2. `AdminPromptService` — 시그니처 확장 + 변환 헬퍼

```java
public String preview(
  PromptKey key, String content, String sampleInput, CharacterType character,
  String previousTitle, List<PromptSampleRequest.PreviousStepInput> previousSteps
) {
  return switch (key) {
    ...
    case GEMINI_ROUTINE_REVISE_PREFIX -> "[System]\n" + content + "\n\n[User]\n"
      + geminiTextClient.buildReviseRoutineUserContent(
          previousTitle == null ? "" : previousTitle,
          toStepDrafts(previousSteps), sampleInput, null, Set.of());
    ...
  };
}
```

`test()`도 동일하게 확장하고, REVISE 분기의 `testGeminiRevise()` 호출에 두 값을 추가로
넘긴다.

```java
private List<RoutineStepDraft.StepDraft> toStepDrafts(List<PromptSampleRequest.PreviousStepInput> steps) {
  if (steps == null) {
    return List.of();
  }
  return java.util.stream.IntStream.range(0, steps.size())
    .mapToObj(i -> new RoutineStepDraft.StepDraft(i + 1, steps.get(i).title(), steps.get(i).description()))
    .toList();
}
```

- `order`는 항상 목록 순번(1부터)으로 부여한다 — 관리자가 별도로 순번을 입력할 필요가
  없다.
- 다른 3개 키의 분기는 `previousTitle`/`previousSteps` 파라미터를 참조하지 않는다
  (기존 `character` 파라미터가 IMAGE 외 키에서 무시되는 것과 동일한 패턴).

### 3. `GeminiTextClient.reviseForTest()` — 하드코딩 제거

```java
public GeminiGenerateContentResponse reviseForTest(
  String systemPrompt, String previousTitle, List<RoutineStepDraft.StepDraft> previousSteps,
  String sampleFeedback
) {
  String userContent = buildReviseRoutineUserContent(previousTitle, previousSteps, sampleFeedback, null, Set.of());
  return callGenerateContent(systemPrompt, userContent);
}
```

`buildReviseRoutineUserContent()` 자체는 변경하지 않는다(이미 실제 호출과 동일한 조립
로직을 재사용하는 상태).

### 4. `AdminPromptTestController` — 값 전달

`preview()`/`test()` 호출부에 `request.previousTitle()`, `request.previousSteps()`를
그대로 추가 전달한다. 컨트롤러는 변환/가공 없이 그대로 넘기기만 한다(요청/응답 변환만
담당하는 기존 책임 분리 유지).

### 5. `templates/admin/prompts.html` — REVISE 전용 입력 UI

기존 `character-select`가 `th:if="${prompt.promptKey.name() == 'GEMINI_ROUTINE_IMAGE_PREFIX'}"`
조건으로 IMAGE 카드에만 렌더링되는 것과 동일한 패턴으로, REVISE 카드에만 아래 3개 요소를
추가한다.

```html
<div th:if="${prompt.promptKey.name() == 'GEMINI_ROUTINE_REVISE_PREFIX'}" class="space-y-2">
  <input type="text" class="previous-title input input-bordered w-full"
         th:attr="data-key=${prompt.promptKey}" placeholder="이전 제목"/>
  <textarea class="previous-step-titles textarea textarea-bordered w-full h-20"
            th:attr="data-key=${prompt.promptKey}"
            placeholder="이전 단계 제목 (줄바꿈으로 구분)"></textarea>
  <textarea class="previous-step-descriptions textarea textarea-bordered w-full h-20"
            th:attr="data-key=${prompt.promptKey}"
            placeholder="이전 단계 설명 (줄바꿈으로 구분, 제목과 같은 순서)"></textarea>
</div>
```

JS 헬퍼 추가:

```js
function getPreviousTitleFor(key) {
  const el = document.querySelector('.previous-title[data-key="' + key + '"]');
  return el ? el.value : null;
}

function getPreviousStepsFor(key) {
  const titleEl = document.querySelector('.previous-step-titles[data-key="' + key + '"]');
  const descEl = document.querySelector('.previous-step-descriptions[data-key="' + key + '"]');
  if (!titleEl || !descEl) {
    return [];
  }
  const titles = titleEl.value.split('\n');
  const descriptions = descEl.value.split('\n');
  const length = Math.max(titles.length, descriptions.length);
  const steps = [];
  for (let i = 0; i < length; i++) {
    const title = (titles[i] || '').trim();
    const description = (descriptions[i] || '').trim();
    if (title === '' && description === '') {
      continue;
    }
    steps.push({title: title, description: description});
  }
  return steps;
}
```

`preview-btn`/`test-btn` 클릭 핸들러의 요청 바디에 각각 추가한다.

```js
const data = await callPromptApi(key, '/preview', {
  content: getContentFor(key),
  sampleInput: getSampleInputFor(key),
  character: getCharacterFor(key),
  previousTitle: getPreviousTitleFor(key),
  previousSteps: getPreviousStepsFor(key)
});
```

- REVISE가 아닌 카드에서는 `previous-title`/`previous-step-titles`/`previous-step-descriptions`
  요소 자체가 DOM에 없으므로 `getPreviousTitleFor`/`getPreviousStepsFor`가 각각 `null`,
  `[]`을 반환한다 — 백엔드 다른 분기는 이 값을 참조하지 않으므로 영향 없다.
- 빈 줄만 있는 행(제목·설명 모두 공백)은 걸러내 무의미한 빈 단계가 섞이지 않게 한다.
- 제목/설명 줄 수가 다르면 짧은 쪽을 빈 문자열로 채운다(에러로 처리하지 않음 —
  관리자 전용 테스트 도구이므로 검증보다 관대한 처리를 우선).

## 테스트

프로젝트 규칙상 통합테스트·DB 접근 테스트는 작성하지 않는다. Mockito 기반 단위테스트만
추가한다.

| 대상 | 검증 | 파일 |
| --- | --- | --- |
| `AdminPromptService.preview()` | REVISE 키에서 `previousTitle`/`previousSteps`가 `buildReviseRoutineUserContent()`에 그대로 전달되고, `previousSteps`의 `order`가 1부터 순서대로 부여됨 | `AdminPromptServiceTest`(갱신) |
| `AdminPromptService.test()` | REVISE 키에서 `previousTitle`/`previousSteps`가 `reviseForTest()`에 그대로 전달됨 | `AdminPromptServiceTest`(갱신) |
| `AdminPromptService` | `previousSteps`가 `null`이면 빈 목록으로 변환됨 | `AdminPromptServiceTest`(갱신) |
| `GeminiTextClient.reviseForTest()` | 전달된 `previousTitle`/`previousSteps`가 `previousRoutine.title`/`previousRoutine.steps`(order/title/description)로 정확히 직렬화됨 | `GeminiTextClientTest`(갱신) |

## 범위 밖 / 후속 작업

- CREATE/QUESTION 테스트에 닉네임·도움목표·추가답변 입력 UI 추가 여부는 별도 요청 시
  재검토한다.
- 단계 순서를 관리자가 직접 지정하거나 행 단위로 추가/삭제하는 구조화된 폼은 이번
  범위 밖이다.
