# 일과 추가 질문 추천 답변(이모지+텍스트) 설계

- 날짜: 2026-07-21
- 대상: `server` — `ai/core`, `ai/infrastructure/client`, `routine/infrastructure/ai`,
  `routine/application/dto/response`, `routine/application/controller`

## 배경

보호자가 자연어 일과를 입력하면, 선택한 도움 방식(`PREPARE_ITEMS`/`PREPARE_NEW`)에 따라
Gemini가 추가 질문을 생성한다(`POST /api/routines/questions`). 클라이언트 목업
(`image.png`)을 보면 질문 아래 추천 답변 버튼들이 이모지+텍스트 형태로 나열되고,
그 옆에 "+ 직접 입력하기" 버튼이 있다.

지금 서버 구현은 두 가지가 목업과 다르다.

1. `options`가 순수 문자열 리스트(`List<String>`, 예: `"우산"`)라 이모지가 없다.
2. Gemini 실패 시 쓰이는 고정 대체 답변(`RoutineAiPipeline.fallbackQuestion()`)의
   `PREPARE_NEW` 목록에 `"직접 입력"`이라는 항목이 실제 옵션처럼 하드코딩돼 있다.

이번 작업은 추천 답변에 **이모지를 포함한 구조화된 데이터**를 실어 보내고, "직접 입력"을
옵션 목록에서 완전히 제거해 보호자가 항상 제시된 항목 중에서만 고르도록 만드는 것이다.
자유 텍스트 입력 자체를 없애는 것은 아니고(그건 client 화면 정책), **서버가 추천 답변에
직접입력 성격의 항목을 섞어 보내지 않는 것**이 이번 범위다.

## 범위

### 할 것

- Gemini에게 보내는 응답 스키마(`responseSchema`)를 옵션 하나당 `{emoji, label}`
  객체로, 배열 길이를 3~5개로 제약
- 프롬프트에 "직접 입력 같은 항목 금지, emoji+label 함께 반환" 지시 추가
- `RoutineQuestionDraft` → `RoutineAiPipeline.RoutineQuestionResult` →
  `RoutineQuestionResponse`로 이어지는 세 계층의 `options` 필드를 문자열 배열에서
  `{emoji, label}` 배열로 변경
- Gemini 실패 시 대체 답변(`fallbackQuestion`)에서 `"직접 입력"` 제거, 남은 항목에
  이모지 부여
- Gemini 응답이 스키마를 어겨도 화면이 깨지지 않도록 옵션 단위 방어적 필터링 추가
- Swagger 문서(`RoutineControllerDocs`)에서 "직접입력한 값을" 문구 정리
- 변경된 옵션 구조에 대한 단위테스트 추가/갱신

### 하지 않을 것

- Flutter client 쪽 화면 수정 — server팀은 `server/` 내부만 작업 범위이므로, 클라이언트가
  새 `options` 구조({emoji, label})를 실제로 렌더링하도록 반영하는 작업은 별도 이슈로
  분리한다
- `POST /api/routines`의 `answers` 필드(문자열 배열) 구조 변경 — 보호자가 선택한 옵션의
  `label` 문자열만 그대로 그 배열에 담아 전달하는 흐름은 바뀌지 않는다
- 옵션에 들어갈 이모지를 서버가 직접 고르는 고정 매핑 테이블 도입 — Gemini 호출 경로는
  Gemini가 emoji까지 함께 생성하고, 서버가 개입하는 곳은 Gemini가 아예 응답하지 못했을 때
  쓰는 fallback 목록뿐이다

## 설계

### 1. 옵션 데이터 모델 — 레이어마다 독립된 record 유지

기존 패턴(레이어마다 자신만의 DTO/record를 갖고 경계에서 필드 복사)을 그대로 따른다.
공유 타입을 만들어 계층 간 결합을 만들지 않는다.

```java
// ai/core/RoutineQuestionDraft.java — Gemini 응답 파싱 계층
public record RoutineQuestionDraft(List<QuestionItem> questions) {
  public record QuestionItem(String question, List<Option> options) {
    public record Option(String emoji, String label) {}
  }
}
```

```java
// routine/infrastructure/ai/RoutineAiPipeline.java — 파이프라인 결과 계층
public record RoutineQuestionResult(List<QuestionResultItem> questions) {
  public record QuestionResultItem(String question, List<OptionResult> options) {
    public record OptionResult(String emoji, String label) {}
  }
}
```

```java
// routine/application/dto/response/RoutineQuestionResponse.java — API 응답 계층
public record RoutineQuestionResponse(boolean required, List<QuestionItem> questions) {
  public record QuestionItem(String question, List<OptionItem> options) {
    public record OptionItem(
      @Schema(description = "선택지 이모지", example = "☔") String emoji,
      @Schema(description = "선택지 텍스트", example = "우산") String label
    ) {}
  }
}
```

각 경계의 매핑 코드(`RoutineAiPipeline.generateQuestion()`, `RoutineService.generateQuestion()`)는
`question`/`options` 두 필드를 복사하던 기존 로직에 `options` 리스트 내부의
`emoji`/`label` 복사 한 단계만 추가된다.

### 2. Gemini 응답 스키마 — `GeminiTextClient.questionResponseSchema()`

```java
private Map<String, Object> questionResponseSchema() {
  return Map.of(
    "type", "object",
    "properties", Map.of(
      "questions", Map.of(
        "type", "array",
        "items", Map.of(
          "type", "object",
          "properties", Map.of(
            "question", Map.of("type", "string"),
            "options", Map.of(
              "type", "array",
              "minItems", 3,
              "maxItems", 5,
              "items", Map.of(
                "type", "object",
                "properties", Map.of(
                  "emoji", Map.of("type", "string"),
                  "label", Map.of("type", "string")
                ),
                "required", List.of("emoji", "label")
              )
            )
          ),
          "required", List.of("question", "options")
        )
      )
    ),
    "required", List.of("questions")
  );
}
```

Gemini의 구조화 출력(`responseSchema`)은 OpenAPI 3.0 서브셋을 따르며 배열의
`minItems`/`maxItems`를 지원한다. 다만 모델이 이를 완벽히 지키지 않을 가능성은
남아있으므로, 4번 항목의 방어적 필터링으로 한 번 더 걸러낸다.

### 3. 프롬프트 — `PromptDefaults.GEMINI_ROUTINE_QUESTION_PREFIX`

기존 문구("선택지(options)는 3~5개의 실제 준비물/상황 예시여야 합니다")에 아래 내용을 추가한다.

> 각 선택지는 그 상황을 표현하는 유니코드 이모지(emoji)와 실제 준비물/상황 텍스트(label)를
> 함께 담은 객체여야 합니다. "직접 입력", "기타" 같이 보호자가 자유 텍스트를 입력하도록
> 유도하는 항목은 선택지에 절대 포함하지 마세요.

이 프롬프트는 관리자 페이지(`AdminPromptService`)에서 재정의 가능한 값이므로, 코드에는
`PromptDefaults`의 기본값만 갱신한다.

### 4. Fallback — `RoutineAiPipeline.fallbackQuestion()`

```java
private RoutineQuestionResult fallbackQuestion(Set<SupportGoal> supportGoals) {
  List<QuestionResultItem> questions = new ArrayList<>();
  if (supportGoals.contains(SupportGoal.PREPARE_ITEMS)) {
    questions.add(new QuestionResultItem(
      "꼭 챙겨야 하는 준비물이 있나요?",
      List.of(
        new OptionResult("☔", "우산"),
        new OptionResult("🧥", "우비"),
        new OptionResult("👖", "장화"),
        new OptionResult("🧦", "여벌 양말"),
        new OptionResult("🧻", "작은 수건")
      )
    ));
  }
  if (supportGoals.contains(SupportGoal.PREPARE_NEW)) {
    questions.add(new QuestionResultItem(
      "평소와 다르게 준비해야 하는 점이 있나요?",
      List.of(
        new OptionResult("⏰", "시간 변경"),
        new OptionResult("📍", "장소 변경"),
        new OptionResult("🧑‍🤝‍🧑", "동행자 변경"),
        new OptionResult("🌦️", "날씨/환경 변화")
      )
    ));
  }
  return new RoutineQuestionResult(questions);
}
```

`PREPARE_NEW`는 "직접 입력"을 빼면 4개가 남는데, 3~5개 범위를 만족하므로 대체 항목을
추가하지 않는다.

### 5. 방어적 필터링 — `RoutineAiPipeline.generateQuestion()`

Gemini가 스키마를 어기고 `label`이 빈 옵션을 반환해도 그 질문 전체를 버리지 않고
옵션 단위로만 걸러낸다. 프로젝트 예외 처리 원칙("어떤 오류가 나도 화면이 깨지지 않는다")에
따라, 값 하나가 이상해도 나머지 옵션은 그대로 보여준다.

```java
List<QuestionResultItem> questions = draft.questions().stream()
  .filter(item -> item.question() != null && !item.question().isBlank())
  .map(item -> new QuestionResultItem(
    item.question(),
    item.options().stream()
      .filter(o -> o.label() != null && !o.label().isBlank())
      .map(o -> new OptionResult(o.emoji() == null ? "" : o.emoji(), o.label()))
      .toList()
  ))
  .filter(item -> !item.options().isEmpty())
  .toList();
```

- `label`이 없는 옵션은 버린다(빈 라벨 버튼은 아동에게 보여줄 수 없다)
- `emoji`가 없으면 빈 문자열로 완화한다(라벨은 있는데 이모지만 없다고 질문 자체를
  버리는 것은 과함)
- 필터링 후 옵션이 하나도 안 남은 질문만 통째로 제외한다(기존 동작 유지)

이 필터를 통과한 질문이 하나도 없으면 기존처럼 `catch` 블록에서
`fallbackQuestion()`으로 대체된다.

### 6. Swagger 문서 — `RoutineControllerDocs.generateQuestion`

79번째 줄의 아래 문구를

> `required:true면 questions 각각의 question/options를 사용자에게 순서대로 보여주고,
> 선택/직접입력한 값을 questions 순서 그대로 POST /api/routines의 answers 필드(문자열 배열)로
> 전달하세요.`

다음으로 바꾼다.

> `required:true면 questions 각각의 question/options를 사용자에게 순서대로 보여주고,
> 선택한 옵션의 label 값을 questions 순서 그대로 POST /api/routines의 answers
> 필드(문자열 배열)로 전달하세요. options 각 항목은 emoji/label 쌍이며, 직접 입력
> 항목은 제공하지 않습니다.`

## 테스트

통합테스트·DB 접근 테스트는 프로젝트 규칙상 작성하지 않는다. Mockito 기반 단위테스트만
추가/갱신한다.

| 대상 | 검증 | 파일 |
| --- | --- | --- |
| `RoutineAiPipeline.generateQuestion()` | Gemini 응답을 emoji/label 구조로 정상 매핑 | `RoutineAiPipelineTest`(신설) |
| `RoutineAiPipeline.generateQuestion()` | label 빈 옵션은 걸러내고 나머지는 유지 | 위와 동일 |
| `RoutineAiPipeline.generateQuestion()` | 옵션이 모두 걸러져 questions가 비면 fallback으로 대체 | 위와 동일 |
| `RoutineAiPipeline.fallbackQuestion()`(간접) | Gemini 예외 시 대체 답변에 "직접 입력"이 없고 각 옵션에 emoji 존재 | 위와 동일 |
| `RoutineService.generateQuestion()` | 파이프라인 결과 → `RoutineQuestionResponse`로 emoji/label 매핑 | `RoutineServiceTest`(갱신) |

## 범위 밖 / 후속 작업

- Flutter client의 질문 화면이 `options.emoji`/`options.label`을 렌더링하도록 반영 —
  별도 이슈로 분리(이번 작업은 서버 API 응답 구조만 바꾼다)
- 이미 배포되어 있는 관리자 프롬프트 오버라이드 값(DB에 저장된 커스텀
  `GEMINI_ROUTINE_QUESTION_PREFIX`)이 있다면, 그 값에는 이번 프롬프트 지시문이
  자동으로 반영되지 않는다 — 관리자가 직접 갱신해야 함(코드 기본값만 바꾸는 것이므로
  DB 마이그레이션 대상 아님)
