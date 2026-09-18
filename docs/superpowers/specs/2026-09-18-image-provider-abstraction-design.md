# 이미지 생성 프로바이더 추상화

> 이슈: https://github.com/Twin-Fang/elum/issues/246

> 관련 설계: [라이선스·권한](./2026-09-18-license-entitlement-design.md) ·
> [Free 픽토그램](./2026-09-18-free-pictogram-design.md) ·
> [관리자 화면 개편](./2026-09-18-admin-console-revamp-design.md)

## 배경

카드 삽화 생성이 Gemini에 고정돼 있다. 두 가지가 문제다.

### 1. 비용이 대안보다 7~8배 비싸다

현재 단가는 `ConfigKey.PRICE_GEMINI_IMAGE_PER_IMAGE = $0.039`다. 카드는 최대 10장
(`RoutineAiPipeline.MAX_STEPS`)이므로 일과 하나가 **$0.39(약 550원)** 다.

| 프로바이더 | 1장 단가 | 일과 1개(10장) |
| --- | --- | --- |
| Gemini 2.5 Flash Image (현재) | $0.039 | $0.39 · 약 550원 |
| GPT Image 1 Mini (low) | ~$0.005 | $0.05 · 약 70원 |
| FLUX schnell (fal.ai fast) | ~$0.006 | $0.06 · 약 84원 |
| FLUX.2 klein 4B | ~$0.014 | $0.14 · 약 196원 |

> 단가는 2026-09 중순 기준으로 사용자가 조사해 전달한 값이다. **이 표를 코드에 박지
> 않는다.** 단가는 시스템 설정으로 두고 실제 청구서와 대조해 갱신한다.

요금제 한도(주 몇 회 등)를 정하려면 원가가 먼저 확정돼야 한다. 550원과 70원 위에서
정하는 숫자는 8배 다르다. **그래서 이 작업이 요금제보다 앞선다.**

### 2. 갈아끼울 수 없다

`GeneratedImage`가 `GeminiImageClient`의 **중첩 타입**이라 Gemini라는 이름이 네 파일로
새어 있다.

| 파일 | 어떻게 새어 있나 |
| --- | --- |
| `routine/.../RoutineStepImageFiller.java` | 필드 주입 + 반환 타입 |
| `routine/.../RoutineImageStorage.java` | `save(..., GeminiImageClient.GeneratedImage)` 파라미터 타입 |
| `routine/.../RoutineAiPipeline.java` | 필드 + `generateImageWithRetry` 반환 타입 |
| `admin/.../AdminPromptService.java` | 관리자 미리보기 호출 |

저장소가 특정 프로바이더의 타입을 아는 것이 가장 큰 문제다. 저장소는 바이트와
MIME 타입만 알면 된다.

### 이미 있는 것

새로 만들지 않아도 되는 것들이다.

- **모델명·비율이 이미 설정값이다.** `GeminiImageClient`가 호출 시점마다
  `SystemConfigService`에서 읽는다 (*"관리자가 바꾸면 재배포 없이 반영된다"*).
- **비용이 이미 기록된다.** `AiCallLog.estimatedCostUsd` — 기록 시점 단가로 계산해
  저장하므로 단가가 바뀌어도 과거 기록이 불변이다.
- **관리자 이미지 테스트가 이미 있다.** `GeminiImageClient.generateImageForTest`,
  `AdminPromptService`, `AdminPromptTestController`.

즉 **프로바이더별 비용 비교 화면은 따로 만들 필요가 없다.** 단가 키만 추가하면
기존 모니터링에 그대로 나온다.

## 목표 / 비목표

**목표**

1. 관리자 화면에서 재배포 없이 프로바이더를 전환한다.
2. 프로바이더별 단가를 설정으로 관리해 실제 비용을 비교한다.
3. 같은 프롬프트로 여러 프로바이더 결과를 나란히 확인한다.
4. 호출부(`RoutineAiPipeline` 등)가 어느 프로바이더인지 모르게 한다.

**비목표** (이번에 하지 않는다)

- 실패 시 다른 프로바이더로 넘어가는 **자동 폴백 체인**. 지금은 수동 전환만 한다.
  폴백은 비용 예측을 깨뜨리고, 어느 모델이 그렸는지 추적을 어렵게 한다.
- 이미지 후처리·업스케일.
- 프로바이더별 프롬프트 자동 최적화. 프롬프트는 지금처럼 `PromptTemplate`로 관리한다.

## 캐릭터 일관성이 선택을 제약한다 ⚠️

이 설계에서 가장 중요한 제약이다.

> `Profile.character` 주석 — *"카드 삽화에 등장하는 캐릭터. **단계마다 같은 모습이어야
> 한 이야기로 읽힌다.**"*

Gemini는 `CharacterReferenceProvider`가 주는 참조 이미지를 멀티모달 입력의
**첫 파트**로 함께 보내 단계마다 같은 캐릭터를 유지한다. 프로바이더마다 이 능력이
다르다. 참조 이미지를 못 받는 모델을 고르면 **단계마다 다른 캐릭터가 나온다.**

그러면 [라이선스 설계](./2026-09-18-license-entitlement-design.md)에서 정한 Pro의
핵심 가치 — *"우리 이룸이가 그림에 나와요"* — 가 그대로 무너진다. 싸다고 골랐다가
파는 물건이 사라지는 것이다.

**그래서 인터페이스가 이 능력을 노출한다.** 미지원 프로바이더도 선택은 가능하되
(비용·품질 비교 목적), 관리자 화면이 무슨 일이 일어나는지 경고한다.

## 설계

### 타입 (`ai/core/`)

```java
/// 프로바이더 중립 이미지 결과. 저장소는 이것만 알면 된다.
public record GeneratedImage(byte[] data, String mimeType) {}

/// 지원 프로바이더. 관리자 화면 SELECT의 허용값이기도 하다.
public enum ImageProvider {
  GEMINI("Gemini 2.5 Flash Image"),
  OPENAI_IMAGE_MINI("GPT Image 1 Mini"),
  FLUX_SCHNELL("FLUX schnell");

  private final String label;
}

/// 생성 요청. 프로바이더별 파라미터는 각 구현체가 설정에서 읽는다.
public record ImageGenerationRequest(
  String promptPrefix,
  String stepDescription,
  CharacterType characterType   // null 가능 — 캐릭터 미선택 회원
) {}
```

### 인터페이스 (`ai/infrastructure/client/`)

```java
public interface ImageGenerationClient {

  ImageProvider provider();

  /// API 키 등 필수 설정이 갖춰졌는가. 관리자 화면의 선택 가능 여부 표시에 쓴다.
  /// 키가 없는 프로바이더를 고르는 사고를 저장 단계에서 막기 위해 필요하다.
  boolean available();

  /// 참조 이미지로 캐릭터 일관성을 유지할 수 있는가.
  /// false면 단계마다 다른 캐릭터가 나온다 — 관리자 화면이 경고한다.
  boolean supportsCharacterReference();

  GeneratedImage generate(ImageGenerationRequest request);
}
```

구현체는 `GeminiImageClient`(기존), `OpenAiImageClient`(신규),
`FluxImageClient`(신규). 각 구현체가 **자기 AiCallLog 기록과 비용 계산을 책임진다** —
단가 키가 프로바이더마다 다르기 때문이다.

### 라우터

```java
@Component
@RequiredArgsConstructor
public class ImageClientRouter {

  private final List<ImageGenerationClient> clients;   // Spring이 전부 주입
  private final SystemConfigService systemConfigService;

  public ImageGenerationClient current() {
    ImageProvider selected = resolveSelected();
    return byProvider(selected)
      .filter(ImageGenerationClient::available)
      .orElseThrow(() -> new CustomException(ErrorCode.IMAGE_PROVIDER_UNAVAILABLE));
  }

  /// 관리자 비교 테스트용 — 설정과 무관하게 지정 프로바이더를 가져온다.
  public Optional<ImageGenerationClient> of(ImageProvider provider) { ... }

  /// DB 값이 손상됐거나 enum에서 사라진 이름이어도 기동·생성이 죽지 않게 GEMINI로
  /// 폴백한다. SystemConfigService의 파싱 실패 폴백과 같은 방침이다.
  private ImageProvider resolveSelected() {
    String raw = systemConfigService.getString(ConfigKey.IMAGE_PROVIDER);
    try {
      return ImageProvider.valueOf(raw.trim());
    } catch (IllegalArgumentException e) {
      log.warn("알 수 없는 이미지 프로바이더 설정, 기본값 사용: value={}", raw);
      return ImageProvider.GEMINI;
    }
  }
}
```

### 설정 키 추가

| 키 | 그룹 | 타입 | 기본값 |
| --- | --- | --- | --- |
| `IMAGE_PROVIDER` | IMAGE_PROVIDER(신규) | SELECT | `GEMINI` |
| `OPENAI_IMAGE_MODEL` | IMAGE_PROVIDER | STRING | `gpt-image-1-mini` |
| `OPENAI_IMAGE_QUALITY` | IMAGE_PROVIDER | SELECT | `low` |
| `FLUX_IMAGE_MODEL` | IMAGE_PROVIDER | STRING | `flux-schnell` |
| `PRICE_OPENAI_IMAGE_PER_IMAGE` | PRICING | DECIMAL | `0.005` |
| `PRICE_FLUX_IMAGE_PER_IMAGE` | PRICING | DECIMAL | `0.006` |

기존 `GEMINI_IMAGE_MODEL`·`GEMINI_IMAGE_ASPECT_RATIO`·
`PRICE_GEMINI_IMAGE_PER_IMAGE`는 그대로 둔다.

`ConfigKey`에 키를 추가하면 `SystemConfigInitializer`가 기본값을 시딩하고 관리자
설정 화면에 자동으로 뜬다. **화면 코드를 건드릴 필요가 없다.**

### API 키는 DB에 넣지 않는다

지금 Gemini 키가 `GeminiProperties`(yml/환경변수)에 있는 것과 같이 간다.
`OpenAiProperties`, `FluxProperties`를 같은 방식으로 만든다.

**`SystemConfig`(DB)에 키를 넣지 않는 이유** — DB가 유출되면 키가 함께 새고, 관리자
설정 화면은 값을 그대로 렌더링하므로 화면에 키가 노출된다. 관리자가 화면에서 고르는
것은 **"어느 프로바이더를 쓸지"까지**다.

### AiCallType 확장

```java
GEMINI_IMAGE("Gemini 이미지"),        // 기존 — 유지
OPENAI_IMAGE("OpenAI 이미지"),        // 신규
FLUX_IMAGE("FLUX 이미지"),            // 신규
```

기존 로그가 `GEMINI_IMAGE`로 쌓여 있으므로 **통합하지 않고 추가**한다. 관리자
모니터링 필터에서 프로바이더별 비용·실패율이 자동으로 갈린다.

## 행복 경로

```
관리자가 설정 화면에서 IMAGE_PROVIDER를 OPENAI_IMAGE_MINI로 바꾼다
  → SystemConfig 저장, 최대 30초 내 전 인스턴스 반영 (기존 TTL 캐시)
  → 다음 일과 생성부터 ImageClientRouter.current()가 OpenAiImageClient를 돌려준다
  → 구현체가 OPENAI_IMAGE 타입으로 AiCallLog 기록, PRICE_OPENAI_* 단가로 비용 계산
  → 대시보드 "오늘 AI 추정 비용"과 모니터링 화면에 새 단가가 즉시 반영
```

## 실패 경로

| 상황 | 동작 | 사용자에게 |
| --- | --- | --- |
| 고른 프로바이더의 API 키 없음 | `available()=false` → 설정 저장 단계에서 거부 | 관리자 화면에 "API 키 없음" 배지, 저장 실패 메시지 |
| DB 값이 알 수 없는 이름 | 경고 로그 + `GEMINI` 폴백 | 생성은 정상 진행 |
| 호출 타임아웃·5xx | 기존 `generateImageWithRetry` 재시도 → 최종 실패 시 **이미지 없이 카드 생성** | 현재 동작 유지 — 일과 생성 자체는 성공 |
| 응답에 이미지 데이터 없음 | 구현체가 실패로 기록, 위와 동일 | 〃 |
| 캐릭터 미지원 프로바이더 선택 | 참조 이미지 없이 생성 | 관리자 화면에 "캐릭터 일관성 미지원" 경고 배지 |

**이미지 실패가 일과 생성을 죽이지 않는다**는 현재 원칙을 그대로 유지한다
(서비스 원칙 6 — 데모는 어떤 실패에서도 끝까지 진행).

### 에러 코드 추가

```java
// IMAGE
IMAGE_PROVIDER_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE, "이미지 생성을 사용할 수 없습니다."),
IMAGE_PROVIDER_NOT_CONFIGURED(HttpStatus.BAD_REQUEST, "해당 이미지 생성 제공자의 설정이 없습니다."),
```

## 영향 범위

**타입 이동으로 import만 바뀌는 곳 (4개)**

`RoutineStepImageFiller` · `RoutineImageStorage` · `RoutineAiPipeline` ·
`AdminPromptService` — `GeminiImageClient.GeneratedImage` → `GeneratedImage`.

`RoutineImageStorage.save()`의 파라미터 타입이 바뀌지만 시그니처 모양은 같다.

**신규 파일**

`GeneratedImage` · `ImageProvider` · `ImageGenerationRequest` ·
`ImageGenerationClient` · `ImageClientRouter` · `OpenAiImageClient` ·
`FluxImageClient` · `OpenAiProperties` · `FluxProperties`

**DB 마이그레이션 없음.** 설정 키는 `SystemConfigInitializer`가 시딩한다.

## 테스트

- `ImageClientRouter` — 정상 선택 / 미설정 프로바이더 거부 / 손상된 설정값 폴백
- 각 구현체 — 응답 파싱, 이미지 없는 응답 처리, 비용 계산 (**실제 API를 부르지 않는다.**
  MockRestServiceServer로 응답을 고정한다. AI 호출은 돈이 든다)
- `RoutineAiPipeline` — 이미지 실패 시 카드가 이미지 없이 생성되는지 (기존 테스트 유지)

## 열린 질문

1. **어느 프로바이더를 먼저 붙일까.** GPT Image 1 Mini가 가장 싸지만, 캐릭터 참조는
   edits 계열 API를 따로 써야 할 수 있다. FLUX schnell은 t2i 전용이라 캐릭터 참조가
   안 될 가능성이 높다. **실제로 붙여서 캐릭터 일관성을 눈으로 비교한 뒤 정한다.**
2. **비교 테스트를 몇 장까지 돌릴까.** 비교 자체가 돈이므로 관리자 테스트 화면에서
   1회 1장으로 제한한다.
