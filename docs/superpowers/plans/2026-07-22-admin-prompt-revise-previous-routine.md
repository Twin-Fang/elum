# 관리자 REVISE 프롬프트 테스트 — 이전 루틴 입력 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 관리자 프롬프트 테스트 화면에서 REVISE(`GEMINI_ROUTINE_REVISE_PREFIX`) 프롬프트를
테스트할 때 이전 루틴(제목+단계)을 실제로 입력할 수 있게 해, 하드코딩된 빈 값(`""`, `[]`)
대신 실제 "수정" 시나리오를 재현할 수 있게 한다.

**Architecture:** `PromptSampleRequest`에 `previousTitle`/`previousSteps` 필드를 추가하고,
`AdminPromptService.preview()`/`test()`가 이를 `GeminiTextClient.buildReviseRoutineUserContent()`/
`reviseForTest()`에 그대로 전달하도록 시그니처를 확장한다. 단계 순번(`order`)은 관리자가
입력한 목록 순서로 서비스 계층에서 자동 부여한다. 관리자 화면(Thymeleaf+JS)에는 REVISE
카드에만 이전 제목 입력창 1개와 단계 제목/설명 textarea 2개(줄 번호로 매칭)를 추가한다.

**Tech Stack:** Java 21, Spring Boot 4.1, Jackson 2(`ObjectMapper` 수동 생성), JUnit5 +
Mockito + AssertJ, Thymeleaf, 순수 JS(프레임워크 없음).

## Global Constraints

- `server/` 내부만 수정한다. `client/`(Flutter)는 손대지 않는다.
- 이번 범위는 REVISE 키의 관리자 테스트 경로로 한정한다. CREATE/QUESTION/IMAGE 키와
  실제 서비스 API(`RoutineService` 등)는 건드리지 않는다.
- 통합테스트·`@SpringBootTest`·DB 직접 접근 테스트는 작성하지 않는다. Mockito 기반
  단위테스트만 작성한다.
- request DTO(`dto/request` 패키지)에 `jakarta.validation.constraints` 검증 어노테이션을
  추가하지 않는다.
- `var` 미사용, 명시적 타입 선언. 주석은 한글, WHY가 비직관적일 때만 작성.
- 예외를 삼키지 않는다. 기존 `CustomException` + `ErrorCode` 패턴을 그대로 유지한다.
- 각 태스크 종료 시 `./gradlew compileJava`가 통과해야 한다. 테스트를 추가한 태스크는
  `./gradlew test`도 통과해야 한다.
- 실행 중인 서버에 curl로 요청을 보내는 수동 통합 검증은 하지 않는다. Thymeleaf/JS
  변경은 자동화된 테스트 대상이 아니므로, 코드 리뷰(diff 확인)로만 검증한다.
- 커밋 메시지는 `feat:`/`test:` 등 Conventional Commits 형식, 매 태스크마다 커밋한다.

---

### Task 1: `PromptSampleRequest`에 이전 루틴 필드 추가

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/dto/request/PromptSampleRequest.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/admin/application/dto/request/PromptSampleRequestTest.java` (신설)

**Interfaces:**
- Produces: `PromptSampleRequest.previousTitle()` (`String`, nullable),
  `PromptSampleRequest.previousSteps()` (`List<PromptSampleRequest.PreviousStepInput>`,
  nullable), `PromptSampleRequest.PreviousStepInput(String title, String description)`.
  Task 2가 이 3개 접근자·레코드를 그대로 사용한다.

이 태스크는 순수 DTO 필드 추가라 다른 코드에 영향이 없다(`new PromptSampleRequest(...)`를
직접 호출하는 코드가 없고, Jackson `@RequestBody` 역직렬화로만 생성됨을 확인했다).

- [ ] **Step 1: 실패하는 역직렬화 테스트 작성**

Create `server/src/test/java/com/chuseok22/elumserver/admin/application/dto/request/PromptSampleRequestTest.java`:

```java
package com.chuseok22.elumserver.admin.application.dto.request;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PromptSampleRequestTest {

  private final ObjectMapper objectMapper = new ObjectMapper();

  @Test
  @DisplayName("previousTitle과 previousSteps를 포함한 JSON을 역직렬화한다")
  void deserialize_withPreviousRoutineFields_populatesFields() throws Exception {
    String json = """
      {
        "content": "시스템 프롬프트",
        "sampleInput": "가방을 챙기는 단계를 추가해줘요",
        "character": null,
        "previousTitle": "학교에 갈 준비를 해요",
        "previousSteps": [
          {"title": "일어나기", "description": "침대에서 일어나요."},
          {"title": "옷 입기", "description": "옷을 입어요."}
        ]
      }
      """;

    PromptSampleRequest request = objectMapper.readValue(json, PromptSampleRequest.class);

    assertThat(request.previousTitle()).isEqualTo("학교에 갈 준비를 해요");
    assertThat(request.previousSteps()).hasSize(2);
    assertThat(request.previousSteps().get(0).title()).isEqualTo("일어나기");
    assertThat(request.previousSteps().get(0).description()).isEqualTo("침대에서 일어나요.");
    assertThat(request.previousSteps().get(1).title()).isEqualTo("옷 입기");
    assertThat(request.previousSteps().get(1).description()).isEqualTo("옷을 입어요.");
  }

  @Test
  @DisplayName("previousTitle과 previousSteps가 없어도(다른 프롬프트 키) 역직렬화가 실패하지 않는다")
  void deserialize_withoutPreviousRoutineFields_defaultsToNull() throws Exception {
    String json = "{\"content\":\"시스템 프롬프트\",\"sampleInput\":\"비 오는 날 학교 가기\",\"character\":null}";

    PromptSampleRequest request = objectMapper.readValue(json, PromptSampleRequest.class);

    assertThat(request.previousTitle()).isNull();
    assertThat(request.previousSteps()).isNull();
  }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `./gradlew test --tests "*PromptSampleRequestTest*"`
Expected: FAIL — `previousTitle`/`previousSteps`/`PreviousStepInput`이 아직 없어 컴파일 실패.

- [ ] **Step 3: `PromptSampleRequest.java` 전체 교체**

`server/src/main/java/com/chuseok22/elumserver/admin/application/dto/request/PromptSampleRequest.java`
전체를 아래로 교체한다.

```java
package com.chuseok22.elumserver.admin.application.dto.request;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import java.util.List;

// content/sampleInput 모두 검증 없이 그대로 전달한다 — 빈 값이어도 AI 호출 자체는
// 가능하고(결과가 유의미하지 않을 뿐), 관리자 전용 테스트 도구이므로 최소한으로 둔다.
// character는 GEMINI_ROUTINE_IMAGE_PREFIX 테스트에서만 쓰이고 다른 키에서는 무시된다.
// previousTitle/previousSteps는 GEMINI_ROUTINE_REVISE_PREFIX 테스트에서만 쓰이고
// 다른 키에서는 무시된다 — REVISE 실제 호출의 previousRoutine을 관리자 화면에서
// 재현하기 위한 필드다.
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

- [ ] **Step 4: 테스트 통과 확인**

Run: `./gradlew test --tests "*PromptSampleRequestTest*"`
Expected: `BUILD SUCCESSFUL`, 2개 테스트 PASS

- [ ] **Step 5: 전체 컴파일 확인**

Run: `./gradlew compileJava`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 6: Commit**

```bash
git add server/src/main/java/com/chuseok22/elumserver/admin/application/dto/request/PromptSampleRequest.java \
  server/src/test/java/com/chuseok22/elumserver/admin/application/dto/request/PromptSampleRequestTest.java
git commit -m "feat: PromptSampleRequest에 REVISE 이전 루틴 입력 필드 추가"
```

---

### Task 2: `GeminiTextClient`/`AdminPromptService`/`AdminPromptTestController` 연결

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/ai/infrastructure/client/GeminiTextClient.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/service/AdminPromptService.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/controller/AdminPromptTestController.java`
- Modify: `server/src/test/java/com/chuseok22/elumserver/admin/application/service/AdminPromptServiceTest.java`

**Interfaces:**
- Consumes: `PromptSampleRequest.previousTitle()`/`previousSteps()`/`PreviousStepInput`(Task 1)
- Produces: `GeminiTextClient.reviseForTest(String systemPrompt, String previousTitle,
  List<RoutineStepDraft.StepDraft> previousSteps, String sampleFeedback)` — 시그니처가
  2개 파라미터에서 4개로 바뀜(기존 2-파라미터 오버로드는 제거). `AdminPromptService.preview(...)`/
  `test(...)`는 각각 6개 파라미터로 확장됨(`previousTitle`, `previousSteps` 추가).

> **참고**: `GeminiTextClient`의 `*ForTest` 계열 메서드(`generateForTest`,
> `generateQuestionForTest`, 기존 `reviseForTest`)는 지금도 `GeminiTextClientTest`에 별도
> 단위테스트가 없다 — 이 클래스 테스트는 순수 조립 메서드(`build*UserContent`)만 다루고,
> `*ForTest` 래퍼는 `AdminPromptServiceTest`에서 `geminiTextClient`를 Mockito `@Mock`으로
> 대체해 "정확한 인자로 호출되는지"만 검증하는 기존 패턴을 그대로 따른다. 따라서 이번
> 태스크도 `GeminiTextClientTest.java`는 건드리지 않는다.

이 3개 프로덕션 파일은 호출 관계로 강하게 묶여 있어(`AdminPromptTestController` →
`AdminPromptService` → `GeminiTextClient`) 한 번에 함께 바꾼다 — 하나만 바꾸면 나머지
호출부가 컴파일 에러를 낸다. 대신 테스트를 먼저 새 시그니처 기준으로 작성해 컴파일
실패(RED)를 확인한 뒤, 3개 파일을 한 번에 구현(GREEN)한다.

- [ ] **Step 1: 새 시그니처를 기대하는 테스트로 갱신(RED)**

`server/src/test/java/com/chuseok22/elumserver/admin/application/service/AdminPromptServiceTest.java`
상단 import 목록 마지막 줄(`import org.mockito.junit.jupiter.MockitoExtension;`) 다음에
빈 줄을 두고 아래 4줄을 추가한다.

```java
import com.chuseok22.elumserver.admin.application.dto.request.PromptSampleRequest;
import com.chuseok22.elumserver.admin.application.dto.response.PromptTestResponse;
import com.chuseok22.elumserver.ai.core.RoutineStepDraft;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse;
import java.util.List;
```

기존 3개 테스트의 `preview(...)` 호출부를 찾아 각각 끝에 `, null, null`을 추가해 새
6-파라미터 시그니처를 호출하도록 바꾼다.

```java
    String result = adminPromptService.preview(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "시스템 프롬프트", "일과 원문", null);
```
→
```java
    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "시스템 프롬프트", "일과 원문", null, null, null
    );
```

```java
    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX, "이미지 프롬프트", "옷을 입어요", CharacterType.LULU
    );
```
→
```java
    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX, "이미지 프롬프트", "옷을 입어요", CharacterType.LULU, null, null
    );
```

```java
    String result = adminPromptService.preview(
      PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK, "시스템 프롬프트", "김민준입니다", null
    );
```
→
```java
    String result = adminPromptService.preview(
      PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK, "시스템 프롬프트", "김민준입니다", null, null, null
    );
```

파일 끝(마지막 `}` 바로 앞)에 REVISE 전용 신규 테스트 3개를 추가한다.

```java

  @Test
  @DisplayName("GEMINI_ROUTINE_REVISE_PREFIX preview는 previousTitle/previousSteps에 order 1부터 부여해 전달한다")
  void preview_revisePrefix_passesPreviousRoutineFieldsWithAssignedOrder() {
    List<PromptSampleRequest.PreviousStepInput> previousSteps = List.of(
      new PromptSampleRequest.PreviousStepInput("일어나기", "침대에서 일어나요."),
      new PromptSampleRequest.PreviousStepInput("옷 입기", "옷을 입어요.")
    );
    List<RoutineStepDraft.StepDraft> expectedStepDrafts = List.of(
      new RoutineStepDraft.StepDraft(1, "일어나기", "침대에서 일어나요."),
      new RoutineStepDraft.StepDraft(2, "옷 입기", "옷을 입어요.")
    );
    when(geminiTextClient.buildReviseRoutineUserContent(
      "학교에 갈 준비를 해요", expectedStepDrafts, "가방을 챙기는 단계를 추가해줘요", null, java.util.Set.of()
    )).thenReturn("{\"task\":\"REVISE_ROUTINE\"}");

    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_REVISE_PREFIX, "시스템 프롬프트", "가방을 챙기는 단계를 추가해줘요", null,
      "학교에 갈 준비를 해요", previousSteps
    );

    assertThat(result).contains("{\"task\":\"REVISE_ROUTINE\"}");
  }

  @Test
  @DisplayName("previousTitle/previousSteps가 null이면 빈 문자열/빈 목록으로 전달한다")
  void preview_revisePrefix_nullPreviousRoutine_passesEmptyDefaults() {
    when(geminiTextClient.buildReviseRoutineUserContent(
      "", List.of(), "피드백", null, java.util.Set.of()
    )).thenReturn("{}");

    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_REVISE_PREFIX, "시스템 프롬프트", "피드백", null, null, null
    );

    assertThat(result).contains("{}");
  }

  @Test
  @DisplayName("GEMINI_ROUTINE_REVISE_PREFIX test는 previousTitle/previousSteps를 reviseForTest에 그대로 전달한다")
  void test_revisePrefix_passesPreviousRoutineFieldsToReviseForTest() {
    List<PromptSampleRequest.PreviousStepInput> previousSteps = List.of(
      new PromptSampleRequest.PreviousStepInput("일어나기", "침대에서 일어나요.")
    );
    List<RoutineStepDraft.StepDraft> expectedStepDrafts = List.of(
      new RoutineStepDraft.StepDraft(1, "일어나기", "침대에서 일어나요.")
    );
    GeminiGenerateContentResponse fakeResponse = new GeminiGenerateContentResponse(
      List.of(new GeminiGenerateContentResponse.Candidate(
        new GeminiGenerateContentResponse.Content(
          List.of(new GeminiGenerateContentResponse.Part(
            "{\"title\":\"학교에 갈 준비를 해요\",\"steps\":"
              + "[{\"order\":1,\"title\":\"일어나기\",\"description\":\"침대에서 일어나요.\"}]}",
            null
          ))
        )
      ))
    );
    when(geminiTextClient.reviseForTest(
      "시스템 프롬프트", "학교에 갈 준비를 해요", expectedStepDrafts, "가방을 챙기는 단계를 추가해줘요"
    )).thenReturn(fakeResponse);

    PromptTestResponse response = adminPromptService.test(
      PromptKey.GEMINI_ROUTINE_REVISE_PREFIX, "시스템 프롬프트", "가방을 챙기는 단계를 추가해줘요", null,
      "학교에 갈 준비를 해요", previousSteps
    );

    assertThat(response.result()).isNotNull();
  }
```

- [ ] **Step 2: 컴파일 실패 확인**

Run: `./gradlew compileTestJava`
Expected: FAIL — `AdminPromptService.preview()`/`test()`가 아직 4-파라미터 시그니처이고
`geminiTextClient.reviseForTest(...)`도 4-인자 오버로드가 없어 컴파일 에러.

- [ ] **Step 3: `GeminiTextClient.reviseForTest()` 시그니처 변경**

`server/src/main/java/com/chuseok22/elumserver/ai/infrastructure/client/GeminiTextClient.java`에서
아래 블록을 찾는다.

```java
  // 관리자 테스트 전용: previousRoutine이 없는 관리자 샘플 입력이라, title은 빈 문자열/
  // steps는 빈 배열로 두고 sampleInput 전체를 feedback으로만 취급한다.
  public GeminiGenerateContentResponse reviseForTest(String systemPrompt, String sampleFeedback) {
    String userContent = buildReviseRoutineUserContent("", List.of(), sampleFeedback, null, Set.of());
    return callGenerateContent(systemPrompt, userContent);
  }
```

아래로 교체한다.

```java
  // 관리자 테스트 전용: 관리자 화면에서 입력한 이전 제목/단계를 그대로 전달한다.
  public GeminiGenerateContentResponse reviseForTest(
    String systemPrompt, String previousTitle, List<RoutineStepDraft.StepDraft> previousSteps,
    String sampleFeedback
  ) {
    String userContent = buildReviseRoutineUserContent(previousTitle, previousSteps, sampleFeedback, null, Set.of());
    return callGenerateContent(systemPrompt, userContent);
  }
```

- [ ] **Step 4: `AdminPromptService.java` 수정**

상단 import 목록에서 `import com.chuseok22.elumserver.admin.application.dto.response.PromptTestResponse;`
바로 위에 아래 줄을 추가한다.

```java
import com.chuseok22.elumserver.admin.application.dto.request.PromptSampleRequest;
```

`import java.util.Set;` 다음 줄에 아래 줄을 추가한다.

```java
import java.util.stream.IntStream;
```

`preview()` 메서드 전체를 아래로 교체한다.

```java
  // 각 클라이언트의 실제 프롬프트 조립 메서드를 그대로 재사용한다 — preview와 실제 호출이
  // 항상 같은 결과를 내도록, <text> 태그나 JSON 래핑을 이 메서드가 직접 조립하지 않는다.
  public String preview(
    PromptKey key, String content, String sampleInput, CharacterType character,
    String previousTitle, List<PromptSampleRequest.PreviousStepInput> previousSteps
  ) {
    return switch (key) {
      case LOCAL_LLM_SENSITIVE_INFO_CHECK ->
        "[System]\n" + content + "\n\n[User]\n" + sensitiveInfoGuardService.buildUserContent(sampleInput);
      case GEMINI_ROUTINE_CREATE_PREFIX -> "[System]\n" + content + "\n\n[User]\n"
        + geminiTextClient.buildCreateRoutineUserContent(sampleInput, null, Set.of(), List.of());
      case GEMINI_ROUTINE_REVISE_PREFIX -> "[System]\n" + content + "\n\n[User]\n"
        + geminiTextClient.buildReviseRoutineUserContent(
            previousTitle == null ? "" : previousTitle, toStepDrafts(previousSteps), sampleInput, null, Set.of());
      case GEMINI_ROUTINE_QUESTION_PREFIX -> "[System]\n" + content + "\n\n[User]\n"
        + geminiTextClient.buildQuestionUserContent(sampleInput, null, Set.of());
      case GEMINI_ROUTINE_IMAGE_PREFIX -> imagePromptBuilder.build(content, sampleInput, character);
    };
  }
```

`test()` 메서드 전체를 아래로 교체한다.

```java
  public PromptTestResponse test(
    PromptKey key, String content, String sampleInput, CharacterType characterType,
    String previousTitle, List<PromptSampleRequest.PreviousStepInput> previousSteps
  ) {
    return switch (key) {
      case LOCAL_LLM_SENSITIVE_INFO_CHECK -> {
        SensitiveInfoCheckResult result = sensitiveInfoGuardService.checkForTest(content, sampleInput);
        yield new PromptTestResponse(result, null);
      }
      case GEMINI_ROUTINE_CREATE_PREFIX -> {
        RoutineStepDraft draft = testGeminiText(content, sampleInput);
        yield new PromptTestResponse(draft, null);
      }
      case GEMINI_ROUTINE_REVISE_PREFIX -> {
        RoutineStepDraft draft = testGeminiRevise(content, previousTitle, previousSteps, sampleInput);
        yield new PromptTestResponse(draft, null);
      }
      case GEMINI_ROUTINE_QUESTION_PREFIX -> {
        RoutineQuestionDraft draft = testGeminiQuestion(content, sampleInput);
        yield new PromptTestResponse(draft, null);
      }
      case GEMINI_ROUTINE_IMAGE_PREFIX -> {
        String dataUri = testGeminiImage(content, sampleInput, characterType);
        yield new PromptTestResponse(null, dataUri);
      }
    };
  }
```

`testGeminiRevise()` 메서드 전체를 아래로 교체한다.

```java
  private RoutineStepDraft testGeminiRevise(
    String systemPrompt, String previousTitle, List<PromptSampleRequest.PreviousStepInput> previousSteps,
    String sampleFeedback
  ) {
    try {
      GeminiGenerateContentResponse response = geminiTextClient.reviseForTest(
        systemPrompt, previousTitle == null ? "" : previousTitle, toStepDrafts(previousSteps), sampleFeedback
      );
      String json = response.candidates().get(0).content().parts().get(0).text();
      return objectMapper.readValue(json, RoutineStepDraft.class);
    } catch (Exception e) {
      log.warn("[관리자 테스트] Gemini 루틴 수정 테스트 실패: systemPrompt={}, sampleInput={}", systemPrompt, sampleFeedback, e);
      throw new CustomException(ErrorCode.PROMPT_TEST_GEMINI_TEXT_FAILED);
    }
  }
```

`testGeminiQuestion()` 메서드 바로 뒤에 아래 private 헬퍼를 새로 추가한다.

```java

  // 관리자가 입력한 이전 단계 목록(title/description)을 실제 호출과 동일한
  // RoutineStepDraft.StepDraft로 변환한다. order는 입력 목록 순서로 1부터 부여한다 —
  // 관리자가 순번을 직접 관리할 필요가 없게 하기 위함이다.
  private List<RoutineStepDraft.StepDraft> toStepDrafts(List<PromptSampleRequest.PreviousStepInput> steps) {
    if (steps == null) {
      return List.of();
    }
    return IntStream.range(0, steps.size())
      .mapToObj(i -> new RoutineStepDraft.StepDraft(i + 1, steps.get(i).title(), steps.get(i).description()))
      .toList();
  }
```

- [ ] **Step 5: `AdminPromptTestController.java` 수정**

`server/src/main/java/com/chuseok22/elumserver/admin/application/controller/AdminPromptTestController.java`의
`preview()`/`test()` 메서드를 아래로 교체한다.

```java
  @PostMapping("/admin/prompts/{key}/preview")
  public PromptPreviewResponse preview(@PathVariable PromptKey key, @RequestBody PromptSampleRequest request) {
    String composed = adminPromptService.preview(
      key, request.content(), request.sampleInput(), request.character(),
      request.previousTitle(), request.previousSteps()
    );
    return new PromptPreviewResponse(composed);
  }

  @PostMapping("/admin/prompts/{key}/test")
  public PromptTestResponse test(@PathVariable PromptKey key, @RequestBody PromptSampleRequest request) {
    return adminPromptService.test(
      key, request.content(), request.sampleInput(), request.character(),
      request.previousTitle(), request.previousSteps()
    );
  }
```

- [ ] **Step 6: 컴파일 확인(GREEN)**

Run: `./gradlew compileJava compileTestJava`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 7: `AdminPromptServiceTest` 전체 실행**

Run: `./gradlew test --tests "*AdminPromptServiceTest*"`
Expected: `BUILD SUCCESSFUL`, 기존 3개 + 신규 3개 = 총 6개 테스트 PASS

- [ ] **Step 8: 전체 빌드 확인**

Run: `./gradlew build -x test`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 9: Commit**

```bash
git add server/src/main/java/com/chuseok22/elumserver/ai/infrastructure/client/GeminiTextClient.java \
  server/src/main/java/com/chuseok22/elumserver/admin/application/service/AdminPromptService.java \
  server/src/main/java/com/chuseok22/elumserver/admin/application/controller/AdminPromptTestController.java \
  server/src/test/java/com/chuseok22/elumserver/admin/application/service/AdminPromptServiceTest.java
git commit -m "feat: 관리자 REVISE 프롬프트 테스트가 이전 루틴 입력을 실제 호출에 반영하도록 연결"
```

---

### Task 3: 관리자 화면(`prompts.html`)에 이전 루틴 입력 UI 추가

**Files:**
- Modify: `server/src/main/resources/templates/admin/prompts.html`

**Interfaces:**
- Consumes: Task 2에서 확장된 `/admin/prompts/{key}/preview`, `/admin/prompts/{key}/test`
  요청 바디의 `previousTitle`(`String`), `previousSteps`(`[{title, description}]`) 필드.

이 태스크는 Thymeleaf 템플릿과 순수 JS만 변경한다. 프로젝트 규칙상 Thymeleaf/JS는
자동화 테스트 대상이 아니므로(수동 서버 기동·curl 검증 금지), 검증은
`./gradlew compileJava`(다른 레이어에 영향 없음 확인)와 diff 리뷰로 한정한다.

- [ ] **Step 1: REVISE 카드에 입력 요소 추가**

`server/src/main/resources/templates/admin/prompts.html`에서 아래 블록(기존
`character-select` 바로 다음)을 찾는다.

```html
          <select th:if="${prompt.promptKey.name() == 'GEMINI_ROUTINE_IMAGE_PREFIX'}"
                  class="character-select select select-bordered w-full"
                  th:attr="data-key=${prompt.promptKey}">
            <option value="">캐릭터 미지정</option>
            <option value="LULU">루루</option>
            <option value="POPO">포포</option>
          </select>
```

바로 다음 줄에 아래 블록을 추가한다.

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

- [ ] **Step 2: JS 헬퍼 함수 추가**

같은 파일의 `<script>` 블록에서 아래 함수를 찾는다.

```js
  function getCharacterFor(key) {
    const select = document.querySelector('.character-select[data-key="' + key + '"]');
    return select && select.value ? select.value : null;
  }
```

바로 다음 줄에 아래 두 함수를 추가한다.

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

- [ ] **Step 3: preview-btn 요청 바디에 필드 추가**

아래 블록을 찾는다.

```js
        const data = await callPromptApi(key, '/preview', {
          content: getContentFor(key),
          sampleInput: getSampleInputFor(key),
          character: getCharacterFor(key)
        });
```

아래로 교체한다.

```js
        const data = await callPromptApi(key, '/preview', {
          content: getContentFor(key),
          sampleInput: getSampleInputFor(key),
          character: getCharacterFor(key),
          previousTitle: getPreviousTitleFor(key),
          previousSteps: getPreviousStepsFor(key)
        });
```

- [ ] **Step 4: test-btn 요청 바디에 필드 추가**

아래 블록을 찾는다.

```js
        const data = await callPromptApi(key, '/test', {
          content: getContentFor(key),
          sampleInput: getSampleInputFor(key),
          character: getCharacterFor(key)
        });
```

아래로 교체한다.

```js
        const data = await callPromptApi(key, '/test', {
          content: getContentFor(key),
          sampleInput: getSampleInputFor(key),
          character: getCharacterFor(key),
          previousTitle: getPreviousTitleFor(key),
          previousSteps: getPreviousStepsFor(key)
        });
```

- [ ] **Step 5: 다른 레이어 영향 없음 확인**

Run: `./gradlew compileJava`
Expected: `BUILD SUCCESSFUL` (템플릿/JS만 변경했으므로 Java 컴파일에는 영향이 없어야 한다)

- [ ] **Step 6: diff 리뷰**

`git diff server/src/main/resources/templates/admin/prompts.html`로 변경 내용을 확인한다.
확인 항목:
- REVISE가 아닌 카드(CREATE/QUESTION/IMAGE)에는 새 입력 요소가 렌더링되지 않는지
  (`th:if` 조건이 REVISE 키에만 걸려 있는지)
- `getPreviousTitleFor`/`getPreviousStepsFor`가 요소가 없는 카드에서 각각 `null`/`[]`을
  반환해 다른 카드의 기존 동작(요청 바디에 `previousTitle: null, previousSteps: []`가
  추가되는 것)에 부작용이 없는지 — Task 2에서 다른 키 분기는 이 두 파라미터를 참조하지
  않으므로 안전함을 코드로 재확인

- [ ] **Step 7: Commit**

```bash
git add server/src/main/resources/templates/admin/prompts.html
git commit -m "feat: 관리자 화면에 REVISE 프롬프트용 이전 루틴 입력 UI 추가"
```

## 남은 이슈 / 범위 밖

- CREATE/QUESTION 테스트에 닉네임·도움목표·추가답변 입력 UI 추가는 이번 범위 밖이다
  (스펙 문서 참고).
- Thymeleaf/JS 변경은 프로젝트 규칙상 자동화 테스트가 없어, 실제 브라우저 동작 확인은
  배포 후 관리자가 `/admin/prompts` 화면에서 직접 확인해야 한다.
