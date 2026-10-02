# 다국어 하위 계획 2: 서버 언어 기반

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 서버가 `Accept-Language` 로 요청 언어를 알고, 에러 문구·서버가 만드는 문장(AI 폴백 질문, 추천 일과)을 언어별 리소스에서 골라 주며, 일과가 자기 언어(`Routine.language`)를 들고 있게 한다. **헤더가 없는 요청(이미 배포된 앱)의 응답은 이전과 같다.** 번역 값은 비워 두고(계획 5 소관) 대체 순서(요청 언어 → `en` → `ko`)만 동작하게 한다.

**Architecture:** 요청 필터(`AcceptLanguageFilter`)가 `Accept-Language` 를 `AppLocale` 로 풀어 `CurrentLocale`(스레드 로컬, 요청 밖은 KO)에 담는다. 에러 문구는 Spring `ResourceBundleMessageSource`(`i18n/messages_{ko,en,ja,zh,es}.properties`, 키 = `ErrorCode` 이름)를 `ErrorMessages` 가 대체 순서로 읽는다. `ErrorCode` 에서 한글 문구를 빼고 `getMessage()` 는 ko 리소스를 돌려준다(관리자 화면·로그용). 서버가 만드는 문장은 `i18n/routine-phrases_*.properties` 를 `RoutinePhrases` 가 "한 벌" 단위로 읽고, 켜진 언어의 한 벌이 비면 기동 검사(`RoutinePhrasesStartupGuard`)가 서버를 세우지 않는다. 일과 생성 가능 언어는 시스템 설정 `ENABLED_CONTENT_LOCALES`(CSV) → `EnabledLocales`.

**Tech Stack:** Spring Boot 4.1(Spring 7) · Java 21 · Flyway · JUnit 5 · AssertJ · Mockito · MockMvc(standalone) · Python 3(ko 스냅샷 생성 1회용)

**Spec:** `docs/superpowers/specs/2026-10-02-multi-language-design.md` (7장 하위 2). 마스터: `docs/superpowers/plans/2026-10-02-i18n-0-master.md`

## Global Constraints

- 지원 언어는 `ko` `en` `ja` `zh`(간체) `es` 다섯이다. RTL과 번체 중국어는 범위 밖이다.
- **앱 안에는 언어 선택 화면을 만들지 않는다.** 언어 강제 스위치는 개발자 도구(`core/dev`)에만 둔다.
- 대체 순서는 어디서든 **요청 언어 → `en` → `ko`** 이다.
- `Accept-Language` 헤더가 **없으면 `ko`**, 5개 밖이거나 깨진 값이면 `en` 이다. 이미 배포된 앱의 응답은 바뀌지 않는다.
- 에러 문구는 서버가 번역해 내려보내고 클라이언트는 서버 문구를 그대로 보여준다(#347). 클라이언트가 에러 코드를 번역하지 않는다.
- `ko` 화면은 **1단계 이후에도 지금과 픽셀 단위로 같다.** 기존 앱 테스트와 골든이 그대로 통과해야 한다.
- 일과의 콘텐츠 언어는 일과를 만든 요청의 화면 언어이고, 보호자가 고르지 않는다.
- 약관은 그 언어의 게시본이 있어야 그 언어를 연다. 없는 언어에서 `en` 약관으로 대체하지 않는다.
- 서비스 원칙 유지: 진단명 미수집, 보호자 승인 후 노출, 원문 로그 미저장, AI 실패 시 fallback 필수.
- 용어: `이룸이`(아이·아동 금지), 해요체·능동형·긍정형(한국어 기준). 번역 용어는 용어집(`docs/i18n/glossary.md`)을 따른다.
- 코드 주석은 간결한 한국어(WHY 중심). 커밋은 `/pro-commit`으로, 이슈 번호 연결, `Co-Authored-By` 금지, 푸시는 사용자 요청 시에만.
- AI 호출은 비용이다. 검증용으로 생성 API를 반복 호출하지 않고 언어당 가장 싼 모델로 최소 횟수만 쓴다.
- Flyway 번호는 아래 표가 임시 배정이다. 구현 시점에 `origin/develop`의 다음 빈 번호를 쓴다(번호가 겹치면 먼저 머지된 쪽이 이긴다).

### 이 계획이 따르는 서버 규칙 (`server/CLAUDE.md`)

- 예외는 `CustomException` + `ErrorCode` + `GlobalExceptionHandler` 만 쓴다. 이 계획이 더하는 오류는 `ErrorCode.CONTENT_LOCALE_NOT_READY` 하나다.
- request DTO(`dto/request`)에 검증 어노테이션을 **새로 더하지 않는다.** 이 계획은 DTO 를 고치지 않는다(이미 있는 `message` 문구의 번역 키만 만든다).
- 새 REST 엔드포인트는 없다. 모든 엔티티는 `BaseEntity` 를 이미 상속한다.
- `.gitignore` 는 건드리지 않는다. 새 리소스는 `server/src/main/resources/i18n/` 에 둔다(무시되지 않음을 Task 4 에서 `git status` 로 확인한다).

## 공통 계약 (마스터 C1~C3, C5 중 이 계획이 구현하는 것 — 이름·타입·경로 그대로)

- `com.chuseok22.elumserver.common.locale.AppLocale` : `KO("ko") EN("en") JA("ja") ZH("zh") ES("es")`, `code()`, `fallbackChain()`, `fromCode(String)`, `fromAcceptLanguage(String)`
- `CurrentLocale.get()` (같은 패키지). `EnabledLocales.contains(AppLocale)` / `EnabledLocales.resolveContentLocale(AppLocale)` (같은 패키지, 스프링 빈)
- `ConfigKey.ENABLED_CONTENT_LOCALES` (CSV, 기본 `ko`)
- Flyway `V33__add_routine_language.sql` : `routine.language VARCHAR(8) NOT NULL DEFAULT 'ko'`
- `Routine.language`(`AppLocale`), `RoutineResponse.language`(문자열 코드). 일과 생성 요청에는 언어 필드를 **더하지 않는다.**

## Review Focus (이 계획이 소유한 줄)

| 줄 | 고정하는 Task | 테스트 |
| --- | --- | --- |
| 헤더가 없는 요청(이미 배포된 앱)의 응답은 이전과 **바이트 단위로 같다** | Task 4, 6, 7 | `ErrorMessageParityTest`, `LocalizedErrorResponsesTest`, `GlobalExceptionHandlerLocaleMvcTest` |
| `Accept-Language: zh-TW`, `zh-Hant`, `ar`, 빈 값, `*`, 품질값(`en;q=0.1, ja;q=0.9`)이 터지지 않고 정해진 언어로 떨어진다 | Task 1, 2, 7 | `AppLocaleTest`, `AcceptLanguageFilterTest`, `GlobalExceptionHandlerLocaleMvcTest` |
| 번역이 하나도 없는 키가 화면을 깨지 않는다(`en` → `ko` 대체) | Task 3, 4 | `ErrorMessagesTest`, `ErrorMessageParityTest` |
| 폴백 질문·추천 목록 파일이 한 언어라도 비면 서버가 뜨지 않는다 | Task 8, 10 | `RoutinePhrasesTest`, `RoutinePhrasesStartupGuardTest` |
| (추가) 헤더가 없으면 일과 언어·추천·폴백 질문도 `ko` 다 | Task 8, 11, 13 | `RoutinePhrasesParityTest`, `RoutineServiceTest`, 호환 묶음 실행 |

## 실제 코드와 계약이 부딪힌 곳 (구현 전에 읽는다)

1. **`fallbackChain()` 이 KO 에서 `[KO, EN]` 이 된다.** C2 는 `[this, EN, KO]` 에서 중복을 지우라고 했다. KO 요청에서 ko 키가 비면 영어가 나간다. 이 계획은 `AppLocale` 은 계약 그대로 두고, **소비하는 쪽(`ErrorMessages`, `RoutinePhrases`)이 KO 요청은 `[KO]` 만 보게** 한다(테스트 `koRequest_neverFallsToEnglish`). 계획 3·4 도 같은 처리가 필요하다.
2. **C1 "첫 번째 태그만 본다" vs 품질값.** `en;q=0.1, ja;q=0.9` 는 C1 대로 `EN` 이다(RFC 로는 `ja`). 앱은 태그 하나만 보내므로 C1 을 따른다. `zh-TW`/`zh-Hant` 도 C1(`zh*` 는 전부 `zh`)대로 `ZH` 다. 스펙 4.1 은 번체를 `en` 으로 보내라고 하지만 그것은 **클라이언트가 헤더를 정하는 규칙**이다(계획 1).
3. **`ErrorCode` 는 104개가 아니라 이 계획 후 105개다**(`CONTENT_LOCALE_NOT_READY` 추가). 패리티 golden 은 원래 104개만 고정한다.
4. **`@Valid` message 는 13줄이 아니라 17줄이다**(`RoutineStepCreate/Update`·`RoutineCreate`·`RoutineQuestion`·`MemberConsent`·`SensitiveInfoCheck` 요청). 그 외 `@NotBlank` 3곳(`OAuthLoginRequest`, `RefreshTokenRequest`, `RedeemLinkRequest`)은 `message` 가 없어 Hibernate Validator 기본 문구가 나가고, 이 문구의 언어는 Spring MVC 가 `Accept-Language` 로 정한다. **이 계획은 그 3곳을 건드리지 않는다**(사용자 결정 항목).
5. **`RoutineResponse` 에 `language` 가 더해진다.** 에러 응답은 바이트 동일이지만 일과 JSON 에는 필드가 하나 늘어난다(C5 요구). Dart `fromJson` 은 모르는 필드를 무시한다.
6. **`MaintenanceModeFilter` 의 안내 문구**는 관리자가 적은 한국어다. 기본 문구 그대로면 요청 언어로 바꾸고, 관리자가 직접 쓴 문구는 그대로 준다.

## 파일 구조

| 구분 | 경로 (server/ 기준) |
| --- | --- |
| 새 코드 | `src/main/java/com/chuseok22/elumserver/common/locale/{AppLocale,CurrentLocale,AcceptLanguageFilter,AppLocaleConverter,EnabledLocales}.java` |
| 새 코드 | `src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessages.java` |
| 새 코드 | `src/main/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrases.java` |
| 새 코드 | `src/main/java/com/chuseok22/elumserver/routine/infrastructure/guard/RoutinePhrasesStartupGuard.java` |
| 새 리소스 | `src/main/resources/i18n/messages_{ko,en,ja,zh,es}.properties`, `src/main/resources/i18n/routine-phrases_{ko,en,ja,zh,es}.properties` |
| 새 마이그레이션 | `src/main/resources/db/migration/V33__add_routine_language.sql` |
| golden(ko 불변 증명) | `src/test/resources/i18n/golden/error-messages-ko.json`, `src/test/resources/i18n/golden/routine-phrases-ko.json` |

---

## Task 1: `AppLocale` 와 `Accept-Language` 파싱

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/common/locale/AppLocale.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/common/locale/AppLocaleTest.java`

**Interfaces:**
- Consumes: 없음
- Produces:
  ```java
  public enum AppLocale {
    KO, EN, JA, ZH, ES;
    public String code();
    public List<AppLocale> fallbackChain();                    // [this, EN, KO] 중복 제거, 처음 나온 자리 유지
    public static AppLocale fromCode(String code);             // 정확히 일치, 아니면 IllegalArgumentException
    public static AppLocale fromAcceptLanguage(String header); // null/빈 값 → KO, 미지원·깨진 값 → EN
  }
  ```

- [ ] **Step 1: 기준선을 기록한다 (전체 테스트 수)**

작업 시작 전 깨끗한 worktree 에서 한 번 돌려 기존 테스트 수를 남긴다. 마지막 Task 가 이 수와 비교한다.

Run:
```bash
cd server && ./gradlew test
python3 - <<'PY'
import glob, xml.etree.ElementTree as ET
t = f = e = s = 0
for path in glob.glob("build/test-results/test/*.xml"):
    r = ET.parse(path).getroot()
    t += int(r.get("tests")); f += int(r.get("failures")); e += int(r.get("errors")); s += int(r.get("skipped"))
print("BASELINE tests=%d failures=%d errors=%d skipped=%d" % (t, f, e, s))
PY
```
Expected: `failures=0 errors=0`. 출력된 `tests=` 값을 PR/이슈 메모에 적어 둔다(이하 `BASELINE`).

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/common/locale/AppLocaleTest.java`:

```java
package com.chuseok22.elumserver.common.locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class AppLocaleTest {

  @Test
  @DisplayName("내부 코드는 소문자 두 글자다")
  void codes() {
    assertThat(List.of(AppLocale.values()).stream().map(AppLocale::code).toList())
      .containsExactly("ko", "en", "ja", "zh", "es");
  }

  @Test
  @DisplayName("대체 순서는 요청 언어 → en → ko 이고 겹치는 언어는 한 번만 나온다")
  void fallbackChain() {
    assertThat(AppLocale.JA.fallbackChain()).containsExactly(AppLocale.JA, AppLocale.EN, AppLocale.KO);
    assertThat(AppLocale.ZH.fallbackChain()).containsExactly(AppLocale.ZH, AppLocale.EN, AppLocale.KO);
    assertThat(AppLocale.ES.fallbackChain()).containsExactly(AppLocale.ES, AppLocale.EN, AppLocale.KO);
    assertThat(AppLocale.EN.fallbackChain()).containsExactly(AppLocale.EN, AppLocale.KO);
    // KO 는 [KO, EN] 이다 — 소비하는 쪽(ErrorMessages·RoutinePhrases)이 KO 요청은 [KO] 만 본다
    assertThat(AppLocale.KO.fallbackChain()).containsExactly(AppLocale.KO, AppLocale.EN);
  }

  @Test
  @DisplayName("fromCode 는 정확히 일치하는 코드만 받는다")
  void fromCode_exact() {
    assertThat(AppLocale.fromCode("ja")).isEqualTo(AppLocale.JA);
    assertThat(AppLocale.fromCode("zh")).isEqualTo(AppLocale.ZH);
  }

  @ParameterizedTest
  @ValueSource(strings = {"KO", "zh-Hans", "xx", "", " ko"})
  @DisplayName("fromCode 는 대소문자가 다르거나 모르는 코드면 IllegalArgumentException")
  void fromCode_rejectsOthers(String code) {
    assertThatThrownBy(() -> AppLocale.fromCode(code)).isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  @DisplayName("fromCode(null) 도 IllegalArgumentException 이다")
  void fromCode_null() {
    assertThatThrownBy(() -> AppLocale.fromCode(null)).isInstanceOf(IllegalArgumentException.class);
  }

  @ParameterizedTest
  @NullAndEmptySource
  @ValueSource(strings = {" ", "\t", "   \n"})
  @DisplayName("헤더가 없거나 비었으면 ko — 이미 배포된 앱")
  void noHeader_isKo(String header) {
    assertThat(AppLocale.fromAcceptLanguage(header)).isEqualTo(AppLocale.KO);
  }

  @ParameterizedTest
  @CsvSource(delimiter = '|', value = {
    "ko|KO", "en|EN", "ja|JA", "zh-Hans|ZH", "es|ES",
    "ko-KR|KO", "en-US|EN", "ja-JP|JA", "es-MX|ES", "zh_CN|ZH",
    "JA|JA", "KO;q=1|KO", "ko-KR,en;q=0.5|KO",
    // C1: zh* 는 모두 zh. 번체 판단은 클라이언트의 몫이다
    "zh-TW|ZH", "zh-Hant|ZH", "zh-HK|ZH",
    // 5개 밖·깨진 값은 en
    "ar|EN", "fr-FR|EN", "*|EN", "xx|EN", ";q=0.5|EN", ",|EN", "-|EN", "_ko|EN",
    // 품질값은 순서를 바꾸지 않는다 — 첫 태그만 본다(C1)
    "en;q=0.1, ja;q=0.9|EN", "ja;q=0.1, en;q=0.9|JA"
  })
  @DisplayName("첫 번째 태그의 기본 언어만 본다 — 지원 밖이거나 깨졌으면 en")
  void firstTagOnly(String header, AppLocale expected) {
    assertThat(AppLocale.fromAcceptLanguage(header)).isEqualTo(expected);
  }

  @Test
  @DisplayName("어떤 값이 와도 터지지 않는다")
  void neverThrows() {
    List<String> weird = List.of(
      "\u0000\u0000", "a".repeat(10_000), ";;;", "q=1", "en;;;q=", ",,,ja", "ko,,,", "日本語", "😀");
    for (String header : weird) {
      assertThatCode(() -> AppLocale.fromAcceptLanguage(header)).doesNotThrowAnyException();
    }
    assertThat(AppLocale.fromAcceptLanguage(",,,ja")).isEqualTo(AppLocale.JA);
  }
}
```

- [ ] **Step 3: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.locale.AppLocaleTest'`
Expected: **FAIL** (컴파일 오류 — `AppLocale` 가 없다)

- [ ] **Step 4: 최소 구현**

`server/src/main/java/com/chuseok22/elumserver/common/locale/AppLocale.java`:

```java
package com.chuseok22.elumserver.common.locale;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;

/**
 * 서버가 다루는 언어 다섯 (다국어 #521, 마스터 계획 C1·C2).
 *
 * <p>내부 코드는 소문자 두 글자다. HTTP {@code Accept-Language} 로는 {@code zh-Hans} 가 오지만 서버는 {@code zh} 로 본다.
 */
public enum AppLocale {
  KO("ko"), EN("en"), JA("ja"), ZH("zh"), ES("es");

  private final String code;

  AppLocale(String code) {
    this.code = code;
  }

  public String code() {
    return code;
  }

  /**
   * 대체 순서: 요청 언어 → en → ko. 겹치는 언어는 처음 나온 자리만 남긴다.
   *
   * <p>KO 는 {@code [KO, EN]} 이 된다. ko 문구가 비었을 때 영어가 나가면 안 되므로, 이 목록을 쓰는 쪽은
   * KO 요청을 {@code [KO]} 로 따로 다룬다.
   */
  public List<AppLocale> fallbackChain() {
    LinkedHashSet<AppLocale> chain = new LinkedHashSet<>();
    chain.add(this);
    chain.add(EN);
    chain.add(KO);
    return List.copyOf(chain);
  }

  /** 정확히 일치하는 코드만 받는다. 저장된 값을 읽을 때 쓰므로 모르는 값은 조용히 넘기지 않는다. */
  public static AppLocale fromCode(String code) {
    for (AppLocale locale : values()) {
      if (locale.code.equals(code)) {
        return locale;
      }
    }
    throw new IllegalArgumentException("지원하지 않는 언어 코드: " + code);
  }

  /**
   * {@code Accept-Language} 값을 언어로 바꾼다. 어떤 값이 와도 던지지 않는다.
   *
   * <ul>
   *   <li>헤더가 없거나 비었다 → KO (이미 배포된 앱은 헤더를 보내지 않는다)</li>
   *   <li>첫 번째 태그의 기본 언어만 본다. 품질값(q)은 순서를 바꾸지 않는다 — 앱은 태그 하나만 보낸다</li>
   *   <li>5개 밖이거나 깨졌다 → EN</li>
   * </ul>
   */
  public static AppLocale fromAcceptLanguage(String header) {
    if (header == null || header.isBlank()) {
      return KO;
    }
    String first = null;
    for (String part : header.split(",")) {
      if (!part.isBlank()) {
        first = part;
        break;
      }
    }
    if (first == null) {
      return EN;
    }
    String tag = first.split(";", 2)[0].trim().toLowerCase(Locale.ROOT);
    int cut = indexOfSubtagSeparator(tag);
    String language = cut < 0 ? tag : tag.substring(0, cut);
    for (AppLocale locale : values()) {
      if (locale.code.equals(language)) {
        return locale;
      }
    }
    return EN;
  }

  private static int indexOfSubtagSeparator(String tag) {
    for (int i = 0; i < tag.length(); i++) {
      char c = tag.charAt(i);
      if (c == '-' || c == '_') {
        return i;
      }
    }
    return -1;
  }
}
```

- [ ] **Step 5: 실행해서 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.locale.AppLocaleTest'`
Expected: **PASS**

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/locale/AppLocale.java \
        server/src/test/java/com/chuseok22/elumserver/common/locale/AppLocaleTest.java
```

---

## Task 2: 요청 범위 `CurrentLocale` 과 `AcceptLanguageFilter`

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/common/locale/CurrentLocale.java`
- Create: `server/src/main/java/com/chuseok22/elumserver/common/locale/AcceptLanguageFilter.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/common/locale/AcceptLanguageFilterTest.java`

**Interfaces:**
- Consumes: `AppLocale.fromAcceptLanguage(String)` (Task 1)
- Produces:
  ```java
  public final class CurrentLocale {
    public static AppLocale get();                                   // 요청 밖은 KO
    public static <T> T callAs(AppLocale locale, Supplier<T> body);  // 테스트·비요청 스레드용
    public static void runAs(AppLocale locale, Runnable body);
    static void set(AppLocale locale);   // 같은 패키지(필터)만
    static void clear();
  }
  @Component @Order(Ordered.HIGHEST_PRECEDENCE + 10)
  public class AcceptLanguageFilter extends OncePerRequestFilter { }
  ```

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/common/locale/AcceptLanguageFilterTest.java`:

```java
package com.chuseok22.elumserver.common.locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import jakarta.servlet.ServletException;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.annotation.Order;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class AcceptLanguageFilterTest {

  private final AcceptLanguageFilter filter = new AcceptLanguageFilter();

  /** 요청을 처리하는 동안(체인 안)의 CurrentLocale. */
  private AppLocale seenDuring(String header) throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/routines");
    if (header != null) {
      request.addHeader("Accept-Language", header);
    }
    AtomicReference<AppLocale> seen = new AtomicReference<>();
    filter.doFilter(request, new MockHttpServletResponse(), (req, res) -> seen.set(CurrentLocale.get()));
    return seen.get();
  }

  @Test
  @DisplayName("헤더가 없으면 요청 안에서도 KO — 이미 배포된 앱")
  void noHeader_isKo() throws Exception {
    assertThat(seenDuring(null)).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("헤더의 언어가 요청 안에서 보인다")
  void header_isVisibleDuringRequest() throws Exception {
    assertThat(seenDuring("zh-Hans")).isEqualTo(AppLocale.ZH);
    assertThat(seenDuring("ja")).isEqualTo(AppLocale.JA);
    assertThat(seenDuring("ar")).isEqualTo(AppLocale.EN);
    assertThat(seenDuring("en;q=0.1, ja;q=0.9")).isEqualTo(AppLocale.EN);
  }

  @Test
  @DisplayName("요청이 끝나면 비운다 — 풀의 스레드를 재사용해도 다음 요청에 새지 않는다")
  void clearedAfterRequest() throws Exception {
    seenDuring("ja");
    assertThat(CurrentLocale.get()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("체인이 던져도 비운다")
  void clearedWhenChainThrows() {
    MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/routines");
    request.addHeader("Accept-Language", "es");

    assertThatThrownBy(() -> filter.doFilter(request, new MockHttpServletResponse(), (req, res) -> {
      throw new ServletException("boom");
    })).isInstanceOf(ServletException.class);

    assertThat(CurrentLocale.get()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("요청 밖에서는 KO, callAs 는 끝나면 이전 값으로 돌려놓는다")
  void callAs_restores() {
    assertThat(CurrentLocale.get()).isEqualTo(AppLocale.KO);
    String inside = CurrentLocale.callAs(AppLocale.JA, () -> CurrentLocale.get().code());
    assertThat(inside).isEqualTo("ja");
    assertThat(CurrentLocale.get()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("필터는 Spring Security 체인(기본 순서 -100)보다 앞에 있다 — 보안 필터가 내는 오류 응답도 요청 언어를 알아야 한다")
  void runsBeforeSecurityChain() {
    Order order = AcceptLanguageFilter.class.getAnnotation(Order.class);
    assertThat(order).isNotNull();
    assertThat(order.value()).isLessThan(-100);
  }
}
```

- [ ] **Step 2: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.locale.AcceptLanguageFilterTest'`
Expected: **FAIL** (컴파일 오류 — `CurrentLocale`, `AcceptLanguageFilter` 없음)

- [ ] **Step 3: 최소 구현**

`server/src/main/java/com/chuseok22/elumserver/common/locale/CurrentLocale.java`:

```java
package com.chuseok22.elumserver.common.locale;

import java.util.function.Supplier;

/**
 * 지금 처리 중인 요청의 언어 (다국어 #521).
 *
 * <p>{@link AcceptLanguageFilter} 가 요청 앞에서 심고 뒤에서 비운다. 요청 밖(스케줄러·기동·테스트)은 KO 다.
 * {@code AiCallContext} 와 같은 이유로 InheritableThreadLocal 을 쓴다 — 이미지 생성이 가상 스레드로 병렬 실행되어도
 * 요청 언어가 따라간다. 풀의 스레드는 필터가 매번 비운다.
 */
public final class CurrentLocale {

  private static final InheritableThreadLocal<AppLocale> CURRENT = new InheritableThreadLocal<>();

  private CurrentLocale() {
  }

  /** 요청 안이면 헤더가 정한 언어, 밖이면 KO. */
  public static AppLocale get() {
    AppLocale locale = CURRENT.get();
    return locale == null ? AppLocale.KO : locale;
  }

  /** 요청이 아닌 곳(테스트 등)에서 잠시 언어를 정한다. 끝나면 이전 값으로 되돌린다. */
  public static <T> T callAs(AppLocale locale, Supplier<T> body) {
    AppLocale previous = CURRENT.get();
    CURRENT.set(locale);
    try {
      return body.get();
    } finally {
      if (previous == null) {
        CURRENT.remove();
      } else {
        CURRENT.set(previous);
      }
    }
  }

  public static void runAs(AppLocale locale, Runnable body) {
    callAs(locale, () -> {
      body.run();
      return null;
    });
  }

  static void set(AppLocale locale) {
    CURRENT.set(locale);
  }

  static void clear() {
    CURRENT.remove();
  }
}
```

`server/src/main/java/com/chuseok22/elumserver/common/locale/AcceptLanguageFilter.java`:

```java
package com.chuseok22.elumserver.common.locale;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * {@code Accept-Language} 를 읽어 요청 범위의 {@link CurrentLocale} 에 담는다 (다국어 #521).
 *
 * <p><b>Spring Security 체인보다 앞에 둔다.</b> 체인의 기본 순서는 -100 이다. 뒤에 두면 점검 모드(503)·토큰 오류(401)처럼
 * 보안 필터가 직접 쓰는 오류 응답이 요청 언어를 모른다. 헤더가 없으면 KO 라 이미 배포된 앱의 응답은 그대로다.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public class AcceptLanguageFilter extends OncePerRequestFilter {

  /** 비동기 재진입에서도 언어를 다시 심는다(스레드가 바뀌므로). */
  @Override
  protected boolean shouldNotFilterAsyncDispatch() {
    return false;
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    CurrentLocale.set(AppLocale.fromAcceptLanguage(request.getHeader(HttpHeaders.ACCEPT_LANGUAGE)));
    try {
      chain.doFilter(request, response);
    } finally {
      CurrentLocale.clear();
    }
  }
}
```

- [ ] **Step 4: 실행해서 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.locale.AcceptLanguageFilterTest' --tests 'com.chuseok22.elumserver.common.BeanConstructorAmbiguityTest'`
Expected: **PASS** (새 `@Component` 가 생성자 모호성 검사를 통과하는지도 함께 본다)

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/locale/CurrentLocale.java \
        server/src/main/java/com/chuseok22/elumserver/common/locale/AcceptLanguageFilter.java \
        server/src/test/java/com/chuseok22/elumserver/common/locale/AcceptLanguageFilterTest.java
```

---

## Task 3: `ErrorMessages` — `MessageSource` 와 대체 순서

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessages.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessagesTest.java`

**Interfaces:**
- Consumes: `AppLocale`, `CurrentLocale` (Task 1, 2), `ErrorCode`(기존)
- Produces:
  ```java
  public final class ErrorMessages {
    public ErrorMessages(MessageSource source);
    public static ErrorMessages standard();                               // i18n/messages_*.properties
    public String of(ErrorCode code);                                     // CurrentLocale 기준
    public String of(ErrorCode code, AppLocale locale);                   // 마지막 대체 = code.name()
    public String of(String key, AppLocale locale, String defaultText);   // 마지막 대체 = defaultText
  }
  ```

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessagesTest.java`:

```java
package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import java.util.Locale;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.StaticMessageSource;

/** 대체 순서(요청 언어 → en → ko)를 가짜 문구 원본으로 본다. 실제 번역 파일 내용과 무관하다. */
class ErrorMessagesTest {

  private static final String KEY = "ROUTINE_NOT_FOUND";

  private final StaticMessageSource source = new StaticMessageSource();
  private final ErrorMessages messages = new ErrorMessages(source);

  private void put(String key, AppLocale locale, String text) {
    source.addMessage(key, Locale.of(locale.code()), text);
  }

  @Test
  @DisplayName("요청 언어의 문구가 있으면 그것을 준다")
  void requestLanguageWins() {
    put(KEY, AppLocale.KO, "ko 문구");
    put(KEY, AppLocale.EN, "en text");
    put(KEY, AppLocale.JA, "ja テキスト");

    assertThat(messages.of(KEY, AppLocale.JA, "기본")).isEqualTo("ja テキスト");
  }

  @Test
  @DisplayName("요청 언어에 키가 없으면 en 으로 간다")
  void missingKey_fallsBackToEn() {
    put(KEY, AppLocale.KO, "ko 문구");
    put(KEY, AppLocale.EN, "en text");

    assertThat(messages.of(KEY, AppLocale.ES, "기본")).isEqualTo("en text");
  }

  @Test
  @DisplayName("en 에도 없으면 ko 로 간다")
  void missingEn_fallsBackToKo() {
    put(KEY, AppLocale.KO, "ko 문구");

    assertThat(messages.of(KEY, AppLocale.ZH, "기본")).isEqualTo("ko 문구");
  }

  @Test
  @DisplayName("값이 비어 있는 키는 없는 것으로 본다 — 번역 파일에 키만 있고 값이 빈 경우")
  void blankValue_isTreatedAsMissing() {
    put(KEY, AppLocale.KO, "ko 문구");
    put(KEY, AppLocale.EN, "   ");
    put(KEY, AppLocale.JA, "");

    assertThat(messages.of(KEY, AppLocale.JA, "기본")).isEqualTo("ko 문구");
  }

  @Test
  @DisplayName("ko 요청은 영어로 새지 않는다 — ko 키가 비면 기본 문구로 간다")
  void koRequest_neverFallsToEnglish() {
    put(KEY, AppLocale.EN, "en text");

    assertThat(messages.of(KEY, AppLocale.KO, "기본")).isEqualTo("기본");
  }

  @Test
  @DisplayName("어느 언어에도 없으면 호출한 쪽이 준 기본 문구, ErrorCode 는 코드 이름이다")
  void nothingAnywhere_usesDefault() {
    assertThat(messages.of("NO.SUCH.KEY", AppLocale.JA, "기본")).isEqualTo("기본");
    assertThat(messages.of(ErrorCode.ROUTINE_NOT_FOUND, AppLocale.JA)).isEqualTo("ROUTINE_NOT_FOUND");
  }

  @Test
  @DisplayName("of(ErrorCode) 는 요청 안의 언어를 따르고, 요청 밖은 KO 다")
  void ofErrorCode_followsCurrentLocale() {
    put("INTERNAL_SERVER_ERROR", AppLocale.KO, "ko");
    put("INTERNAL_SERVER_ERROR", AppLocale.JA, "ja");

    assertThat(messages.of(ErrorCode.INTERNAL_SERVER_ERROR)).isEqualTo("ko");
    assertThat(CurrentLocale.callAs(AppLocale.JA, () -> messages.of(ErrorCode.INTERNAL_SERVER_ERROR))).isEqualTo("ja");
  }

  @Test
  @DisplayName("standard() 는 같은 인스턴스를 돌려준다")
  void standard_isShared() {
    assertThat(ErrorMessages.standard()).isSameAs(ErrorMessages.standard());
  }
}
```

- [ ] **Step 2: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessagesTest'`
Expected: **FAIL** (컴파일 오류 — `ErrorMessages` 없음)

- [ ] **Step 3: 최소 구현**

`server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessages.java`:

```java
package com.chuseok22.elumserver.common.infrastructure.exception;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import java.util.List;
import java.util.Locale;
import org.springframework.context.MessageSource;
import org.springframework.context.support.ResourceBundleMessageSource;

/**
 * 에러 응답 문구를 요청 언어로 고른다 (다국어 #521).
 *
 * <p>원본은 {@code i18n/messages_{언어}.properties} 이고 키는 {@link ErrorCode} 이름이다. 대체 순서는
 * 요청 언어 → en → ko. 값이 비었거나 키가 없으면 다음 언어로 넘어가므로, 번역 파일이 비어 있어도 서버는 정상 동작한다.
 *
 * <p>스프링 빈이 아니라 정적으로 둔다 — 필터·인증 진입점·예외 어드바이스가 모두 직접 {@code new} 로 만들어지는 곳이라
 * 주입을 끌어오면 기존 생성자가 줄줄이 바뀐다.
 */
public final class ErrorMessages {

  private static final String BASENAME = "i18n/messages";
  private static final ErrorMessages STANDARD = new ErrorMessages(standardSource());

  private final MessageSource source;

  public ErrorMessages(MessageSource source) {
    this.source = source;
  }

  public static ErrorMessages standard() {
    return STANDARD;
  }

  private static MessageSource standardSource() {
    ResourceBundleMessageSource bundle = new ResourceBundleMessageSource();
    bundle.setBasename(BASENAME);
    bundle.setDefaultEncoding("UTF-8");
    // 서버 JVM 의 기본 언어로 새지 않게 한다. 대체 순서는 이 클래스가 직접 정한다.
    bundle.setFallbackToSystemLocale(false);
    return bundle;
  }

  /** 지금 요청의 언어로 고른 문구. */
  public String of(ErrorCode code) {
    return of(code, CurrentLocale.get());
  }

  public String of(ErrorCode code, AppLocale locale) {
    return of(code.name(), locale, code.name());
  }

  /**
   * @param defaultText 어느 언어에도 키가 없을 때 돌려줄 문구(예: DTO 에 적은 한국어 message)
   */
  public String of(String key, AppLocale locale, String defaultText) {
    // ko 요청은 영어로 새지 않는다 — fallbackChain() 은 KO 에서 [KO, EN] 이 된다.
    List<AppLocale> chain = locale == AppLocale.KO ? List.of(AppLocale.KO) : locale.fallbackChain();
    for (AppLocale candidate : chain) {
      String message = source.getMessage(key, null, null, Locale.of(candidate.code()));
      if (message != null && !message.isBlank()) {
        return message;
      }
    }
    return defaultText;
  }
}
```

- [ ] **Step 4: 실행해서 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessagesTest'`
Expected: **PASS**

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessages.java \
        server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessagesTest.java
```

---

## Task 4: `ErrorCode` 문구를 ko 리소스로 옮기고 패리티를 증명한다

번역 값은 **채우지 않는다**(계획 5). en·ja·zh·es 파일은 머리 주석만 둔다.

**Files:**
- Create: `server/src/main/resources/i18n/messages_ko.properties` (기존 enum 문구에서 생성)
- Create: `server/src/main/resources/i18n/messages_en.properties`, `messages_ja.properties`, `messages_zh.properties`, `messages_es.properties` (머리 주석만)
- Create: `server/src/test/resources/i18n/golden/error-messages-ko.json` (기존 enum 의 이름·상태·문구를 고정, 생성)
- Test: `server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessageParityTest.java`

**Interfaces:**
- Consumes: `ErrorMessages.standard()` (Task 3), `ErrorCode`(기존, 아직 문구를 들고 있다)
- Produces: ko 리소스 = 기존 enum 문구와 글자 하나까지 같음을 증명하는 테스트. golden 은 이후에도 ko 불변의 기준이다(ko 문구를 의도적으로 바꾸는 PR 이 golden 을 같이 고친다).

- [ ] **Step 1: 패리티 테스트를 먼저 쓴다**

`server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessageParityTest.java`:

```java
package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

/**
 * ko 응답이 다국어 작업 전과 같다는 증명 (다국어 #521, 헤더 없는 앱의 호환).
 *
 * <p>golden 은 작업 전 {@code ErrorCode} enum 의 이름·HTTP 상태·문구를 <b>JSON 으로 따로</b> 고정한 것이다. ko 리소스는
 * properties 로 읽으므로 인코딩·이스케이프 실수가 있으면 여기서 글자 단위로 드러난다.
 * ko 문구를 의도적으로 바꾸는 PR 은 golden 도 같이 고친다 — 그때는 그것이 이 테스트의 목적이다.
 */
class ErrorMessageParityTest {

  private static final Map<String, Map<String, String>> GOLDEN = loadGolden();

  private static Map<String, Map<String, String>> loadGolden() {
    try (InputStream in = ErrorMessageParityTest.class.getResourceAsStream("/i18n/golden/error-messages-ko.json")) {
      assertThat(in).as("golden 파일 /i18n/golden/error-messages-ko.json").isNotNull();
      return new ObjectMapper().readValue(in, new TypeReference<>() {
      });
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  @Test
  @DisplayName("golden 은 작업 전 ErrorCode 104개를 모두 담고 있다")
  void goldenCoversAllLegacyCodes() {
    assertThat(GOLDEN).hasSize(104);
  }

  @Test
  @DisplayName("ko 리소스의 문구는 기존 enum 문구와 글자 하나까지 같다")
  void koResource_equalsLegacyText() {
    GOLDEN.forEach((name, legacy) -> {
      ErrorCode code = ErrorCode.valueOf(name);
      assertThat(ErrorMessages.standard().of(code, AppLocale.KO))
        .as("ko 문구 %s", name)
        .isEqualTo(legacy.get("message"));
    });
  }

  @Test
  @DisplayName("HTTP 상태도 그대로다")
  void status_isUnchanged() {
    GOLDEN.forEach((name, legacy) ->
      assertThat(ErrorCode.valueOf(name).getStatus().name()).as("상태 %s", name).isEqualTo(legacy.get("status")));
  }

  @Test
  @DisplayName("ErrorCode.getMessage() 는 지금도 같은 한국어 문구다 — 관리자 화면·로그·예외 메시지")
  void getMessage_stillReturnsLegacyKorean() {
    GOLDEN.forEach((name, legacy) ->
      assertThat(ErrorCode.valueOf(name).getMessage()).as("getMessage %s", name).isEqualTo(legacy.get("message")));
  }

  @Test
  @DisplayName("모든 ErrorCode 는 ko 문구가 있다 — 새 코드를 더하고 리소스를 빠뜨리면 여기서 걸린다")
  void everyErrorCodeHasKoMessage() {
    for (ErrorCode code : ErrorCode.values()) {
      assertThat(ErrorMessages.standard().of(code, AppLocale.KO))
        .as("ko 문구 %s", code.name())
        .isNotBlank()
        .isNotEqualTo(code.name());
    }
  }

  @ParameterizedTest
  @EnumSource(AppLocale.class)
  @DisplayName("언어마다 문구 파일이 있다 — 번역 값은 계획 5에서 채운다")
  void everyLocaleHasAFile(AppLocale locale) {
    assertThat(getClass().getResource("/i18n/messages_" + locale.code() + ".properties")).isNotNull();
  }

  @ParameterizedTest
  @EnumSource(AppLocale.class)
  @DisplayName("파일이 비어 있어도 모든 언어가 모든 코드에서 문구를 받는다 — en → ko 대체")
  void everyLocaleAlwaysGetsAMessage(AppLocale locale) {
    for (ErrorCode code : ErrorCode.values()) {
      assertThat(ErrorMessages.standard().of(code, locale))
        .as("%s %s", locale.code(), code.name())
        .isNotBlank()
        .isNotEqualTo(code.name());
    }
  }
}
```

- [ ] **Step 2: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessageParityTest'`
Expected: **FAIL** (golden 파일·ko 리소스가 아직 없다)

- [ ] **Step 3: golden 과 ko 리소스를 기존 enum 에서 생성한다 (1회용)**

작업 전 소스는 고정 커밋 `0164a36a`(스펙 문서의 기준 코드)에서 읽는다 — 이후 `ErrorCode.java` 가 바뀌어도 같은 결과가 나온다. 레포 루트(worktree 루트)에서 실행한다. 스크립트는 저장소에 넣지 않는다.

```bash
mkdir -p server/src/main/resources/i18n server/src/test/resources/i18n/golden
python3 - <<'PY'
import json, re, subprocess

BASE = "0164a36a"
PATH = "server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java"
src = subprocess.check_output(["git", "show", f"{BASE}:{PATH}"]).decode("utf-8")

# NAME(HttpStatus.X, "문구"), — 한 줄이든 줄바꿈이 있든 잡는다
pattern = re.compile(r'([A-Z][A-Z0-9_]*)\(\s*HttpStatus\.([A-Z_]+)\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)\s*,')
entries = pattern.findall(src)
assert len(entries) == 104, len(entries)
assert len({name for name, _, _ in entries}) == 104
for name, _, message in entries:
    # properties 이스케이프가 필요한 글자는 지금 문구에 없다. 생기면 여기서 멈춰 사람이 본다.
    assert "\\" not in message and message == message.strip(), name

header = (
    "# 에러 응답 문구 (ko). 키는 ErrorCode 이름이다. 원본은 이 파일이다.\n"
    "# 문구를 바꾸면 ErrorMessageParityTest 의 golden(src/test/resources/i18n/golden)도 같은 PR 에서 의도적으로 고친다.\n"
)
with open("server/src/main/resources/i18n/messages_ko.properties", "w", encoding="utf-8") as f:
    f.write(header)
    for name, _, message in entries:
        f.write(f"{name}={message}\n")

golden = {name: {"status": status, "message": message} for name, status, message in entries}
with open("server/src/test/resources/i18n/golden/error-messages-ko.json", "w", encoding="utf-8") as f:
    json.dump(golden, f, ensure_ascii=False, indent=1)
    f.write("\n")
print("ok", len(entries))
PY
for l in en ja zh es; do
  printf '# 에러 응답 문구 (%s). 키는 ErrorCode 이름이다.\n# 번역 값은 계획 5(번역과 품질)에서 채운다. 키가 없거나 값이 비어 있으면 요청 언어 → en → ko 순서로 대체된다.\n' "$l" \
    > "server/src/main/resources/i18n/messages_${l}.properties"
done
git status --short server/src/main/resources/i18n server/src/test/resources/i18n
```
Expected: `ok 104`, 그리고 `git status` 에 `i18n/` 의 새 파일 5개(+golden 1개)가 `??` 로 보인다(`.gitignore` 에 걸리지 않는다는 확인. 안 보이면 멈추고 사용자에게 알린다 — `.gitignore` 는 건드리지 않는다).

- [ ] **Step 4: 실행해서 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessageParityTest'`
Expected: **PASS** (ko 리소스 = 기존 enum 문구 104개, 상태 104개, 다른 언어는 파일이 비어도 문구를 받는다)

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/resources/i18n/messages_ko.properties \
        server/src/main/resources/i18n/messages_en.properties \
        server/src/main/resources/i18n/messages_ja.properties \
        server/src/main/resources/i18n/messages_zh.properties \
        server/src/main/resources/i18n/messages_es.properties \
        server/src/test/resources/i18n/golden/error-messages-ko.json \
        server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessageParityTest.java
```

---

## Task 5: `ErrorCode` 에서 한글 문구를 빼고 `getMessage()` 를 ko 리소스로 돌린다

원본을 한 곳(리소스)으로 만든다. `getMessage()` 는 남긴다 — `CustomException` 의 예외 메시지, 관리자 화면, `MaintenanceModeFilter` 등 기존 호출부와 테스트가 그대로 동작해야 한다.

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java` (생성자 인자 104곳 + 끝의 필드 2줄 — 약 7-160행)
- Test: `ErrorMessageParityTest`(Task 4), `ErrorCodeTest`, `MaintenanceModeFilterTest`, `AdminGrantProFailureTest`, `AdminCreditControllerTest`(기존)

**Interfaces:**
- Consumes: `ErrorMessages.standard()`, `AppLocale.KO`
- Produces: `ErrorCode.getStatus()`(그대로), `ErrorCode.getMessage()`(ko 문구, 시그니처 그대로)

- [ ] **Step 1: 기계적으로 바꾼다**

`(HttpStatus.X, "문구")` → `(HttpStatus.X)`. 레포 루트에서 실행한다.

```bash
python3 - <<'PY'
import re
path = "server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java"
text = open(path, encoding="utf-8").read()
text, count = re.subn(r'\(\s*(HttpStatus\.[A-Z_]+)\s*,\s*"(?:[^"\\]|\\.)*"\s*\)', r'(\1)', text)
assert count == 104, count
open(path, "w", encoding="utf-8").write(text)
print("rewritten", count)
PY
grep -n '"' server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java | grep -v '^[0-9]*: *//'
```
Expected: `rewritten 104`, 그리고 마지막 `grep` 은 **아무것도 출력하지 않는다**(주석 밖에 따옴표가 남지 않음).

- [ ] **Step 2: 필드를 정리하고 `getMessage()` 를 더한다**

`ErrorCode.java` 끝(`;` 다음)을 고친다.

기존:
```java
  private final HttpStatus status;
  private final String message;
}
```
바꿈:
```java
  private final HttpStatus status;

  /**
   * 한국어 문구. 관리자 화면·로그·예외 메시지처럼 요청 언어가 없는 곳에서 쓴다.
   *
   * <p>원본은 {@code i18n/messages_ko.properties} 다. 응답으로 나가는 문구는 {@link ErrorMessages} 가 요청 언어로 고른다.
   */
  public String getMessage() {
    return ErrorMessages.standard().of(this, AppLocale.KO);
  }
}
```
그리고 import 한 줄을 더한다: `import com.chuseok22.elumserver.common.locale.AppLocale;` (`lombok.AllArgsConstructor` 는 그대로 — 필드가 `status` 하나라 생성자가 `ErrorCode(HttpStatus status)` 가 된다).

- [ ] **Step 3: 컴파일과 기존 테스트를 확인한다**

Run:
```bash
cd server && ./gradlew test \
  --tests 'com.chuseok22.elumserver.common.infrastructure.exception.*' \
  --tests 'com.chuseok22.elumserver.common.infrastructure.security.MaintenanceModeFilterTest' \
  --tests 'com.chuseok22.elumserver.admin.application.controller.AdminGrantProFailureTest' \
  --tests 'com.chuseok22.elumserver.admin.application.controller.AdminCreditControllerTest'
```
Expected: **PASS** (`ErrorMessageParityTest` 의 `getMessage_stillReturnsLegacyKorean` · `status_isUnchanged` 가 기계 치환이 문구와 상태를 망가뜨리지 않았음을 증명한다)

- [ ] **Step 4: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java
```

---

## Task 6: 응답을 만드는 곳이 요청 언어로 문구를 고르게 한다

`GlobalExceptionHandler`·`MultipartLimitExceptionHandler`·`MaintenanceModeFilter`·`JwtAuthenticationEntryPoint`·`AidlpDecryptionFilter`. 모두 기존 생성자를 바꾸지 않고(정적 `ErrorMessages.standard()`) 기존 테스트가 그대로 돈다.

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/application/exception/GlobalExceptionHandler.java` (46행 클래스 선언 아래 필드, 54·88·97·109·119·128행 `errorCode.getMessage()`, 62행 `.orElse(...)`)
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/application/exception/MultipartLimitExceptionHandler.java` (40행)
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/MaintenanceModeFilter.java` (86-94행 `message()`)
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/jwt/JwtAuthenticationEntryPoint.java` (17·28행)
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpDecryptionFilter.java` (필드 + 166행)
- Test: `server/src/test/java/com/chuseok22/elumserver/common/LocalizedErrorResponsesTest.java`

**Interfaces:**
- Consumes: `ErrorMessages.standard().of(ErrorCode)`, `ErrorMessages.standard().of(ErrorCode, AppLocale)`, `CurrentLocale`
- Produces: 응답 `errorMessage` 가 요청 언어를 따름. **헤더가 없으면 이전 응답과 바이트 단위로 같다.**

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/common/LocalizedErrorResponsesTest.java`:

```java
package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.application.exception.GlobalExceptionHandler;
import com.chuseok22.elumserver.common.application.exception.MultipartLimitExceptionHandler;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpCryptoService;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpDecryptionFilter;
import com.chuseok22.elumserver.common.infrastructure.security.MaintenanceModeFilter;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/**
 * 오류 응답이 요청 언어를 따르되, <b>헤더가 없으면 이전과 바이트 단위로 같다</b> (다국어 #521).
 *
 * <p>기대값은 작업 전 enum 문구를 고정한 golden(ko)에서 손으로 JSON 을 조립해 만든다 — 응답 객체를 같은 방식으로
 * 직렬화해 비교하면 둘이 함께 틀려도 통과한다.
 */
class LocalizedErrorResponsesTest {

  private static final ObjectMapper MAPPER = new ObjectMapper();
  private static final Map<String, Map<String, String>> GOLDEN = golden();

  private static Map<String, Map<String, String>> golden() {
    try (InputStream in = LocalizedErrorResponsesTest.class.getResourceAsStream("/i18n/golden/error-messages-ko.json")) {
      return MAPPER.readValue(in, new TypeReference<>() {
      });
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  /** 작업 전 응답 본문 — 이 모양 그대로 나가야 이미 배포된 앱이 깨지지 않는다. */
  private static String legacyJson(ErrorCode code) throws Exception {
    return "{\"errorCode\":\"" + code.name() + "\",\"errorMessage\":"
      + MAPPER.writeValueAsString(GOLDEN.get(code.name()).get("message")) + "}";
  }

  @Test
  @DisplayName("헤더가 없으면 모든 ErrorCode 의 응답 본문이 이전과 바이트 단위로 같다")
  void headerless_everyCode_bodyIsByteIdentical() throws Exception {
    GlobalExceptionHandler handler = new GlobalExceptionHandler();
    for (String name : GOLDEN.keySet()) {
      ErrorCode code = ErrorCode.valueOf(name);
      ResponseEntity<ErrorResponse> response = handler.handleCustomException(new CustomException(code));

      assertThat(response.getStatusCode().value()).as("상태 %s", name).isEqualTo(code.getStatus().value());
      assertThat(MAPPER.writeValueAsString(response.getBody()).getBytes(StandardCharsets.UTF_8))
        .as("본문 %s", name)
        .isEqualTo(legacyJson(code).getBytes(StandardCharsets.UTF_8));
    }
  }

  @Test
  @DisplayName("일본어 요청도 상태와 에러 코드는 그대로이고 문구는 대체 순서를 따른다")
  void jaRequest_keepsStatusAndCode_andFollowsChain() {
    GlobalExceptionHandler handler = new GlobalExceptionHandler();
    for (ErrorCode code : ErrorCode.values()) {
      ResponseEntity<ErrorResponse> response =
        CurrentLocale.callAs(AppLocale.JA, () -> handler.handleCustomException(new CustomException(code)));

      assertThat(response.getStatusCode().value()).isEqualTo(code.getStatus().value());
      assertThat(response.getBody().errorCode()).isEqualTo(code);
      // 번역 파일을 채우면 값이 달라지므로 "ko 와 같다"가 아니라 "대체 순서가 고른 값"이다
      assertThat(response.getBody().errorMessage())
        .isNotBlank()
        .isEqualTo(ErrorMessages.standard().of(code, AppLocale.JA));
    }
  }

  @Test
  @DisplayName("multipart 한도 초과 응답도 헤더가 없으면 이전과 같다")
  void multipartLimit_headerless_isLegacy() throws Exception {
    ResponseEntity<ErrorResponse> response = new MultipartLimitExceptionHandler().handleMaxUploadSize(
      new MaxUploadSizeExceededException(1L), new MockHttpServletRequest("POST", "/api/routines/r1/steps/s1/image"));

    assertThat(MAPPER.writeValueAsString(response.getBody()))
      .isEqualTo(legacyJson(ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE));
  }

  @Test
  @DisplayName("인증 진입점(401)의 본문도 헤더가 없으면 이전과 같다")
  void entryPoint_headerless_isLegacy() throws Exception {
    MockHttpServletResponse response = new MockHttpServletResponse();

    new JwtAuthenticationEntryPoint().commence(
      new MockHttpServletRequest("GET", "/api/member/me"), response, new BadCredentialsException("x"));

    assertThat(response.getStatus()).isEqualTo(401);
    assertThat(response.getContentAsString(StandardCharsets.UTF_8)).isEqualTo(legacyJson(ErrorCode.INVALID_TOKEN));
  }

  @Test
  @DisplayName("DLP 필터의 오류 본문은 에러 코드와 문구가 이전과 같다 (키 순서는 원래 보장되지 않았다)")
  void dlpFilter_headerless_isLegacy() throws Exception {
    AidlpDecryptionFilter filter =
      new AidlpDecryptionFilter(mock(AidlpCryptoService.class), mock(NonceStore.class), new AidlpProperties());
    MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/routines");
    request.setContent("{\"encrypted\":{}}".getBytes(StandardCharsets.UTF_8));
    MockHttpServletResponse response = new MockHttpServletResponse();

    filter.doFilter(request, response, new MockFilterChain());

    JsonNode body = MAPPER.readTree(response.getContentAsString(StandardCharsets.UTF_8));
    assertThat(body.get("errorCode").asText()).isEqualTo("DLP_SECRET_NOT_CONFIGURED");
    assertThat(body.get("errorMessage").asText())
      .isEqualTo(GOLDEN.get("DLP_SECRET_NOT_CONFIGURED").get("message"));
  }

  // --- 점검 모드: 관리자가 적은 안내는 그대로, 기본 문구는 요청 언어로 ---

  private MockHttpServletResponse maintenance(String configuredMessage, AppLocale locale) throws Exception {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getBoolean(ConfigKey.MAINTENANCE_MODE)).thenReturn(true);
    when(config.getString(ConfigKey.MAINTENANCE_MESSAGE)).thenReturn(configuredMessage);
    MockHttpServletResponse response = new MockHttpServletResponse();
    CurrentLocale.runAs(locale, () -> {
      try {
        new MaintenanceModeFilter(config).doFilter(
          new MockHttpServletRequest("GET", "/api/member/me"), response, new MockFilterChain());
      } catch (Exception e) {
        throw new IllegalStateException(e);
      }
    });
    return response;
  }

  @Test
  @DisplayName("점검: 헤더가 없고 안내가 비었으면 이전 응답과 같다")
  void maintenance_headerless_blankMessage_isLegacy() throws Exception {
    MockHttpServletResponse response = maintenance("", AppLocale.KO);

    assertThat(response.getStatus()).isEqualTo(503);
    assertThat(response.getContentAsString(StandardCharsets.UTF_8)).isEqualTo(legacyJson(ErrorCode.MAINTENANCE_MODE));
  }

  @Test
  @DisplayName("점검: 기본 안내 문구 그대로면 요청 언어로 바꾼다 — ko 는 같은 글자다")
  void maintenance_defaultText_followsLocale() throws Exception {
    String defaultText = ConfigKey.MAINTENANCE_MESSAGE.getDefaultValue();

    assertThat(maintenance(defaultText, AppLocale.KO).getContentAsString(StandardCharsets.UTF_8))
      .isEqualTo(legacyJson(ErrorCode.MAINTENANCE_MODE));
    JsonNode ja = MAPPER.readTree(maintenance(defaultText, AppLocale.JA).getContentAsString(StandardCharsets.UTF_8));
    assertThat(ja.get("errorMessage").asText())
      .isEqualTo(ErrorMessages.standard().of(ErrorCode.MAINTENANCE_MODE, AppLocale.JA));
  }

  @Test
  @DisplayName("점검: 관리자가 직접 쓴 안내는 어느 언어에서도 그대로 준다")
  void maintenance_customText_passesThrough() throws Exception {
    JsonNode ja = MAPPER.readTree(
      maintenance("오늘 밤 10시까지 점검해요", AppLocale.JA).getContentAsString(StandardCharsets.UTF_8));

    assertThat(ja.get("errorMessage").asText()).isEqualTo("오늘 밤 10시까지 점검해요");
  }
}
```

- [ ] **Step 2: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.LocalizedErrorResponsesTest'`
Expected: **FAIL** (`maintenance_defaultText_followsLocale` 는 코드가 아직 `getMessage()` 를 써서, 대체 순서가 고른 값과 다를 수 있다. 번역 파일이 비어 있는 지금은 ko 와 같은 글자가 나오므로 일부 테스트는 통과할 수 있다 — **실패하는 것이 있는지 확인하고, 없으면 Step 3 구현 뒤 `jaRequest_keepsStatusAndCode_andFollowsChain` 의 의미가 구현을 통해서만 성립함을 코드 리뷰로 확인한다**)

> 참고: 번역 파일이 비어 있는 동안에는 ja 요청이 ko 와 같은 글자를 받으므로 이 테스트들은 구현 전에도 우연히 통과할 수 있다. 그래서 Task 3 의 `ErrorMessagesTest`(가짜 리소스로 대체 순서를 직접 검증)가 대체 순서의 증거이고, 이 Task 의 테스트는 **헤더 없음 = 바이트 동일** 과 **배선**을 지킨다. 배선이 끊기면(누군가 `getMessage()` 로 되돌리면) 번역을 채운 순간 ja 요청이 ko 문구를 받는 것을 `jaRequest_keepsStatusAndCode_andFollowsChain` 이 잡는다.

- [ ] **Step 3: 구현**

**`GlobalExceptionHandler.java`**

1. import 를 더한다: `import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;`
2. 클래스 선언(`public class GlobalExceptionHandler {`) 바로 아래에 필드를 더한다.
```java
  // 문구는 요청 언어로 고른다(다국어 #521). 헤더가 없으면 KO 라 이전 응답과 같다.
  private final ErrorMessages messages = ErrorMessages.standard();

```
3. 파일 안의 `new ErrorResponse(errorCode, errorCode.getMessage())` 를 **모두** `new ErrorResponse(errorCode, messages.of(errorCode))` 로 바꾼다(Edit `replace_all`, 6곳: 54·88·97·109·119·128행).
4. 검증 오류 핸들러의 `.orElse(ErrorCode.INVALID_INPUT_VALUE.getMessage());` 를 `.orElse(messages.of(ErrorCode.INVALID_INPUT_VALUE));` 로 바꾼다. (필드별 문구와 "요청 본문을 읽을 수 없습니다." 는 Task 7)

**`MultipartLimitExceptionHandler.java`**: import `ErrorMessages` 를 더하고, 클래스 안에 `private final ErrorMessages messages = ErrorMessages.standard();` 를 더한 뒤 40행 `errorCode.getMessage()` 를 `messages.of(errorCode)` 로 바꾼다.

**`JwtAuthenticationEntryPoint.java`**: import `ErrorMessages` 를 더하고 `objectMapper` 필드 아래에 `private final ErrorMessages messages = ErrorMessages.standard();` 를 더한 뒤 28행을 다음으로 바꾼다.
```java
    // 보안 필터가 직접 쓰는 응답이라 어드바이스를 타지 않는다. AcceptLanguageFilter 가 앞서 언어를 심어 둔다.
    ErrorResponse errorResponse = new ErrorResponse(errorCode, messages.of(errorCode));
```

**`AidlpDecryptionFilter.java`**: import `ErrorMessages` 를 더하고 `objectMapper` 필드 아래에 `private final ErrorMessages messages = ErrorMessages.standard();` (초기화된 final 필드라 `@RequiredArgsConstructor` 가 생성자에 넣지 않는다)를 더한 뒤 `writeError` 의 `code.getMessage()` 를 `messages.of(code)` 로 바꾼다.

**`MaintenanceModeFilter.java`**: import `ErrorMessages` 를 더하고 `objectMapper` 필드 아래에 `private final ErrorMessages messages = ErrorMessages.standard();` 를 더한 뒤 `message()` 전체(86-94행)를 다음으로 바꾼다.
```java
  /**
   * 점검 안내. 관리자가 직접 쓴 문구(한국어)는 그대로 준다. 기본 문구를 그대로 둔 경우만 요청 언어로 바꾼다 —
   * 기본 문구는 ErrorCode.MAINTENANCE_MODE 의 ko 문구와 같은 글자라 ko 응답은 이전과 같다.
   */
  private String message() {
    ErrorCode code = ErrorCode.MAINTENANCE_MODE;
    try {
      String configured = systemConfigService.getString(ConfigKey.MAINTENANCE_MESSAGE);
      boolean untouched = configured == null || configured.isBlank()
        || configured.equals(ConfigKey.MAINTENANCE_MESSAGE.getDefaultValue());
      return untouched ? messages.of(code) : configured;
    } catch (RuntimeException e) {
      return messages.of(code);
    }
  }
```

- [ ] **Step 4: 실행해서 통과를 확인한다**

Run:
```bash
cd server && ./gradlew test \
  --tests 'com.chuseok22.elumserver.common.LocalizedErrorResponsesTest' \
  --tests 'com.chuseok22.elumserver.common.GlobalExceptionHandlerMultipartTest' \
  --tests 'com.chuseok22.elumserver.common.MultipartLimitExceptionHandlerTest' \
  --tests 'com.chuseok22.elumserver.common.infrastructure.security.MaintenanceModeFilterTest' \
  --tests 'com.chuseok22.elumserver.common.infrastructure.config.SecurityConfigInternalPathTest' \
  --tests 'com.chuseok22.elumserver.common.ExceptionHandlerCoverageTest'
```
Expected: **PASS** (보안 슬라이스 테스트는 `JwtAuthenticationEntryPoint` 를 `@Import` 로 그대로 쓴다 — 생성자를 바꾸지 않았으므로 그대로 통과한다)

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/application/exception/GlobalExceptionHandler.java \
        server/src/main/java/com/chuseok22/elumserver/common/application/exception/MultipartLimitExceptionHandler.java \
        server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/MaintenanceModeFilter.java \
        server/src/main/java/com/chuseok22/elumserver/common/infrastructure/jwt/JwtAuthenticationEntryPoint.java \
        server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpDecryptionFilter.java \
        server/src/test/java/com/chuseok22/elumserver/common/LocalizedErrorResponsesTest.java
```

---

## Task 7: 검증 오류(`@Valid`)와 "요청 본문을 읽을 수 없습니다" 문구

`GlobalExceptionHandler` 의 `detail` 경로는 두 가지다 — (1) `MethodArgumentNotValidException` 의 첫 필드 오류 `"필드: DTO message"`, (2) `HttpMessageNotReadableException` 의 고정 문장. 둘 다 에러 코드는 `INVALID_INPUT_VALUE` 이고 문구가 `errorMessage` 로 나간다. 필드 이름 부분(`rawInputText: `)은 영어 식별자라 그대로 둔다.

**방식:** 키 `validation.<객체이름>.<필드>.<제약>`(예: `validation.routineCreateRequest.rawInputText.NotBlank`)을 ko 리소스에 DTO message 와 **같은 글자로** 둔다(테스트가 DTO 어노테이션과 대조). 요청 언어에 키가 없으면 대체 순서, 그래도 없으면 DTO 의 `message`(한국어)다. DTO 는 고치지 않는다.

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessages.java` (끝에 `ofValidation` 추가)
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/application/exception/GlobalExceptionHandler.java` (57-77행: 검증·본문 읽기 핸들러)
- Modify: `server/src/main/resources/i18n/messages_ko.properties` (끝에 18줄)
- Test: `server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/ValidationMessageKeysTest.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/common/GlobalExceptionHandlerLocaleMvcTest.java`

**Interfaces:**
- Consumes: `ErrorMessages.of(String, AppLocale, String)`, `AcceptLanguageFilter`, `CurrentLocale`
- Produces: `public String ErrorMessages.ofValidation(FieldError error, AppLocale locale)`

- [ ] **Step 1: 키·문구 대조 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/ValidationMessageKeysTest.java`:

```java
package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.beans.Introspector;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.annotation.Annotation;
import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.RegexPatternTypeFilter;

/**
 * request DTO 의 {@code message} 문구와 ko 리소스가 같은 글자인지 대조한다 (다국어 #521).
 *
 * <p>DTO 의 문구가 {@code FieldError.getDefaultMessage()} 로 나가는 지금 응답이 원본이다. ko 리소스를 따로 두는 이유는
 * 다른 언어 번역을 같은 키 체계로 받기 위해서이고, 둘이 어긋나면 헤더 없는 앱의 응답이 바뀐다.
 * 새 DTO 에 message 를 적으면 여기서 걸린다 — 키를 ko 리소스에 더해야 번역이 들어갈 자리가 생긴다.
 */
class ValidationMessageKeysTest {

  private record Constraint(String key, String message) {
  }

  private static List<Constraint> literalConstraints() throws Exception {
    ClassPathScanningCandidateComponentProvider scanner = new ClassPathScanningCandidateComponentProvider(false);
    scanner.addIncludeFilter(new RegexPatternTypeFilter(Pattern.compile(".*\\.dto\\.request\\..+")));
    List<Constraint> found = new ArrayList<>();
    for (BeanDefinition definition : scanner.findCandidateComponents("com.chuseok22.elumserver")) {
      Class<?> type = Class.forName(definition.getBeanClassName());
      for (Field field : type.getDeclaredFields()) {
        for (Annotation annotation : field.getAnnotations()) {
          Class<? extends Annotation> annotationType = annotation.annotationType();
          if (!annotationType.getName().startsWith("jakarta.validation.constraints.")) {
            continue;
          }
          String message = (String) annotationType.getMethod("message").invoke(annotation);
          if (message.startsWith("{")) {
            continue; // message 를 안 적은 제약은 Hibernate Validator 기본 문구다 — 이 계획 범위 밖
          }
          found.add(new Constraint(
            "validation." + Introspector.decapitalize(type.getSimpleName()) + "." + field.getName() + "."
              + annotationType.getSimpleName(),
            message));
        }
      }
    }
    return found;
  }

  private static Properties koFile() throws Exception {
    Properties properties = new Properties();
    try (InputStream in = ValidationMessageKeysTest.class.getResourceAsStream("/i18n/messages_ko.properties")) {
      properties.load(new InputStreamReader(in, StandardCharsets.UTF_8));
    }
    return properties;
  }

  @Test
  @DisplayName("message 를 적은 제약이 있고, 키가 서로 겹치지 않는다")
  void keysAreUnique() throws Exception {
    List<Constraint> found = literalConstraints();

    assertThat(found).hasSizeGreaterThanOrEqualTo(17);
    assertThat(found.stream().map(Constraint::key).toList()).doesNotHaveDuplicates();
  }

  @Test
  @DisplayName("ko 리소스는 DTO message 와 글자 하나까지 같다")
  void koResource_equalsDtoMessage() throws Exception {
    for (Constraint constraint : literalConstraints()) {
      assertThat(ErrorMessages.standard().of(constraint.key(), AppLocale.KO, "<<없음>>"))
        .as(constraint.key())
        .isEqualTo(constraint.message());
    }
  }

  @Test
  @DisplayName("ko 리소스의 validation.* 키는 DTO 에 실제로 있는 제약과 정확히 일치한다 — 쓰이지 않는 키가 남지 않는다")
  void koResourceKeys_matchDtoConstraints() throws Exception {
    Set<String> expected = literalConstraints().stream().map(Constraint::key).collect(Collectors.toSet());
    Set<String> inFile = koFile().stringPropertyNames().stream()
      .filter(key -> key.startsWith("validation."))
      .collect(Collectors.toSet());

    assertThat(inFile).containsExactlyInAnyOrderElementsOf(expected);
  }

  @Test
  @DisplayName("본문을 읽을 수 없을 때의 문구 키가 ko 리소스에 있다")
  void unreadableBodyKey_exists() {
    assertThat(ErrorMessages.standard().of("detail.requestBodyUnreadable", AppLocale.KO, "<<없음>>"))
      .isEqualTo("요청 본문을 읽을 수 없습니다.");
  }
}
```

- [ ] **Step 2: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.common.infrastructure.exception.ValidationMessageKeysTest'`
Expected: **FAIL** (ko 리소스에 `validation.*` · `detail.*` 키가 없다)

- [ ] **Step 3: ko 리소스에 키를 더한다**

`server/src/main/resources/i18n/messages_ko.properties` 끝에 이어 붙인다.

```bash
cat >> server/src/main/resources/i18n/messages_ko.properties <<'EOF'

# --- 요청 검증(@Valid) 필드 문구. 키: validation.<객체이름>.<필드>.<제약>. DTO 의 message 와 같은 글자여야 한다(ValidationMessageKeysTest) ---
validation.routineStepUpdateRequest.title.Size=카드 제목은 100자를 넘을 수 없습니다.
validation.routineStepUpdateRequest.description.Size=카드 설명은 300자를 넘을 수 없습니다.
validation.routineStepUpdateRequest.stepOrder.Min=카드 순서는 1부터 시작합니다.
validation.routineCreateRequest.rawInputText.NotBlank=일과 내용을 입력해주세요.
validation.routineCreateRequest.rawInputText.Size=일과 내용은 1000자를 넘을 수 없습니다.
validation.routineCreateRequest.rewardText.Size=보상은 100자를 넘을 수 없습니다.
validation.routineStepCreateRequest.title.NotBlank=카드 제목은 비울 수 없습니다.
validation.routineStepCreateRequest.title.Size=카드 제목은 100자를 넘을 수 없습니다.
validation.routineStepCreateRequest.description.Size=카드 설명은 300자를 넘을 수 없습니다.
validation.routineQuestionRequest.rawInputText.NotBlank=일과 내용을 입력해주세요.
validation.routineQuestionRequest.rawInputText.Size=일과 내용은 1000자를 넘을 수 없습니다.
validation.memberConsentRequest.termsAgreed.AssertTrue=서비스 이용약관에 동의해야 합니다.
validation.memberConsentRequest.privacyAgreed.AssertTrue=개인정보 수집·이용에 동의해야 합니다.
validation.memberConsentRequest.overseasTransferAgreed.AssertTrue=개인정보 국외 이전에 동의해야 합니다.
validation.memberConsentRequest.guardianConfirmed.AssertTrue=법정대리인 확인이 필요합니다.
validation.sensitiveInfoCheckRequest.text.NotBlank=검사할 내용을 입력해주세요.
validation.sensitiveInfoCheckRequest.text.Size=검사할 내용은 1000자를 넘을 수 없습니다.

# --- 에러 코드가 아닌 고정 문장 (GlobalExceptionHandler) ---
detail.requestBodyUnreadable=요청 본문을 읽을 수 없습니다.
EOF
```

- [ ] **Step 4: `ErrorMessages` 에 `ofValidation` 을 더한다**

`ErrorMessages.java` 에 import `org.springframework.validation.FieldError;` 를 더하고 클래스 끝(마지막 `}` 앞)에 추가한다.

```java

  /**
   * 요청 검증 실패 필드 하나의 문구. 키는 {@code validation.{객체이름}.{필드}.{제약}} 이다.
   * 어느 언어에도 키가 없으면 DTO 에 적은 message(한국어)를 그대로 준다 — 헤더 없는 앱의 응답이 바뀌지 않는다.
   */
  public String ofValidation(FieldError error, AppLocale locale) {
    String key = "validation." + error.getObjectName() + "." + error.getField() + "." + error.getCode();
    return of(key, locale, error.getDefaultMessage());
  }
```

- [ ] **Step 5: `GlobalExceptionHandler` 를 고친다**

검증 오류 핸들러(`handleValidationException`)의 `detail` 계산부를 바꾼다.

기존:
```java
    String detail = e.getBindingResult().getFieldErrors().stream()
      .map(error -> error.getField() + ": " + error.getDefaultMessage())
      .findFirst()
      .orElse(messages.of(ErrorCode.INVALID_INPUT_VALUE));
```
바꿈:
```java
    // 필드 이름은 식별자라 그대로 두고 문구만 요청 언어로 고른다. 키가 없으면 DTO message(한국어)다.
    AppLocale locale = CurrentLocale.get();
    String detail = e.getBindingResult().getFieldErrors().stream()
      .map(error -> error.getField() + ": " + messages.ofValidation(error, locale))
      .findFirst()
      .orElse(messages.of(ErrorCode.INVALID_INPUT_VALUE, locale));
```
`handleMessageNotReadable` 의 본문을 바꾼다.

기존: `.body(new ErrorResponse(errorCode, "요청 본문을 읽을 수 없습니다."));`
바꿈:
```java
      .body(new ErrorResponse(errorCode,
        messages.of("detail.requestBodyUnreadable", CurrentLocale.get(), "요청 본문을 읽을 수 없습니다.")));
```
import 두 줄을 더한다: `com.chuseok22.elumserver.common.locale.AppLocale`, `com.chuseok22.elumserver.common.locale.CurrentLocale`.

- [ ] **Step 6: 실제 MVC 경로 테스트를 쓴다**

standalone MockMvc 로 필터 → 컨트롤러 → 어드바이스를 실제로 돌린다(스프링 컨텍스트 없음). `Probe` 는 클래스 수준 컨트롤러 어노테이션을 달지 않아 컴포넌트 스캔에 잡히지 않는다. 어드바이스의 `basePackages` 에 걸리도록 테스트를 `com.chuseok22.elumserver.common` 아래에 둔다.

`server/src/test/java/com/chuseok22/elumserver/common/GlobalExceptionHandlerLocaleMvcTest.java`:

```java
package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.application.exception.GlobalExceptionHandler;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.common.locale.AcceptLanguageFilter;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import jakarta.validation.Valid;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 필터 → 컨트롤러 → 예외 어드바이스를 실제로 거친 응답 (다국어 #521).
 *
 * <p>단위 테스트가 핸들러를 직접 부르는 것과 달리, 여기서는 {@code Accept-Language} 가 실제 요청 헤더로 들어간다.
 * 헤더가 없으면 응답 본문이 이전과 <b>바이트 단위로 같아야</b> 한다 — 기대 문자열은 작업 전 응답을 손으로 적은 것이다.
 */
class GlobalExceptionHandlerLocaleMvcTest {

  /** 클래스 수준 컨트롤러 어노테이션이 없어 컴포넌트 스캔에 잡히지 않는다. standalone MockMvc 가 직접 등록한다. */
  public static class Probe {

    @GetMapping("/probe/error")
    @ResponseBody
    public String error() {
      throw new CustomException(ErrorCode.ROUTINE_NOT_FOUND);
    }

    @PostMapping("/probe/routine")
    @ResponseBody
    public String create(@RequestBody @Valid RoutineCreateRequest request) {
      return "ok";
    }
  }

  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    mockMvc = MockMvcBuilders.standaloneSetup(new Probe())
      .setControllerAdvice(new GlobalExceptionHandler())
      .addFilters(new AcceptLanguageFilter())
      .build();
  }

  private String body(org.springframework.test.web.servlet.ResultActions actions) throws Exception {
    return actions.andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
  }

  @Test
  @DisplayName("헤더 없음: CustomException 응답이 이전과 바이트 단위로 같다")
  void headerless_customException_isLegacy() throws Exception {
    var result = mockMvc.perform(get("/probe/error")).andExpect(status().isNotFound());

    assertThat(body(result).getBytes(StandardCharsets.UTF_8)).isEqualTo(
      "{\"errorCode\":\"ROUTINE_NOT_FOUND\",\"errorMessage\":\"존재하지 않는 일과입니다.\"}".getBytes(StandardCharsets.UTF_8));
  }

  @Test
  @DisplayName("헤더 없음: 검증 오류 응답이 이전과 바이트 단위로 같다 — 필드 이름 + DTO 문구")
  void headerless_validation_isLegacy() throws Exception {
    var result = mockMvc.perform(post("/probe/routine").contentType(MediaType.APPLICATION_JSON)
      .content("{\"rawInputText\":\"\"}")).andExpect(status().isBadRequest());

    assertThat(body(result).getBytes(StandardCharsets.UTF_8)).isEqualTo(
      "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"rawInputText: 일과 내용을 입력해주세요.\"}"
        .getBytes(StandardCharsets.UTF_8));
  }

  @Test
  @DisplayName("헤더 없음: 본문을 읽을 수 없을 때 응답이 이전과 바이트 단위로 같다")
  void headerless_unreadableBody_isLegacy() throws Exception {
    var result = mockMvc.perform(post("/probe/routine").contentType(MediaType.APPLICATION_JSON)
      .content("{깨진 json")).andExpect(status().isBadRequest());

    assertThat(body(result).getBytes(StandardCharsets.UTF_8)).isEqualTo(
      "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"요청 본문을 읽을 수 없습니다.\"}"
        .getBytes(StandardCharsets.UTF_8));
  }

  @Test
  @DisplayName("일본어 요청: 상태·에러 코드는 그대로이고 필드 문구는 대체 순서가 고른 값이다")
  void jaRequest_validation_followsChain() throws Exception {
    String expectedMessage = ErrorMessages.standard()
      .of("validation.routineCreateRequest.rawInputText.NotBlank", AppLocale.JA, "<<없음>>");

    mockMvc.perform(post("/probe/routine").header("Accept-Language", "ja").contentType(MediaType.APPLICATION_JSON)
        .content("{\"rawInputText\":\"\"}"))
      .andExpect(status().isBadRequest())
      .andExpect(jsonPath("$.errorCode").value("INVALID_INPUT_VALUE"))
      .andExpect(jsonPath("$.errorMessage").value("rawInputText: " + expectedMessage));
  }

  @ParameterizedTest
  @ValueSource(strings = {"*", "ar", "zh-TW", "zh-Hant", "zh-Hans", "en;q=0.1, ja;q=0.9", ";;;", "-", "\u0000", "日本語"})
  @DisplayName("이상한 Accept-Language 도 500 이 아니라 정해진 응답이 나온다")
  void weirdHeaders_neverBreakTheResponse(String header) throws Exception {
    mockMvc.perform(get("/probe/error").header("Accept-Language", header))
      .andExpect(status().isNotFound())
      .andExpect(jsonPath("$.errorCode").value("ROUTINE_NOT_FOUND"))
      .andExpect(jsonPath("$.errorMessage").isNotEmpty());
  }
}
```

- [ ] **Step 7: 실행해서 통과를 확인한다**

Run:
```bash
cd server && ./gradlew test \
  --tests 'com.chuseok22.elumserver.common.infrastructure.exception.ValidationMessageKeysTest' \
  --tests 'com.chuseok22.elumserver.common.GlobalExceptionHandlerLocaleMvcTest' \
  --tests 'com.chuseok22.elumserver.common.LocalizedErrorResponsesTest' \
  --tests 'com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessageParityTest'
```
Expected: **PASS**. 실패하면 먼저 `validation.*` 키 철자(객체 이름은 클래스 이름의 첫 글자만 소문자)와 `FieldError.getCode()` 가 `NotBlank`/`Size`/`Min`/`AssertTrue` 인지 확인한다.
`MockHttpServletRequest` 가 특정 이상한 헤더 값(`;;;`, `\u0000` 등) 자체를 거절해 테스트 준비 단계에서 던지면 그 값만 `weirdHeaders` 목록에서 뺀다 — 같은 값이 서버 코드에서 터지지 않는다는 증거는 `AppLocaleTest.neverThrows` 와 `AcceptLanguageFilterTest` 가 따로 가진다.

- [ ] **Step 8: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorMessages.java \
        server/src/main/java/com/chuseok22/elumserver/common/application/exception/GlobalExceptionHandler.java \
        server/src/main/resources/i18n/messages_ko.properties \
        server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/ValidationMessageKeysTest.java \
        server/src/test/java/com/chuseok22/elumserver/common/GlobalExceptionHandlerLocaleMvcTest.java
```

---

## Task 8: 서버가 만드는 문장 — `RoutinePhrases` (폴백 질문 · 추천 일과)

`RoutineAiPipeline` 폴백 질문(질문 1 + 선택지 라벨/이모지)과 `RoutineSuggestionCatalog` 58개를 언어별 properties 로 옮긴다. **한 파일이 "한 벌"** 이다 — 키가 하나라도 비면 그 언어는 미완성으로 보고 대체 순서(`en` → `ko`)로 넘긴다(여러 언어가 한 목록에 섞이지 않게).

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrases.java`
- Create: `server/src/main/resources/i18n/routine-phrases_ko.properties` (기존 코드에서 생성), `routine-phrases_{en,ja,zh,es}.properties` (머리 주석만)
- Create: `server/src/test/resources/i18n/golden/routine-phrases-ko.json` (기존 코드에서 생성)
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutineSuggestionCatalog.java` (전체 교체)
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/ai/RoutineAiPipeline.java` (import, 168-192행 `fallbackQuestionItem`·`option`)
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineService.java` (`getSuggestions` 820-826행)
- Test: `server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrasesTest.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrasesParityTest.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/ai/RoutineAiPipelineFallbackLocaleTest.java`

**Interfaces:**
- Consumes: `AppLocale`, `CurrentLocale`, `SupportGoal`, `RoutineSuggestionResponse`(기존 record: `icon, text, naturalLanguageExample`)
- Produces:
  ```java
  public final class RoutinePhrases {
    public RoutinePhrases(Function<AppLocale, Map<String, String>> loader);
    public static RoutinePhrases standard();
    public List<String> missingKeys(AppLocale locale);                              // ko 파일이 기준. 비어 있으면 완성
    public Map<AppLocale, List<String>> incompleteLocales(Collection<AppLocale> locales);
    public List<RoutineSuggestionResponse> suggestions(AppLocale requested);        // 완성된 첫 언어(요청 → en → ko)
    public FallbackQuestion fallbackQuestion(SupportGoal goal, AppLocale requested);
    public record FallbackQuestion(String question, List<Option> options) { public record Option(String emoji, String label) {} }
  }
  public final class RoutineSuggestionCatalog {
    public static final List<RoutineSuggestionResponse> ALL;                        // ko, 기존 이름 유지
    public static List<RoutineSuggestionResponse> forLocale(AppLocale locale);
  }
  ```
  파일 키: `suggestion.NN.icon|text|example`(NN=01..58), `fallback.<PREPARE_ITEMS|PREPARE_NEW>.question`, `fallback.<목표>.option.N.emoji|label`.

- [ ] **Step 1: 단위 테스트(가짜 로더)를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrasesTest.java`:

```java
package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 가짜 문구 파일로 "한 벌" 규칙과 대체 순서를 본다. 실제 번역 내용과 무관하다. */
class RoutinePhrasesTest {

  private static Map<String, String> full(String tag) {
    Map<String, String> map = new HashMap<>();
    for (int i = 1; i <= 2; i++) {
      String n = "%02d".formatted(i);
      map.put("suggestion." + n + ".icon", "I" + i);
      map.put("suggestion." + n + ".text", tag + "-text-" + n);
      map.put("suggestion." + n + ".example", tag + "-example-" + n);
    }
    for (String goal : List.of("PREPARE_ITEMS", "PREPARE_NEW")) {
      map.put("fallback." + goal + ".question", tag + "-q-" + goal);
      for (int i = 1; i <= 3; i++) {
        map.put("fallback." + goal + ".option." + i + ".emoji", "E" + i);
        map.put("fallback." + goal + ".option." + i + ".label", tag + "-o" + i);
      }
    }
    return map;
  }

  private static RoutinePhrases phrasesOf(Map<AppLocale, Map<String, String>> files) {
    return new RoutinePhrases(locale -> files.getOrDefault(locale, Map.of()));
  }

  @Test
  @DisplayName("ko 파일이 기준이다 — 같은 키가 모두 채워져 있어야 완성이다")
  void completeWhenAllKoKeysFilled() {
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en")));

    assertThat(phrases.missingKeys(AppLocale.KO)).isEmpty();
    assertThat(phrases.missingKeys(AppLocale.EN)).isEmpty();
    assertThat(phrases.missingKeys(AppLocale.JA)).hasSize(full("ko").size());
  }

  @Test
  @DisplayName("값이 빈 키도 비어 있는 것으로 센다")
  void blankValueCountsAsMissing() {
    Map<String, String> ja = full("ja");
    ja.put("fallback.PREPARE_NEW.option.2.label", "  ");
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.JA, ja));

    assertThat(phrases.missingKeys(AppLocale.JA)).containsExactly("fallback.PREPARE_NEW.option.2.label");
  }

  @Test
  @DisplayName("ko 파일에 꼭 있어야 하는 키(폴백 질문·추천 첫 항목)가 빠지면 ko 도 미완성이다")
  void koStructure_isRequired() {
    Map<String, String> ko = full("ko");
    ko.remove("fallback.PREPARE_NEW.question");
    var phrases = phrasesOf(Map.of(AppLocale.KO, ko));

    assertThat(phrases.missingKeys(AppLocale.KO)).contains("fallback.PREPARE_NEW.question");
  }

  @Test
  @DisplayName("요청 언어가 완성이면 그 언어의 목록을 준다")
  void completeRequestLanguage_isUsed() {
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en"), AppLocale.ES, full("es")));

    assertThat(phrases.suggestions(AppLocale.ES)).extracting("text").containsExactly("es-text-01", "es-text-02");
    assertThat(phrases.fallbackQuestion(SupportGoal.PREPARE_ITEMS, AppLocale.ES).question()).isEqualTo("es-q-PREPARE_ITEMS");
  }

  @Test
  @DisplayName("요청 언어가 미완성이면 en, en 도 미완성이면 ko 로 간다 — 두 언어가 한 목록에 섞이지 않는다")
  void incompleteRequestLanguage_fallsBackAsWholeSet() {
    Map<String, String> partialJa = new HashMap<>();
    partialJa.put("suggestion.01.text", "ja-text-01");
    var withEn = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en"), AppLocale.JA, partialJa));
    var withoutEn = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.JA, partialJa));

    assertThat(withEn.suggestions(AppLocale.JA)).extracting("text").containsExactly("en-text-01", "en-text-02");
    assertThat(withoutEn.suggestions(AppLocale.JA)).extracting("text").containsExactly("ko-text-01", "ko-text-02");
    assertThat(withoutEn.suggestions(AppLocale.ZH)).extracting("text").containsExactly("ko-text-01", "ko-text-02");
  }

  @Test
  @DisplayName("ko 요청은 en 이 완성돼 있어도 영어로 새지 않는다")
  void koRequest_neverFallsToEnglish() {
    Map<String, String> brokenKo = full("ko");
    brokenKo.put("suggestion.02.text", "");
    var phrases = phrasesOf(Map.of(AppLocale.KO, brokenKo, AppLocale.EN, full("en")));

    // ko 가 미완성이어도 KO 요청은 ko 파일을 쓴다(기동 검사가 이 상태를 막는다)
    assertThat(phrases.suggestions(AppLocale.KO).get(0).text()).isEqualTo("ko-text-01");
  }

  @Test
  @DisplayName("선택지 수는 ko 파일을 따른다 — 다른 언어가 더 많이 적어도 같은 개수다")
  void optionCount_followsKo() {
    Map<String, String> en = full("en");
    en.put("fallback.PREPARE_ITEMS.option.4.emoji", "E4");
    en.put("fallback.PREPARE_ITEMS.option.4.label", "extra");
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, en));

    assertThat(phrases.fallbackQuestion(SupportGoal.PREPARE_ITEMS, AppLocale.EN).options()).hasSize(3);
  }

  @Test
  @DisplayName("incompleteLocales 는 미완성인 언어와 빠진 키만 돌려준다")
  void incompleteLocales_listsOnlyIncomplete() {
    var phrases = phrasesOf(Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en")));

    Map<AppLocale, List<String>> result =
      phrases.incompleteLocales(List.of(AppLocale.KO, AppLocale.EN, AppLocale.JA, AppLocale.ES));

    assertThat(result).containsOnlyKeys(AppLocale.JA, AppLocale.ES);
  }

  @Test
  @DisplayName("실제 문구 파일: 다섯 언어 파일이 모두 있고 ko 는 완성이다")
  void realFiles() {
    for (AppLocale locale : AppLocale.values()) {
      assertThat(getClass().getResource("/i18n/routine-phrases_" + locale.code() + ".properties"))
        .as("파일 %s", locale.code()).isNotNull();
    }
    assertThat(RoutinePhrases.standard().missingKeys(AppLocale.KO)).isEmpty();
    assertThat(RoutinePhrases.standard().suggestions(AppLocale.KO)).hasSize(58);
  }

  @Test
  @DisplayName("실제 문구 파일: 어느 언어도 빈 목록이나 빈 질문을 내지 않는다 — 비어 있으면 ko 로 간다")
  void realFiles_neverEmpty() {
    for (AppLocale locale : AppLocale.values()) {
      assertThat(RoutinePhrases.standard().suggestions(locale)).hasSize(58).allSatisfy(suggestion ->
        assertThat(suggestion.text()).isNotBlank());
      for (SupportGoal goal : List.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW)) {
        var question = RoutinePhrases.standard().fallbackQuestion(goal, locale);
        assertThat(question.question()).isNotBlank();
        assertThat(question.options()).hasSizeGreaterThanOrEqualTo(3).allSatisfy(option ->
          assertThat(option.label()).isNotBlank());
      }
    }
  }
}
```

- [ ] **Step 2: 패리티 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrasesParityTest.java`:

```java
package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * ko 추천 일과·폴백 질문이 다국어 작업 전과 같다는 증명 (다국어 #521).
 *
 * <p>golden 은 작업 전 {@code RoutineSuggestionCatalog} 의 58개와 {@code RoutineAiPipeline} 폴백 질문을 JSON 으로
 * 따로 고정한 것이다. 이모지의 ZWJ·변형 선택자까지 같은 코드 포인트여야 한다.
 */
class RoutinePhrasesParityTest {

  private static JsonNode golden() throws Exception {
    try (InputStream in = RoutinePhrasesParityTest.class.getResourceAsStream("/i18n/golden/routine-phrases-ko.json")) {
      assertThat(in).as("golden 파일").isNotNull();
      return new ObjectMapper().readTree(in);
    }
  }

  @Test
  @DisplayName("ko 추천 일과 58개가 작업 전과 같은 순서·같은 글자다")
  void koSuggestions_identicalToLegacy() throws Exception {
    JsonNode legacy = golden().get("suggestions");

    assertThat(legacy).hasSize(58);
    assertThat(RoutineSuggestionCatalog.ALL).hasSize(58);
    for (int i = 0; i < legacy.size(); i++) {
      var actual = RoutineSuggestionCatalog.ALL.get(i);
      assertThat(actual.icon()).as("icon #%d", i + 1).isEqualTo(legacy.get(i).get("icon").asText());
      assertThat(actual.text()).as("text #%d", i + 1).isEqualTo(legacy.get(i).get("text").asText());
      assertThat(actual.naturalLanguageExample()).as("example #%d", i + 1)
        .isEqualTo(legacy.get(i).get("example").asText());
    }
  }

  @Test
  @DisplayName("헤더 없음(KO): 추천 일과 목록은 ALL 과 같다")
  void headerless_suggestions_areAll() {
    assertThat(RoutineSuggestionCatalog.forLocale(AppLocale.KO)).isEqualTo(RoutineSuggestionCatalog.ALL);
  }

  @Test
  @DisplayName("ko 폴백 질문(질문·선택지 이모지·라벨)이 작업 전과 같다")
  void koFallbackQuestions_identicalToLegacy() throws Exception {
    JsonNode legacy = golden().get("fallback");

    for (SupportGoal goal : List.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW)) {
      JsonNode expected = legacy.get(goal.name());
      var actual = RoutinePhrases.standard().fallbackQuestion(goal, AppLocale.KO);

      assertThat(actual.question()).as(goal.name()).isEqualTo(expected.get("question").asText());
      assertThat(actual.options()).as(goal.name()).hasSize(expected.get("options").size());
      for (int i = 0; i < actual.options().size(); i++) {
        assertThat(actual.options().get(i).emoji()).isEqualTo(expected.get("options").get(i).get("emoji").asText());
        assertThat(actual.options().get(i).label()).isEqualTo(expected.get("options").get(i).get("label").asText());
      }
    }
  }
}
```

- [ ] **Step 3: 파이프라인 폴백 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/ai/RoutineAiPipelineFallbackLocaleTest.java`:

```java
package com.chuseok22.elumserver.routine.infrastructure.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** AI 가 실패했을 때의 폴백 질문이 요청 언어를 따르고, 헤더가 없으면 이전과 같은 한국어인지 본다. */
@ExtendWith(MockitoExtension.class)
class RoutineAiPipelineFallbackLocaleTest {

  @Mock private TextClientRouter textClientRouter;
  @Mock private ImageClientRouter imageClientRouter;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private FluxImageClient fluxImageClient;
  @Mock private GeminiTextClient geminiTextClient;
  @Mock private TextGenerationClient textGenerationClient;

  private RoutineAiPipeline pipeline;

  @BeforeEach
  void setUp() {
    pipeline = new RoutineAiPipeline(
      textClientRouter, imageClientRouter,
      new CardImageGenerator(imageClientRouter, fluxImageClient, geminiTextClient),
      routineImageStorage, PictogramCatalog.empty());
    lenient().when(textClientRouter.current()).thenReturn(textGenerationClient);
    // AI 가 실패하면 폴백 질문이 나간다
    when(textGenerationClient.generateQuestionJson(any(), any(), any())).thenThrow(new RuntimeException("AI 실패"));
  }

  private RoutineAiPipeline.RoutineQuestionResult ask() {
    return pipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW), "내일 비 오는 날");
  }

  @Test
  @DisplayName("헤더 없음(KO): AI 가 실패하면 작업 전과 같은 한국어 질문과 선택지가 나간다")
  void headerless_fallback_isLegacyKorean() throws Exception {
    JsonNode legacy;
    try (InputStream in = getClass().getResourceAsStream("/i18n/golden/routine-phrases-ko.json")) {
      legacy = new ObjectMapper().readTree(in).get("fallback");
    }

    var result = ask();

    assertThat(result.questions()).hasSize(2);
    for (int i = 0; i < 2; i++) {
      String goal = i == 0 ? "PREPARE_ITEMS" : "PREPARE_NEW";
      var item = result.questions().get(i);
      assertThat(item.question()).isEqualTo(legacy.get(goal).get("question").asText());
      assertThat(item.options()).hasSize(legacy.get(goal).get("options").size());
      for (int j = 0; j < item.options().size(); j++) {
        assertThat(item.options().get(j).emoji()).isEqualTo(legacy.get(goal).get("options").get(j).get("emoji").asText());
        assertThat(item.options().get(j).label()).isEqualTo(legacy.get(goal).get("options").get(j).get("label").asText());
      }
    }
  }

  @Test
  @DisplayName("일본어 요청: 폴백 질문은 문구 파일의 대체 순서가 고른 언어다 — 비어 있지 않고 직접 입력이 없다")
  void jaRequest_fallback_followsPhrases() {
    var result = CurrentLocale.callAs(AppLocale.JA, this::ask);

    assertThat(result.questions().get(0).question())
      .isNotBlank()
      .isEqualTo(RoutinePhrases.standard().fallbackQuestion(SupportGoal.PREPARE_ITEMS, AppLocale.JA).question());
    List<RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult> options =
      result.questions().stream().flatMap(q -> q.options().stream()).toList();
    assertThat(options).allSatisfy(option -> assertThat(option.label()).isNotBlank());
  }
}
```

- [ ] **Step 4: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests '*RoutinePhrasesTest' --tests '*RoutinePhrasesParityTest' --tests '*RoutineAiPipelineFallbackLocaleTest'`
Expected: **FAIL** (컴파일 오류 — `RoutinePhrases`, `RoutineSuggestionCatalog.forLocale` 없음)

- [ ] **Step 5: 문구 파일과 golden 을 기존 코드에서 생성한다 (1회용)**

Task 4 와 같은 방식이다(고정 커밋 `0164a36a`, 레포 루트에서 실행, 스크립트는 저장소에 넣지 않는다). 폴백 질문의 이모지(ZWJ·변형 선택자)를 손으로 옮겨 적지 않고 원본 소스에서 그대로 읽는다.

```bash
python3 - <<'PY'
import json, re, subprocess

BASE = "0164a36a"
def show(path):
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"]).decode("utf-8")

ROOT = "server/src/main/java/com/chuseok22/elumserver/routine/infrastructure"
catalog = show(f"{ROOT}/constant/RoutineSuggestionCatalog.java")
pipeline = show(f"{ROOT}/ai/RoutineAiPipeline.java")

suggestions = re.findall(r'new RoutineSuggestionResponse\("([^"]*)", "([^"]*)", "([^"]*)"\)', catalog)
assert len(suggestions) == 58, len(suggestions)

body = re.search(r'fallbackQuestionItem\(SupportGoal goal\) \{(.*?)\n  private RoutineQuestionResult\.QuestionResultItem\.OptionResult option', pipeline, re.S).group(1)
items = re.findall(r'new RoutineQuestionResult\.QuestionResultItem\(\s*"([^"]+)",\s*List\.of\((.*?)\)\s*\);', body, re.S)
assert len(items) == 2, len(items)
goals = ["PREPARE_ITEMS", "PREPARE_NEW"]
fallback = {}
for goal, (question, options_src) in zip(goals, items):
    options = re.findall(r'option\("([^"]*)", "([^"]*)"\)', options_src)
    assert len(options) >= 3, goal
    fallback[goal] = {"question": question, "options": [{"emoji": e, "label": l} for e, l in options]}
assert len(fallback["PREPARE_ITEMS"]["options"]) == 5 and len(fallback["PREPARE_NEW"]["options"]) == 4

def check(value):
    # properties 이스케이프가 필요한 글자는 지금 문구에 없다. 생기면 멈춰 사람이 본다.
    assert "\\" not in value and "\n" not in value and value == value.strip(), value
    return value

lines = [
    "# 서버가 만들어 내려보내는 일과 문구 (ko): AI 추가 질문 폴백, 홈 추천 일과.",
    "# 키: suggestion.NN.icon|text|example / fallback.<목표>.question / fallback.<목표>.option.N.emoji|label",
    "# 한 파일은 \"한 벌\"이다. 키가 하나라도 비면 그 언어는 미완성으로 보고 요청 언어 → en → ko 순서로 넘긴다.",
    "# 켜진 언어의 한 벌이 비면 서버가 뜨지 않는다(RoutinePhrasesStartupGuard).",
    "",
]
for i, (icon, text, example) in enumerate(suggestions, start=1):
    n = f"{i:02d}"
    lines += [f"suggestion.{n}.icon={check(icon)}", f"suggestion.{n}.text={check(text)}", f"suggestion.{n}.example={check(example)}"]
lines.append("")
for goal in goals:
    lines.append(f"fallback.{goal}.question={check(fallback[goal]['question'])}")
    for i, option in enumerate(fallback[goal]["options"], start=1):
        lines += [f"fallback.{goal}.option.{i}.emoji={check(option['emoji'])}", f"fallback.{goal}.option.{i}.label={check(option['label'])}"]
    lines.append("")
open("server/src/main/resources/i18n/routine-phrases_ko.properties", "w", encoding="utf-8").write("\n".join(lines))

golden = {
    "suggestions": [{"icon": i, "text": t, "example": e} for i, t, e in suggestions],
    "fallback": fallback,
}
with open("server/src/test/resources/i18n/golden/routine-phrases-ko.json", "w", encoding="utf-8") as f:
    json.dump(golden, f, ensure_ascii=False, indent=1)
    f.write("\n")
print("ok", len(suggestions), {g: len(v["options"]) for g, v in fallback.items()})
PY
for l in en ja zh es; do
  printf '# 서버가 만들어 내려보내는 일과 문구 (%s). 키 구조는 routine-phrases_ko.properties 와 같다.\n# 번역 값은 계획 5(번역과 품질)에서 채운다. 한 벌이 갖춰지기 전에는 요청 언어 → en → ko 순서로 대체되고, 이 언어를 켤 수 없다.\n' "$l" \
    > "server/src/main/resources/i18n/routine-phrases_${l}.properties"
done
git status --short server/src/main/resources/i18n server/src/test/resources/i18n
```
Expected: `ok 58 {'PREPARE_ITEMS': 5, 'PREPARE_NEW': 4}`, `git status` 에 새 파일이 `??` 로 보인다.

- [ ] **Step 6: `RoutinePhrases` 를 구현한다**

`server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrases.java`:

```java
package com.chuseok22.elumserver.routine.infrastructure.constant;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;
import lombok.extern.slf4j.Slf4j;

/**
 * 서버가 만들어 내려보내는 일과 문구 — AI 추가 질문 폴백, 홈 추천 일과 (다국어 #521).
 *
 * <p>원본은 {@code i18n/routine-phrases_{언어}.properties} 다. <b>한 파일이 "한 벌"</b>이다: ko 파일의 키가 기준이고
 * 한 언어의 파일이 그 키를 모두 채워야 완성이다. 미완성인 언어는 요청이 와도 건너뛰고 요청 언어 → en → ko 중 완성된
 * 첫 언어의 한 벌을 쓴다(두 언어가 한 목록에 섞이지 않게). KO 요청은 영어로 새지 않는다.
 *
 * <p>켜진 언어의 한 벌이 비면 {@code RoutinePhrasesStartupGuard} 가 서버를 세우지 않는다 — AI 가 실패하는 순간에
 * 문구도 없는 일을 막는다.
 */
@Slf4j
public final class RoutinePhrases {

  private static final String RESOURCE = "i18n/routine-phrases_%s.properties";
  private static final List<SupportGoal> FALLBACK_GOALS = List.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW);
  /** RoutineAiPipeline 이 질문을 인정하는 최소 선택지 수와 같은 기준. ko 파일이 이보다 적으면 미완성이다. */
  private static final int MIN_FALLBACK_OPTIONS = 3;
  private static final RoutinePhrases STANDARD = new RoutinePhrases(RoutinePhrases::loadFromClasspath);

  private final Function<AppLocale, Map<String, String>> loader;
  private final Map<AppLocale, Map<String, String>> files = new ConcurrentHashMap<>();
  private final Map<AppLocale, List<String>> missing = new ConcurrentHashMap<>();

  public RoutinePhrases(Function<AppLocale, Map<String, String>> loader) {
    this.loader = loader;
  }

  public static RoutinePhrases standard() {
    return STANDARD;
  }

  /** 이 언어의 파일에서 비어 있는 키. ko 파일의 키(+필수 구조)가 기준이고, 비어 있으면 완성이다. */
  public List<String> missingKeys(AppLocale locale) {
    return missing.computeIfAbsent(locale, this::computeMissing);
  }

  /** 미완성인 언어와 빠진 키. 완성된 언어는 담기지 않는다. */
  public Map<AppLocale, List<String>> incompleteLocales(Collection<AppLocale> locales) {
    Map<AppLocale, List<String>> result = new LinkedHashMap<>();
    for (AppLocale locale : locales) {
      List<String> keys = missingKeys(locale);
      if (!keys.isEmpty()) {
        result.put(locale, keys);
      }
    }
    return result;
  }

  public List<RoutineSuggestionResponse> suggestions(AppLocale requested) {
    Map<String, String> ko = file(AppLocale.KO);
    Map<String, String> phrases = file(resolve(requested));
    List<RoutineSuggestionResponse> list = new ArrayList<>();
    // 개수는 ko 파일이 정한다 — 다른 언어가 더 적어도(미완성) 더 많아도 같은 개수다.
    for (int i = 1; ko.containsKey(suggestionKey(i, "text")); i++) {
      list.add(new RoutineSuggestionResponse(
        phrases.get(suggestionKey(i, "icon")),
        phrases.get(suggestionKey(i, "text")),
        phrases.get(suggestionKey(i, "example"))));
    }
    return List.copyOf(list);
  }

  public FallbackQuestion fallbackQuestion(SupportGoal goal, AppLocale requested) {
    String name = (goal == SupportGoal.PREPARE_ITEMS ? SupportGoal.PREPARE_ITEMS : SupportGoal.PREPARE_NEW).name();
    Map<String, String> ko = file(AppLocale.KO);
    Map<String, String> phrases = file(resolve(requested));
    List<FallbackQuestion.Option> options = new ArrayList<>();
    for (int i = 1; ko.containsKey(optionKey(name, i, "label")); i++) {
      options.add(new FallbackQuestion.Option(
        phrases.getOrDefault(optionKey(name, i, "emoji"), ""), phrases.get(optionKey(name, i, "label"))));
    }
    return new FallbackQuestion(phrases.get("fallback." + name + ".question"), List.copyOf(options));
  }

  /** 요청 → en → ko 중 한 벌이 완성된 첫 언어. KO 요청은 ko 만 본다. 아무것도 없으면 ko. */
  private AppLocale resolve(AppLocale requested) {
    List<AppLocale> chain = requested == AppLocale.KO ? List.of(AppLocale.KO) : requested.fallbackChain();
    for (AppLocale candidate : chain) {
      if (missingKeys(candidate).isEmpty()) {
        return candidate;
      }
    }
    return AppLocale.KO;
  }

  private List<String> computeMissing(AppLocale locale) {
    TreeSet<String> expected = new TreeSet<>(file(AppLocale.KO).keySet());
    expected.addAll(structuralKeys());
    Map<String, String> target = file(locale);
    return expected.stream().filter(key -> isBlank(target.get(key))).toList();
  }

  /** ko 파일에 반드시 있어야 하는 키 — 파일이 통째로 비었을 때 "키가 없으니 완성"으로 오해하지 않게. */
  private static List<String> structuralKeys() {
    List<String> keys = new ArrayList<>();
    keys.add(suggestionKey(1, "text"));
    for (SupportGoal goal : FALLBACK_GOALS) {
      keys.add("fallback." + goal.name() + ".question");
      for (int i = 1; i <= MIN_FALLBACK_OPTIONS; i++) {
        keys.add(optionKey(goal.name(), i, "label"));
      }
    }
    return keys;
  }

  private Map<String, String> file(AppLocale locale) {
    return files.computeIfAbsent(locale, key -> Map.copyOf(loader.apply(key)));
  }

  private static String suggestionKey(int index, String part) {
    return "suggestion.%02d.%s".formatted(index, part);
  }

  private static String optionKey(String goal, int index, String part) {
    return "fallback.%s.option.%d.%s".formatted(goal, index, part);
  }

  private static boolean isBlank(String value) {
    return value == null || value.isBlank();
  }

  private static Map<String, String> loadFromClasspath(AppLocale locale) {
    String path = RESOURCE.formatted(locale.code());
    try (InputStream in = RoutinePhrases.class.getClassLoader().getResourceAsStream(path)) {
      if (in == null) {
        return Map.of();
      }
      Properties properties = new Properties();
      properties.load(new InputStreamReader(in, StandardCharsets.UTF_8));
      Map<String, String> map = new HashMap<>();
      properties.stringPropertyNames().forEach(key -> map.put(key, properties.getProperty(key)));
      return map;
    } catch (IOException e) {
      // 못 읽은 파일은 빈 파일과 같다 — 대체 순서로 넘어가고, 켜진 언어면 기동 검사가 막는다.
      log.warn("[RoutinePhrases] 문구 파일을 읽지 못했습니다: {}", path, e);
      return Map.of();
    }
  }

  /** AI 가 질문을 못 만들었을 때 쓰는 고정 질문. */
  public record FallbackQuestion(String question, List<Option> options) {

    public record Option(String emoji, String label) {

    }
  }
}
```

- [ ] **Step 7: 추천 카탈로그를 문구 파일 위로 옮긴다**

`server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutineSuggestionCatalog.java` 를 **전체 교체**한다(원본 목록 58개는 이제 `routine-phrases_ko.properties` 에 있다).

```java
package com.chuseok22.elumserver.routine.infrastructure.constant;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import java.util.List;

// 홈 화면 "추천 일과" 카드에 무작위로 노출할 데이터.
// DB에 저장하지 않는 정적 데이터라 엔티티/리포지토리를 두지 않는다.
// 문구의 원본은 i18n/routine-phrases_{언어}.properties 다 (다국어 #521). 항목을 더할 때는 ko 파일에 먼저 더한다.
//
// 항목을 추가할 때 지켜야 할 두 가지 (2026-09-13 서울 ABA연구소 자문):
//  1) 눈으로 "했다/안 했다"를 확인할 수 있는 행동만 넣는다.
//     "마음 다스리기", "진정하기" 같은 내면 조절은 카드로 만들 수 없다 —
//     기분이 나쁘면 폰을 던지지, 속으로 조절하지 않는다.
//  2) 아동·학교 전제를 두지 않는다. 성인 사용자에게 "학교에 가요"가 뜨면 안 된다.
public final class RoutineSuggestionCatalog {

  /** 한국어 목록(기존 이름 유지). 헤더 없는 앱이 받는 목록이다. */
  public static final List<RoutineSuggestionResponse> ALL = RoutinePhrases.standard().suggestions(AppLocale.KO);

  /** 요청 언어의 목록. 그 언어의 문구 파일이 한 벌 갖춰지지 않았으면 en → ko 순서로 대체한다. */
  public static List<RoutineSuggestionResponse> forLocale(AppLocale locale) {
    return RoutinePhrases.standard().suggestions(locale);
  }

  private RoutineSuggestionCatalog() {
  }
}
```

- [ ] **Step 8: 파이프라인 폴백과 서비스의 추천 조회를 연결한다**

**`RoutineAiPipeline.java`** — import 두 줄을 `ErrorCode` import 아래에 더한다.
```java
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
```
그리고 `fallbackQuestionItem` 과 `option` 헬퍼(168-192행)를 바꾼다. 이모지를 옮겨 적지 않도록 앵커로 교체한다. 레포 루트에서 실행한다.
```bash
python3 - <<'PY'
path = "server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/ai/RoutineAiPipeline.java"
s = open(path, encoding="utf-8").read()
start = s.index('  // 목표 하나에 대한 고정 대체 질문. "직접 입력"은 보호자가 자유 텍스트를 입력하도록')
end = s.index("  // AI 호출 자체(RestClient의")
new = '''  // 목표 하나에 대한 고정 대체 질문. "직접 입력"은 보호자가 자유 텍스트를 입력하도록
  // 유도하는 항목이라 추천 답변 목록에 절대 포함하지 않는다(서비스 정책).
  // 문구는 요청 언어의 문구 파일에서 온다(다국어 #521). 헤더 없는 옛 앱은 KO 라 지금과 같다.
  // 요청 스레드에서 불리므로 CurrentLocale 을 읽는다 — 다른 스레드로 옮기면 언어를 인자로 받게 바꾼다.
  private RoutineQuestionResult.QuestionResultItem fallbackQuestionItem(SupportGoal goal) {
    RoutinePhrases.FallbackQuestion fallback = RoutinePhrases.standard().fallbackQuestion(goal, CurrentLocale.get());
    return new RoutineQuestionResult.QuestionResultItem(
      fallback.question(),
      fallback.options().stream()
        .map(option -> new RoutineQuestionResult.QuestionResultItem.OptionResult(option.emoji(), option.label()))
        .toList()
    );
  }

'''
open(path, "w", encoding="utf-8").write(s[:start] + new + s[end:])
PY
grep -n "option(\"" server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/ai/RoutineAiPipeline.java
```
Expected: 마지막 `grep` 은 아무것도 출력하지 않는다(한글 문구 리터럴이 파이프라인에서 사라짐).

**`RoutineService.java`** — import `com.chuseok22.elumserver.common.locale.CurrentLocale;` 를 더하고 `getSuggestions`(820-826행)를 바꾼다.

기존:
```java
  public List<RoutineSuggestionResponse> getSuggestions(int count) {
    if (count < 1 || count > RoutineSuggestionCatalog.ALL.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    List<RoutineSuggestionResponse> pool = new ArrayList<>(RoutineSuggestionCatalog.ALL);
```
바꿈:
```java
  public List<RoutineSuggestionResponse> getSuggestions(int count) {
    // 요청 언어의 목록(다국어 #521). 한 벌이 갖춰지지 않은 언어는 en → ko 로 대체된다. 헤더 없으면 ALL(ko) 그대로다.
    List<RoutineSuggestionResponse> catalog = RoutineSuggestionCatalog.forLocale(CurrentLocale.get());
    if (count < 1 || count > catalog.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    List<RoutineSuggestionResponse> pool = new ArrayList<>(catalog);
```

- [ ] **Step 9: 실행해서 통과를 확인한다**

Run:
```bash
cd server && ./gradlew test \
  --tests '*RoutinePhrasesTest' --tests '*RoutinePhrasesParityTest' --tests '*RoutineAiPipelineFallbackLocaleTest' \
  --tests '*RoutineSuggestionCatalogTest' --tests '*RoutineAiPipelineTest' --tests '*RoutineServiceTest'
```
Expected: **PASS** (기존 `RoutineSuggestionCatalogTest`·`RoutineAiPipelineTest`·`RoutineServiceTest` 의 추천·폴백 검증이 그대로 통과한다)

- [ ] **Step 10: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrases.java \
        server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutineSuggestionCatalog.java \
        server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/ai/RoutineAiPipeline.java \
        server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineService.java \
        server/src/main/resources/i18n/routine-phrases_ko.properties \
        server/src/main/resources/i18n/routine-phrases_en.properties \
        server/src/main/resources/i18n/routine-phrases_ja.properties \
        server/src/main/resources/i18n/routine-phrases_zh.properties \
        server/src/main/resources/i18n/routine-phrases_es.properties \
        server/src/test/resources/i18n/golden/routine-phrases-ko.json \
        server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrasesTest.java \
        server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/constant/RoutinePhrasesParityTest.java \
        server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/ai/RoutineAiPipelineFallbackLocaleTest.java
```

---

## Task 9: 일과 생성 가능 언어 — `ENABLED_CONTENT_LOCALES` 와 `EnabledLocales`

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/systemconfig/core/ConfigGroup.java` (28행 `AD_REWARD("광고 보상"),` 아래)
- Modify: `server/src/main/java/com/chuseok22/elumserver/systemconfig/core/ConfigKey.java` (391-397행 마지막 키 뒤, `;` 앞)
- Modify: `server/src/main/java/com/chuseok22/elumserver/systemconfig/application/service/SystemConfigService.java` (290-291행 `validate` 의 `try {` 직후)
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java` (끝 `;` 앞에 `CONTENT_LOCALE_NOT_READY`)
- Modify: `server/src/main/resources/i18n/messages_ko.properties` (1줄)
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/controller/AdminConfigController.java` (`failureReason` 102-112행, `rejectUnavailableProvider` 114-122행, import)
- Create: `server/src/main/java/com/chuseok22/elumserver/common/locale/EnabledLocales.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/common/locale/EnabledLocalesTest.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/systemconfig/application/service/SystemConfigServiceLocaleTest.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/systemconfig/infrastructure/config/SystemConfigInitializerLocaleTest.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminConfigControllerLocaleTest.java`

**Interfaces:**
- Consumes: `SystemConfigService.getString(ConfigKey)`, `AppLocale`, `RoutinePhrases.incompleteLocales(...)`(Task 8), `CustomException`/`ErrorCode`
- Produces:
  ```java
  @Component public class EnabledLocales {
    public Set<AppLocale> current();                              // ko 는 늘 포함. 잘못된 값은 건너뛴다
    public boolean contains(AppLocale locale);
    public AppLocale resolveContentLocale(AppLocale requested);   // 요청 언어가 켜져 있으면 그것, 아니면 EN 이 켜져 있으면 EN, 아니면 KO
    public static Set<AppLocale> parse(String csv);               // 관대한 읽기
    public static String normalize(String csv);                   // 엄격한 저장 검증 → "ko,en,ja" 순서 고정. 잘못되면 CustomException(SYSTEM_CONFIG_INVALID_VALUE)
  }
  ConfigKey.ENABLED_CONTENT_LOCALES   // STRING, 기본 "ko", ConfigGroup.LANGUAGE
  ErrorCode.CONTENT_LOCALE_NOT_READY  // 400
  ```

- [ ] **Step 1: `EnabledLocales` 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/common/locale/EnabledLocalesTest.java`:

```java
package com.chuseok22.elumserver.common.locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class EnabledLocalesTest {

  private EnabledLocales enabledWith(String configured) {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).thenReturn(configured);
    return new EnabledLocales(config);
  }

  @Test
  @DisplayName("기본값은 ko 하나다 — 배포만으로는 동작이 바뀌지 않는다")
  void default_isKoOnly() {
    assertThat(ConfigKey.ENABLED_CONTENT_LOCALES.getDefaultValue()).isEqualTo("ko");
    assertThat(enabledWith("ko").current()).containsExactly(AppLocale.KO);
  }

  @Test
  @DisplayName("켠 언어를 읽고 ko 는 늘 켜져 있다")
  void parse_enabled() {
    assertThat(enabledWith("en, ja").current()).containsExactly(AppLocale.KO, AppLocale.EN, AppLocale.JA);
    assertThat(enabledWith("ko,en").contains(AppLocale.EN)).isTrue();
    assertThat(enabledWith("en").contains(AppLocale.KO)).isTrue();
    assertThat(enabledWith("ko").contains(AppLocale.JA)).isFalse();
  }

  @ParameterizedTest
  @ValueSource(strings = {"xx", "", " ", ",", "zh-Hans", "ko,xx", "null"})
  @DisplayName("잘못된 값은 터지지 않고 ko 만 켜진 것으로 읽는다 (알 수 없는 코드는 건너뛴다)")
  void parse_brokenValues_neverThrow(String configured) {
    assertThat(enabledWith(configured).current()).contains(AppLocale.KO).doesNotContain(AppLocale.JA);
  }

  @Test
  @DisplayName("알 수 없는 코드가 섞여 있어도 유효한 코드는 살린다")
  void parse_keepsValidTokens() {
    assertThat(enabledWith("ko,xx,en").current()).containsExactly(AppLocale.KO, AppLocale.EN);
  }

  @Test
  @DisplayName("설정을 읽지 못해도 ko 로 동작한다")
  void configFailure_isKoOnly() {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).thenThrow(new IllegalStateException("db down"));

    assertThat(new EnabledLocales(config).current()).containsExactly(AppLocale.KO);
  }

  @Test
  @DisplayName("요청 언어가 켜져 있으면 그 언어, 아니면 en 이 켜져 있을 때 en, 아니면 ko")
  void resolveContentLocale() {
    EnabledLocales withEn = enabledWith("ko,en,ja");
    assertThat(withEn.resolveContentLocale(AppLocale.JA)).isEqualTo(AppLocale.JA);
    assertThat(withEn.resolveContentLocale(AppLocale.ZH)).isEqualTo(AppLocale.EN);
    assertThat(withEn.resolveContentLocale(AppLocale.KO)).isEqualTo(AppLocale.KO);

    EnabledLocales koOnly = enabledWith("ko");
    assertThat(koOnly.resolveContentLocale(AppLocale.JA)).isEqualTo(AppLocale.KO);
    assertThat(koOnly.resolveContentLocale(AppLocale.EN)).isEqualTo(AppLocale.KO);
    assertThat(koOnly.resolveContentLocale(AppLocale.KO)).isEqualTo(AppLocale.KO);

    EnabledLocales jaWithoutEn = enabledWith("ko,ja");
    assertThat(jaWithoutEn.resolveContentLocale(AppLocale.ES)).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("저장 검증: 정규화해서 ko 를 앞에 붙이고 enum 순서로 정렬한다")
  void normalize_ok() {
    assertThat(EnabledLocales.normalize("en")).isEqualTo("ko,en");
    assertThat(EnabledLocales.normalize("EN, ja")).isEqualTo("ko,en,ja");
    assertThat(EnabledLocales.normalize("es,ko,es,ja")).isEqualTo("ko,ja,es");
  }

  @ParameterizedTest
  @ValueSource(strings = {"xx", "", " ", ",", "ko,xx", "zh-Hans", "ko;en"})
  @DisplayName("저장 검증: 모르는 코드나 빈 값은 SYSTEM_CONFIG_INVALID_VALUE")
  void normalize_rejects(String csv) {
    assertThatThrownBy(() -> EnabledLocales.normalize(csv))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
  }
}
```

- [ ] **Step 2: 설정 서비스·초기화·관리자 컨트롤러 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/systemconfig/application/service/SystemConfigServiceLocaleTest.java`:

```java
package com.chuseok22.elumserver.systemconfig.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.SecretProperties;
import com.chuseok22.elumserver.common.infrastructure.security.SecretCipher;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfig;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigHistoryRepository;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigRepository;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SystemConfigServiceLocaleTest {

  @Mock
  private SystemConfigRepository systemConfigRepository;

  @Mock
  private SystemConfigHistoryRepository systemConfigHistoryRepository;

  private SystemConfigService service;

  @BeforeEach
  void setUp() {
    service = new SystemConfigService(
      systemConfigRepository,
      new GeminiProperties("key", null, "yml-text-model", "yml-image-model", 1000),
      new LocalLlmProperties(true, null, "/chat", "key", "yml-local-model", 1000),
      new SecretCipher(new SecretProperties("test-master-key")),
      systemConfigHistoryRepository);
    when(systemConfigRepository.findAll()).thenReturn(List.of());
  }

  @Test
  @DisplayName("저장된 값이 없으면 ko 가 기본값이다")
  void default_isKo() {
    assertThat(service.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).isEqualTo("ko");
  }

  @Test
  @DisplayName("저장하면 정규화한 값이 들어간다 — ko 를 앞에 붙이고 순서를 고정한다")
  void update_savesNormalizedValue() {
    service.update(ConfigKey.ENABLED_CONTENT_LOCALES, "EN, ja");

    ArgumentCaptor<SystemConfig> saved = ArgumentCaptor.forClass(SystemConfig.class);
    verify(systemConfigRepository).save(saved.capture());
    assertThat(saved.getValue().getConfigValue()).isEqualTo("ko,en,ja");
  }

  @Test
  @DisplayName("모르는 코드는 저장하지 않는다")
  void update_rejectsUnknownCode() {
    assertThatThrownBy(() -> service.update(ConfigKey.ENABLED_CONTENT_LOCALES, "xx"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    verify(systemConfigRepository, never()).save(any());
  }

  @Test
  @DisplayName("빈 값도 저장하지 않는다 — 켠 언어가 통째로 사라지지 않게")
  void update_rejectsBlank() {
    assertThatThrownBy(() -> service.update(ConfigKey.ENABLED_CONTENT_LOCALES, "  "))
      .isInstanceOf(CustomException.class);
    verify(systemConfigRepository, never()).save(any());
  }
}
```

`server/src/test/java/com/chuseok22/elumserver/systemconfig/infrastructure/config/SystemConfigInitializerLocaleTest.java`:

```java
package com.chuseok22.elumserver.systemconfig.infrastructure.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfig;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigRepository;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class SystemConfigInitializerLocaleTest {

  @Test
  @DisplayName("처음 뜰 때 일과 생성 가능 언어를 ko 로 시딩한다")
  void seedsEnabledContentLocales() {
    SystemConfigRepository repository = mock(SystemConfigRepository.class);
    SystemConfigService service = mock(SystemConfigService.class);
    when(repository.findByConfigKey(any())).thenReturn(Optional.empty());
    when(service.defaultValueFor(any())).thenAnswer(invocation -> ((ConfigKey) invocation.getArgument(0)).getDefaultValue());

    new SystemConfigInitializer(repository, service).run(null);

    ArgumentCaptor<SystemConfig> saved = ArgumentCaptor.forClass(SystemConfig.class);
    verify(repository, atLeastOnce()).save(saved.capture());
    assertThat(saved.getAllValues())
      .filteredOn(config -> config.getConfigKey() == ConfigKey.ENABLED_CONTENT_LOCALES)
      .singleElement()
      .satisfies(config -> assertThat(config.getConfigValue()).isEqualTo("ko"));
  }

  @Test
  @DisplayName("관리자가 바꾼 값은 다시 뜰 때 덮어쓰지 않는다")
  void doesNotOverwriteExisting() {
    SystemConfigRepository repository = mock(SystemConfigRepository.class);
    SystemConfigService service = mock(SystemConfigService.class);
    SystemConfig existing = new SystemConfig();
    existing.setConfigKey(ConfigKey.ENABLED_CONTENT_LOCALES);
    existing.setConfigValue("ko,en");
    when(repository.findByConfigKey(any())).thenReturn(Optional.of(existing));

    new SystemConfigInitializer(repository, service).run(null);

    verify(repository, org.mockito.Mockito.never()).save(any());
    assertThat(existing.getConfigValue()).isEqualTo("ko,en");
  }
}
```

`server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminConfigControllerLocaleTest.java`:

```java
package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.security.Principal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/** 일과 생성 가능 언어 저장이 관리자 화면에서 어떻게 거절·안내되는지 본다 (다국어 #521). */
@ExtendWith(MockitoExtension.class)
class AdminConfigControllerLocaleTest {

  @Mock private SystemConfigService systemConfigService;
  @Mock private ImageClientRouter imageClientRouter;
  @Mock private TextClientRouter textClientRouter;

  private AdminConfigController controller;
  private final Principal admin = () -> "admin";

  @BeforeEach
  void setUp() {
    controller = new AdminConfigController(systemConfigService, imageClientRouter, textClientRouter);
  }

  @Test
  @DisplayName("ko 만 켜는 저장은 통과해 설정 서비스로 간다 — ko 문구 한 벌은 늘 완성이다")
  void koOnly_passesThrough() {
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko", null, admin, flash);

    verify(systemConfigService).update(eq(ConfigKey.ENABLED_CONTENT_LOCALES), eq("ko"), any(), any());
    assertThat(flash.getFlashAttributes()).containsKey("message").doesNotContainKey("errorMessage");
  }

  @Test
  @DisplayName("모르는 언어 코드는 저장 전에 막고 E-CFG-001 로 알린다")
  void unknownCode_isRejected() {
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko,xx", null, admin, flash);

    verify(systemConfigService, never()).update(any(), any(), any(), any());
    assertThat((String) flash.getFlashAttributes().get("errorMessage")).contains("E-CFG-001");
  }

  @Test
  @DisplayName("서버 문구 파일이 비어 있는 언어는 켤 수 없다고 E-CFG-004 로 알린다")
  void notReady_isExplained() {
    doThrow(new CustomException(ErrorCode.CONTENT_LOCALE_NOT_READY))
      .when(systemConfigService).update(any(), any(), any(), any());
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko", null, admin, flash);

    assertThat((String) flash.getFlashAttributes().get("errorMessage")).contains("E-CFG-004").contains("문구 파일");
  }
}
```

- [ ] **Step 3: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests '*EnabledLocalesTest' --tests '*SystemConfigServiceLocaleTest' --tests '*SystemConfigInitializerLocaleTest' --tests '*AdminConfigControllerLocaleTest'`
Expected: **FAIL** (컴파일 오류 — `ENABLED_CONTENT_LOCALES`, `EnabledLocales`, `CONTENT_LOCALE_NOT_READY` 없음)

- [ ] **Step 4: 설정 키·그룹·오류 코드를 더한다**

**`ConfigGroup.java`** — `AD_REWARD("광고 보상"),` 아래에 더한다.
```java
  // 일과를 만들 수 있는 언어 (다국어 #521).
  LANGUAGE("언어"),
```

**`ConfigKey.java`** — 마지막 키(`AD_REWARD_ALLOWED_AD_UNITS(...),`) 뒤, 단독 `;` 앞에 더한다.
```java

  // --- 언어 (다국어 #521) ---
  //
  // 일과를 만들 수 있는 언어 목록. 앱에 번역이 들어 있어도 이 목록에 없는 언어의 휴대폰에서 만든 일과는 en(켜져 있을 때)
  // 아니면 ko 로 처리한다. 새 언어를 열 때 앱 업데이트 없이 여기서 켠다. 기본값 ko 는 배포만으로 동작이 바뀌지 않는다.
  ENABLED_CONTENT_LOCALES(
    ConfigGroup.LANGUAGE, "일과 생성 가능 언어",
    "쉼표로 나눈 언어 코드(ko,en,ja,zh,es). 켠 언어의 휴대폰에서 만든 일과는 그 언어로 만들어진다. "
      + "꺼진 언어는 en 이 켜져 있으면 en, 아니면 ko 로 처리한다. ko 는 늘 켜져 있다. "
      + "켜기 전에 확인한다: 앱 번역 파일 완성, 그 언어 약관 게시, AI 프롬프트 행 검증, 서버 문구 파일(폴백 질문·추천) 완성. "
      + "서버 문구 파일이 비어 있으면 저장되지 않는다",
    ConfigValueType.STRING, List.of(), "ko"
  ),
```

**`ErrorCode.java`** — 마지막 상수 뒤(`;` 앞)에 더한다.
```java

  // 일과 생성 가능 언어 (다국어 #521). 서버 문구 파일(폴백 질문·추천)이 비어 있는 언어는 켤 수 없다 —
  // 켜 두면 다음 기동의 시작 검사가 서버를 세우지 않는다. 관리자 화면은 E-CFG-004 를 함께 보여준다.
  CONTENT_LOCALE_NOT_READY(HttpStatus.BAD_REQUEST),
```

**`messages_ko.properties`** — 에러 코드 구간 끝(첫 `# --- 요청 검증` 주석 앞)에 한 줄을 더한다. 파일 끝에 붙여도 키 이름이 겹치지 않아 동작은 같다.
```bash
cat >> server/src/main/resources/i18n/messages_ko.properties <<'EOF'

# --- 다국어 #521 에서 더한 에러 코드 ---
CONTENT_LOCALE_NOT_READY=이 언어는 아직 켤 수 없어요. 서버 문구 파일이 비어 있어요.
EOF
```

- [ ] **Step 5: `EnabledLocales` 를 구현한다**

`server/src/main/java/com/chuseok22/elumserver/common/locale/EnabledLocales.java`:

```java
package com.chuseok22.elumserver.common.locale;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.Collections;
import java.util.EnumSet;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 일과를 만들 수 있는 언어 (다국어 #521, 시스템 설정 {@code ENABLED_CONTENT_LOCALES}).
 *
 * <p>ko 는 늘 켜져 있다 — 설정이 깨져도 일과 생성이 멈추지 않는다. 읽기는 관대하고(알 수 없는 코드는 건너뛴다)
 * 저장은 엄격하다({@link #normalize}).
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class EnabledLocales {

  private final SystemConfigService systemConfigService;

  /** 켜진 언어(ko 포함, enum 순서). 설정을 읽지 못하면 ko 만. */
  public Set<AppLocale> current() {
    try {
      return parse(systemConfigService.getString(ConfigKey.ENABLED_CONTENT_LOCALES));
    } catch (RuntimeException e) {
      log.warn("[EnabledLocales] 설정을 읽지 못해 ko 만 켜진 것으로 봅니다", e);
      return Collections.unmodifiableSet(EnumSet.of(AppLocale.KO));
    }
  }

  public boolean contains(AppLocale locale) {
    return current().contains(locale);
  }

  /**
   * 일과의 콘텐츠 언어. 요청 언어가 켜져 있으면 그것, 아니면 EN 이 켜져 있을 때 EN, 아니면 KO.
   * 검증되지 않은 언어로 AI 가 글을 쓰는 일을 막는다.
   */
  public AppLocale resolveContentLocale(AppLocale requested) {
    Set<AppLocale> enabled = current();
    if (enabled.contains(requested)) {
      return requested;
    }
    return enabled.contains(AppLocale.EN) ? AppLocale.EN : AppLocale.KO;
  }

  /** 관대한 읽기. 알 수 없는 코드와 빈 토큰은 건너뛰고, ko 는 늘 넣는다. */
  public static Set<AppLocale> parse(String csv) {
    Set<AppLocale> result = EnumSet.of(AppLocale.KO);
    if (csv != null) {
      for (String token : csv.split(",")) {
        String code = token.trim().toLowerCase(Locale.ROOT);
        if (code.isEmpty()) {
          continue;
        }
        try {
          result.add(AppLocale.fromCode(code));
        } catch (IllegalArgumentException e) {
          log.warn("[EnabledLocales] 알 수 없는 언어 코드는 건너뜁니다: {}", token);
        }
      }
    }
    return Collections.unmodifiableSet(result);
  }

  /**
   * 엄격한 저장 검증. 알 수 없는 코드나 빈 값이면 던지고, 통과하면 ko 를 앞에 붙여 enum 순서로 고정한 CSV 를 준다.
   *
   * @throws CustomException {@link ErrorCode#SYSTEM_CONFIG_INVALID_VALUE}
   */
  public static String normalize(String csv) {
    Set<AppLocale> result = EnumSet.of(AppLocale.KO);
    boolean any = false;
    if (csv != null) {
      for (String token : csv.split(",")) {
        String code = token.trim().toLowerCase(Locale.ROOT);
        if (code.isEmpty()) {
          continue;
        }
        try {
          result.add(AppLocale.fromCode(code));
          any = true;
        } catch (IllegalArgumentException e) {
          throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
        }
      }
    }
    if (!any) {
      throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    }
    return result.stream().map(AppLocale::code).collect(Collectors.joining(","));
  }
}
```

- [ ] **Step 6: 저장 검증과 관리자 컨트롤러를 연결한다**

**`SystemConfigService.java`** — import `com.chuseok22.elumserver.common.locale.EnabledLocales;` 를 더하고 `validate` 의 `try {`(291행) 바로 뒤에 더한다.
```java
      if (key == ConfigKey.ENABLED_CONTENT_LOCALES) {
        // 모르는 코드는 저장하지 않는다. ko 는 늘 켜 두므로 앞에 붙여 정규화한다 (다국어 #521).
        return EnabledLocales.normalize(value);
      }
```

**`AdminConfigController.java`** — import 를 더한다.
```java
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.EnabledLocales;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import java.util.Set;
```
`failureReason` 의 switch 에 케이스를 더한다(`default` 앞).
```java
      case CONTENT_LOCALE_NOT_READY ->
        " 저장 실패: 그 언어의 서버 문구 파일(폴백 질문·추천)이 비어 있어 켤 수 없습니다. (E-CFG-004)";
```
`rejectUnavailableProvider` 의 switch 에 케이스를 더하고(`default` 앞) 메서드를 하나 더한다.
```java
      case ENABLED_CONTENT_LOCALES -> rejectIncompleteLocales(value);
```
```java
  /**
   * 서버 문구 파일(폴백 질문·추천)이 비어 있는 언어는 켤 수 없다 (다국어 #521).
   * 켜 두면 다음 기동의 시작 검사(RoutinePhrasesStartupGuard)가 서버를 세우지 않으므로 화면에서 먼저 막는다.
   * 모르는 코드는 normalize 가 SYSTEM_CONFIG_INVALID_VALUE 로 거절한다.
   */
  private void rejectIncompleteLocales(String value) {
    Set<AppLocale> requested = EnabledLocales.parse(EnabledLocales.normalize(value));
    if (!RoutinePhrases.standard().incompleteLocales(requested).isEmpty()) {
      throw new CustomException(ErrorCode.CONTENT_LOCALE_NOT_READY);
    }
  }
```

- [ ] **Step 7: 실행해서 통과를 확인한다**

Run:
```bash
cd server && ./gradlew test \
  --tests '*EnabledLocalesTest' --tests '*SystemConfigServiceLocaleTest' --tests '*SystemConfigInitializerLocaleTest' \
  --tests '*AdminConfigControllerLocaleTest' --tests '*SystemConfigServiceTest' --tests '*SystemConfigServiceHistoryTest' \
  --tests '*ErrorMessageParityTest' --tests '*BeanConstructorAmbiguityTest'
```
Expected: **PASS**. 컴파일이 `ConfigGroup` 의 `switch` 누락을 지적하면 그 `switch` 에 `LANGUAGE` 를 더한다.

- [ ] **Step 8: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/locale/EnabledLocales.java \
        server/src/main/java/com/chuseok22/elumserver/systemconfig/core/ConfigGroup.java \
        server/src/main/java/com/chuseok22/elumserver/systemconfig/core/ConfigKey.java \
        server/src/main/java/com/chuseok22/elumserver/systemconfig/application/service/SystemConfigService.java \
        server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java \
        server/src/main/java/com/chuseok22/elumserver/admin/application/controller/AdminConfigController.java \
        server/src/main/resources/i18n/messages_ko.properties \
        server/src/test/java/com/chuseok22/elumserver/common/locale/EnabledLocalesTest.java \
        server/src/test/java/com/chuseok22/elumserver/systemconfig/application/service/SystemConfigServiceLocaleTest.java \
        server/src/test/java/com/chuseok22/elumserver/systemconfig/infrastructure/config/SystemConfigInitializerLocaleTest.java \
        server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminConfigControllerLocaleTest.java
```

---

## Task 10: 기동 검사 — 켜진 언어의 문구 한 벌이 비면 서버가 뜨지 않는다

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/guard/RoutinePhrasesStartupGuard.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/guard/RoutinePhrasesStartupGuardTest.java`

**Interfaces:**
- Consumes: `EnabledLocales.current()`(Task 9), `RoutinePhrases.incompleteLocales(...)`(Task 8)
- Produces: `ApplicationRunner` — 켜진 언어(+ko) 중 하나라도 한 벌이 미완성이면 `IllegalStateException` 으로 기동을 실패시킨다.

기존 시작 작업(`SystemConfigInitializer`)이 `ApplicationRunner` 이므로 같은 스타일을 따른다. 이 검사는 DB 시딩 순서에 의존하지 않는다 — 시딩 전이면 `getString` 이 기본값 `ko` 를 돌려준다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/guard/RoutinePhrasesStartupGuardTest.java`:

```java
package com.chuseok22.elumserver.routine.infrastructure.guard;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.EnabledLocales;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RoutinePhrasesStartupGuardTest {

  private static Map<String, String> full(String tag) {
    Map<String, String> map = new HashMap<>();
    map.put("suggestion.01.icon", "I");
    map.put("suggestion.01.text", tag + "-text");
    map.put("suggestion.01.example", tag + "-example");
    for (String goal : List.of("PREPARE_ITEMS", "PREPARE_NEW")) {
      map.put("fallback." + goal + ".question", tag + "-q");
      for (int i = 1; i <= 3; i++) {
        map.put("fallback." + goal + ".option." + i + ".emoji", "E");
        map.put("fallback." + goal + ".option." + i + ".label", tag + "-o" + i);
      }
    }
    return map;
  }

  private RoutinePhrasesStartupGuard guard(String enabledCsv, Map<AppLocale, Map<String, String>> files) {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).thenReturn(enabledCsv);
    return new RoutinePhrasesStartupGuard(
      new EnabledLocales(config), new RoutinePhrases(locale -> files.getOrDefault(locale, Map.of())));
  }

  @Test
  @DisplayName("ko 만 켜져 있으면 다른 언어 파일이 비어 있어도 뜬다 — 지금의 배포 상태")
  void koOnly_startsEvenWithEmptyOtherFiles() {
    assertThatCode(() -> guard("ko", Map.of(AppLocale.KO, full("ko"))).verify()).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("켜진 언어의 문구 한 벌이 비어 있으면 서버가 뜨지 않는다 — 빠진 언어와 키를 알린다")
  void enabledButEmpty_blocksStartup() {
    var guard = guard("ko,ja", Map.of(AppLocale.KO, full("ko")));

    assertThatThrownBy(guard::verify)
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("ja")
      .hasMessageContaining("fallback.PREPARE_ITEMS");
  }

  @Test
  @DisplayName("켜진 언어가 키 하나만 비어도 서버가 뜨지 않는다")
  void enabledButOneKeyMissing_blocksStartup() {
    Map<String, String> en = full("en");
    en.put("fallback.PREPARE_NEW.option.3.label", "");
    var guard = guard("ko,en", Map.of(AppLocale.KO, full("ko"), AppLocale.EN, en));

    assertThatThrownBy(guard::verify)
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("fallback.PREPARE_NEW.option.3.label");
  }

  @Test
  @DisplayName("켜진 언어가 한 벌을 모두 채웠으면 뜬다")
  void enabledAndComplete_starts() {
    assertThatCode(() -> guard("ko,en", Map.of(AppLocale.KO, full("ko"), AppLocale.EN, full("en"))).verify())
      .doesNotThrowAnyException();
  }

  @Test
  @DisplayName("ko 파일 자체가 비면 아무 언어도 안 켜도 서버가 뜨지 않는다 — 모든 대체 순서의 끝이다")
  void koEmpty_blocksStartup() {
    assertThatThrownBy(() -> guard("ko", Map.of()).verify()).isInstanceOf(IllegalStateException.class);
  }

  @Test
  @DisplayName("ApplicationRunner 로 등록돼 기동 때 실제로 검사한다")
  void isAnApplicationRunner() {
    assertThat(org.springframework.boot.ApplicationRunner.class).isAssignableFrom(RoutinePhrasesStartupGuard.class);
  }

  @Test
  @DisplayName("실제 문구 파일과 기본 설정(ko)으로는 검사를 통과한다")
  void realFiles_defaultConfig_passes() {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).thenReturn("ko");

    assertThatCode(() -> new RoutinePhrasesStartupGuard(new EnabledLocales(config)).verify()).doesNotThrowAnyException();
  }
}
```

- [ ] **Step 2: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests '*RoutinePhrasesStartupGuardTest'`
Expected: **FAIL** (컴파일 오류 — `RoutinePhrasesStartupGuard` 없음)

- [ ] **Step 3: 구현**

`server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/guard/RoutinePhrasesStartupGuard.java`:

```java
package com.chuseok22.elumserver.routine.infrastructure.guard;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.EnabledLocales;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * 켜진 언어의 서버 문구 한 벌(폴백 질문·추천 일과)이 비어 있으면 서버를 띄우지 않는다 (다국어 #521).
 *
 * <p>AI 가 실패하는 바로 그 순간에 보여줄 문구도 없는 일을 막는다. 검사 대상은 ko(모든 대체 순서의 끝)와
 * 일과 생성이 켜진 언어다. 기본 설정(ko 만)에서는 다른 언어 파일이 비어 있어도 뜬다.
 *
 * <p>DB 시딩 순서에 의존하지 않는다 — 설정 행이 아직 없으면 {@code getString} 이 기본값 ko 를 돌려준다.
 * 관리자 화면은 한 벌이 비어 있는 언어를 아예 켜지 못하게 막는다(AdminConfigController).
 */
@Slf4j
@Component
public class RoutinePhrasesStartupGuard implements ApplicationRunner {

  private static final int MAX_KEYS_IN_MESSAGE = 5;

  private final EnabledLocales enabledLocales;
  private final RoutinePhrases phrases;

  @Autowired
  public RoutinePhrasesStartupGuard(EnabledLocales enabledLocales) {
    this(enabledLocales, RoutinePhrases.standard());
  }

  RoutinePhrasesStartupGuard(EnabledLocales enabledLocales, RoutinePhrases phrases) {
    this.enabledLocales = enabledLocales;
    this.phrases = phrases;
  }

  @Override
  public void run(ApplicationArguments args) {
    verify();
  }

  void verify() {
    Set<AppLocale> targets = new LinkedHashSet<>();
    targets.add(AppLocale.KO);
    targets.addAll(enabledLocales.current());

    Map<AppLocale, List<String>> incomplete = phrases.incompleteLocales(targets);
    if (incomplete.isEmpty()) {
      log.info("[RoutinePhrasesStartupGuard] 서버 문구 확인 완료: {}", targets);
      return;
    }
    StringBuilder message = new StringBuilder("서버 문구 파일(i18n/routine-phrases_*.properties)이 비어 있어 기동을 멈춥니다.");
    incomplete.forEach((locale, keys) -> message
      .append(" [").append(locale.code()).append(": ")
      .append(keys.stream().limit(MAX_KEYS_IN_MESSAGE).toList())
      .append(keys.size() > MAX_KEYS_IN_MESSAGE ? " 외 " + (keys.size() - MAX_KEYS_IN_MESSAGE) + "개" : "")
      .append("]"));
    message.append(" 파일을 채우거나 시스템 설정 ENABLED_CONTENT_LOCALES 에서 그 언어를 끈다.");
    throw new IllegalStateException(message.toString());
  }
}
```

- [ ] **Step 4: 실행해서 통과를 확인한다**

Run: `cd server && ./gradlew test --tests '*RoutinePhrasesStartupGuardTest' --tests '*BeanConstructorAmbiguityTest'`
Expected: **PASS** (생성자가 둘이라도 한쪽에 `@Autowired` 가 있어 모호성 검사를 통과한다)

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/guard/RoutinePhrasesStartupGuard.java \
        server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/guard/RoutinePhrasesStartupGuardTest.java
```

---

## Task 11: 일과 언어 — V33 · `Routine.language` · `RoutineResponse.language`

**Files:**
- Create: `server/src/main/resources/db/migration/V33__add_routine_language.sql`
- Create: `server/src/main/java/com/chuseok22/elumserver/common/locale/AppLocaleConverter.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/entity/Routine.java` (import, 98행 `displayOrder` 아래)
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/application/dto/response/RoutineResponse.java` (record 끝 컴포넌트, `with*` 5곳, `from`)
- Modify: `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineService.java` (필드 111행 아래, `create` 218행, `duplicate` 341행)
- Modify (테스트): `RoutineControllerAuthorTest`(34-35행), `RoutineControllerSourceTextTest`(54-55행), `RoutineAuthorResolverTest`(38-39행)의 `new RoutineResponse(...)` 끝에 `"ko"` 추가
- Modify (테스트): `RoutineServiceTest`, `RoutineServiceCreditTest` — `EnabledLocales` 목 추가
- Test: `server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/entity/RoutineLanguageMigrationTest.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/common/locale/AppLocaleConverterTest.java`
- Test: `RoutineResponseTest`(기존 파일에 테스트 추가), `RoutineServiceTest`(기존 파일에 테스트 추가)

**Interfaces:**
- Consumes: `AppLocale`, `CurrentLocale`, `EnabledLocales.resolveContentLocale(...)`(Task 9)
- Produces:
  ```java
  // Routine
  private AppLocale language = AppLocale.KO;                 // @Convert(AppLocaleConverter), column "language"
  // RoutineResponse (record 의 마지막 컴포넌트)
  String language                                            // "ko" 같은 코드. 모든 with*/forCaller 가 보존
  ```
  일과 생성 요청 DTO 는 바꾸지 않는다(C5).

- [ ] **Step 1: 마이그레이션·엔티티 계약 테스트를 쓴다**

`server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/entity/RoutineLanguageMigrationTest.java`:

```java
package com.chuseok22.elumserver.routine.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.AppLocaleConverter;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import java.io.IOException;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * V33 이 "추가만 한다"는 약속을 지키고 엔티티와 같은지 글로 확인한다 (다국어 #521, V25~V31 과 같은 약속).
 *
 * <p>운영은 ddl-auto: validate 라 컬럼 이름·길이가 어긋나면 서버가 뜨지 않는다. 옛 서버 이미지로 되돌려도 이 스키마 위에서
 * 옛 코드가 돌아야 하므로 NOT NULL 에는 DEFAULT 가 있어야 한다. DB 를 띄우지 않는다 — 실제 적용은 운영 사본 리허설에서 본다.
 */
class RoutineLanguageMigrationTest {

  private static final Path V33 = Path.of("src/main/resources/db/migration/V33__add_routine_language.sql");

  private static String normalizedSql() throws IOException {
    return Files.readAllLines(V33).stream()
      .map(line -> line.contains("--") ? line.substring(0, line.indexOf("--")) : line)
      .collect(Collectors.joining(" "))
      .replaceAll("\\s+", " ")
      .toLowerCase();
  }

  @Test
  @DisplayName("V33 은 language 를 DEFAULT 'ko' 와 함께 더하기만 한다 — 기존 일과는 모두 한국어다")
  void addsColumnWithDefaultOnly() throws IOException {
    String sql = normalizedSql();

    assertThat(sql).doesNotContain("drop ").doesNotContain("rename ").doesNotContain("update routine")
      .doesNotContain("set not null");
    assertThat(sql).contains(
      "alter table routine add column if not exists language varchar(8) not null default 'ko';");
  }

  @Test
  @DisplayName("V33 은 엔티티와 같다 — 컬럼 이름·길이·NOT NULL·변환기")
  void matchesEntity() throws Exception {
    Field field = Routine.class.getDeclaredField("language");
    Column column = field.getAnnotation(Column.class);

    assertThat(column.name()).isEqualTo("language");
    assertThat(column.length()).isEqualTo(8);
    assertThat(column.nullable()).isFalse();
    assertThat(field.getAnnotation(Convert.class).converter()).isEqualTo(AppLocaleConverter.class);
  }

  @Test
  @DisplayName("새 Routine 의 기본 언어는 ko 다 — 언어를 모르는 생성 경로(복제·테스트)도 지금과 같다")
  void newRoutine_defaultsToKo() {
    assertThat(new Routine().getLanguage()).isEqualTo(AppLocale.KO);
  }
}
```

`server/src/test/java/com/chuseok22/elumserver/common/locale/AppLocaleConverterTest.java`:

```java
package com.chuseok22.elumserver.common.locale;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class AppLocaleConverterTest {

  private final AppLocaleConverter converter = new AppLocaleConverter();

  @Test
  @DisplayName("DB 에는 소문자 코드로 저장하고 그대로 읽는다")
  void roundTrip() {
    for (AppLocale locale : AppLocale.values()) {
      assertThat(converter.convertToDatabaseColumn(locale)).isEqualTo(locale.code());
      assertThat(converter.convertToEntityAttribute(locale.code())).isEqualTo(locale);
    }
  }

  @Test
  @DisplayName("손상된 값·빈 값으로 일과 조회가 죽지 않는다 — ko 로 읽는다")
  void brokenValues_readAsKo() {
    assertThat(converter.convertToEntityAttribute(null)).isEqualTo(AppLocale.KO);
    assertThat(converter.convertToEntityAttribute("")).isEqualTo(AppLocale.KO);
    assertThat(converter.convertToEntityAttribute("xx")).isEqualTo(AppLocale.KO);
    assertThat(converter.convertToEntityAttribute(" EN ")).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("null 은 null 로 저장한다 — NOT NULL 제약이 잡는다")
  void nullWrite() {
    assertThat(converter.convertToDatabaseColumn(null)).isNull();
  }
}
```

- [ ] **Step 2: 응답·서비스 테스트를 쓴다**

**`RoutineResponseTest`** — 기존 파일의 마지막 `}` 앞에 추가한다(import 에 `com.chuseok22.elumserver.common.locale.AppLocale`, `com.chuseok22.elumserver.member.application.service.Caller` 가 필요하다).

```java

  @Test
  @DisplayName("응답은 일과의 언어를 코드 문자열로 싣는다 — 기존 일과(기본값)는 ko")
  void from_carriesLanguageCode() {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("병원 다녀오기");
    routine.setRawInputText("raw");
    routine.setSanitizedInputText("sanitized");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setSteps(List.of());

    assertThat(RoutineResponse.from(routine).language()).isEqualTo("ko");

    routine.setLanguage(AppLocale.JA);
    assertThat(RoutineResponse.from(routine).language()).isEqualTo("ja");
  }

  @Test
  @DisplayName("언어는 응답을 가공하는 어떤 메서드를 거쳐도 그대로다")
  void language_survivesEveryTransformation() {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setTitle("제목");
    routine.setRawInputText("raw");
    routine.setSanitizedInputText("sanitized");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setCreatedBy("member-1");
    routine.setSteps(List.of());
    routine.setLanguage(AppLocale.ES);
    RoutineResponse base = RoutineResponse.from(routine);

    assertThat(base.withCredit(new RoutineResponse.CreditUsage(1, 1, 1, 1)).language()).isEqualTo("es");
    assertThat(base.withImageSkippedReason("AI_CREDIT_INSUFFICIENT").language()).isEqualTo("es");
    assertThat(base.withoutSourceText().language()).isEqualTo("es");
    assertThat(base.withCreatorName("엄마").language()).isEqualTo("es");
    assertThat(base.forCaller(Caller.guardian("member-1")).language()).isEqualTo("es");
    assertThat(base.forCaller(Caller.guardian("someone-else")).language()).isEqualTo("es");
  }
```

**`RoutineServiceTest`** — 기존 파일에 추가한다. (a) 필드 `@Mock private EnabledLocales enabledLocales;` 를 `pictogramPicker` 목 아래에 더하고, (b) 기존 `@BeforeEach creditDisabledByDefault` 아래에 새 `@BeforeEach` 를 더하고, (c) 테스트 두 개를 마지막 `}` 앞에 더한다. import: `com.chuseok22.elumserver.common.locale.AppLocale`, `CurrentLocale`, `EnabledLocales`, `org.mockito.ArgumentCaptor`(이미 있음).

```java
  @BeforeEach
  void contentLocaleDefaultsToKo() {
    // 헤더가 없는 옛 앱: 요청 언어 KO → 일과 언어 KO (다국어 #521)
    lenient().when(enabledLocales.resolveContentLocale(any())).thenReturn(AppLocale.KO);
  }
```
```java

  @Test
  @DisplayName("헤더가 없으면 일과 언어는 ko 다 — 이미 배포된 앱")
  void create_headerless_languageIsKo() {
    Routine saved = createAndCaptureSavedRoutine();

    assertThat(saved.getLanguage()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("일과 언어는 요청 언어를 켜진 언어 목록에 비춰 정한다 — 일본어 요청이 en 으로 처리되는 설정")
  void create_languageFollowsEnabledLocales() {
    when(enabledLocales.resolveContentLocale(AppLocale.JA)).thenReturn(AppLocale.EN);

    Routine saved = CurrentLocale.callAs(AppLocale.JA, this::createAndCaptureSavedRoutine);

    assertThat(saved.getLanguage()).isEqualTo(AppLocale.EN);
    verify(enabledLocales).resolveContentLocale(AppLocale.JA);
  }

  @Test
  @DisplayName("복제한 일과는 원본의 언어를 그대로 가진다 — 카드 글이 원본 그대로이므로")
  void duplicate_keepsOriginLanguage() {
    Routine origin = confirmedRoutine(profileWithStars(0), 1);
    origin.setTitle("Go to the hospital");
    origin.setLanguage(AppLocale.EN);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(origin));
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    when(routineRepository.save(saved.capture())).thenAnswer(i -> i.getArgument(0));

    routineService.duplicate(GUARDIAN, "routine-1");

    assertThat(saved.getValue().getLanguage()).isEqualTo(AppLocale.EN);
  }

  /** 일과 생성을 한 번 돌리고 저장기에 넘어간 Routine 을 돌려준다. */
  private Routine createAndCaptureSavedRoutine() {
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("하늘이");
    profile.setSupportGoals(Set.of());
    profile.setCharacter(CharacterType.LULU);
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), eq(CharacterType.LULU), any(), any()))
      .thenReturn(new RoutineAiPipeline.RoutineGenerationResult(
        "병원 다녀오기",
        List.of(new RoutineAiPipeline.GeneratedStep(1, "신발 신어요", "신발 신기", "data/routine-images/batch-1/1.png")),
        "batch-1"));
    ArgumentCaptor<Routine> routine = ArgumentCaptor.forClass(Routine.class);
    when(routineCreationWriter.save(any(), any(), routine.capture(), any(), anyInt()))
      .thenAnswer(invocation -> new RoutineCreationWriter.SavedRoutine(invocation.getArgument(2), null));

    routineService.create(GUARDIAN, new RoutineCreateRequest("내일 병원 가기", null, null, null, null), null);

    return routine.getValue();
  }
```

**`RoutineServiceCreditTest`** — 필드 `@Mock private EnabledLocales enabledLocales;` 를 다른 `@Mock` 들과 함께 더하고 새 `@BeforeEach` 를 더한다(import 는 위와 같고 `org.junit.jupiter.api.BeforeEach`, `static org.mockito.Mockito.lenient` 가 없으면 더한다).
```java
  @BeforeEach
  void contentLocaleDefaultsToKo() {
    lenient().when(enabledLocales.resolveContentLocale(any())).thenReturn(AppLocale.KO);
  }
```

- [ ] **Step 3: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests '*RoutineLanguageMigrationTest' --tests '*AppLocaleConverterTest' --tests '*RoutineResponseTest' --tests '*RoutineServiceTest'`
Expected: **FAIL** (컴파일 오류 — `Routine.language`, `AppLocaleConverter`, `RoutineResponse.language()` 없음)

- [ ] **Step 4: 마이그레이션·변환기·엔티티를 만든다**

`server/src/main/resources/db/migration/V33__add_routine_language.sql`:

```sql
-- 일과의 콘텐츠 언어 (다국어 #521, 계획 2).
--
-- 일과를 만든 요청의 화면 언어를 켜진 언어 목록(system_config ENABLED_CONTENT_LOCALES)에 비춰 정해 일과에 저장한다.
-- 보호자가 고르지 않는다. 카드 글과 음성이 이 값을 따른다.
-- 기존 일과는 모두 한국어로 만들어졌으므로 DEFAULT 'ko' 로 채운다.
--
-- 추가만 한다 (V25 원칙). 옛 서버 이미지는 이 컬럼을 모르고 routine 을 INSERT 하므로 NOT NULL 에는 반드시 DEFAULT 가 있어야 한다.
-- 운영은 ddl-auto: validate 라 이 마이그레이션이 없으면 Routine 엔티티가 language 를 읽다가 서버가 뜨지 않는다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE routine ADD COLUMN IF NOT EXISTS language VARCHAR(8) NOT NULL DEFAULT 'ko';
```

`server/src/main/java/com/chuseok22/elumserver/common/locale/AppLocaleConverter.java`:

```java
package com.chuseok22.elumserver.common.locale;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import lombok.extern.slf4j.Slf4j;

/**
 * {@link AppLocale} 을 DB 에 소문자 코드({@code ko})로 저장한다 (다국어 #521).
 *
 * <p>{@code @Enumerated(STRING)} 은 상수 이름({@code KO})을 쓰므로 마이그레이션의 {@code DEFAULT 'ko'} 와 어긋난다.
 * 읽을 때 손상된 값은 ko 로 읽는다 — 한 행 때문에 일과 목록 전체가 죽으면 안 된다.
 */
@Slf4j
@Converter
public class AppLocaleConverter implements AttributeConverter<AppLocale, String> {

  @Override
  public String convertToDatabaseColumn(AppLocale attribute) {
    return attribute == null ? null : attribute.code();
  }

  @Override
  public AppLocale convertToEntityAttribute(String dbData) {
    if (dbData == null || dbData.isBlank()) {
      return AppLocale.KO;
    }
    try {
      return AppLocale.fromCode(dbData);
    } catch (IllegalArgumentException e) {
      log.warn("[AppLocaleConverter] 알 수 없는 언어 코드를 ko 로 읽습니다: {}", dbData);
      return AppLocale.KO;
    }
  }
}
```

**`Routine.java`** — import 를 더한다.
```java
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.AppLocaleConverter;
import jakarta.persistence.Convert;
```
`displayOrder` 필드(98행) 아래에 더한다.
```java

  /**
   * 일과의 콘텐츠 언어 (다국어 #521). 카드 글과 음성이 이 언어다.
   *
   * <p>일과를 만든 요청의 화면 언어를 켜진 언어 목록(ENABLED_CONTENT_LOCALES)에 비춰 정한다. 보호자가 고르지 않고
   * 만든 뒤에는 바꾸지 않는다. 기존 일과는 V33 이 ko 로 채웠다.
   *
   * <p>columnDefinition 은 로컬(ddl-auto: update)에서 행이 있는 표에 NOT NULL 컬럼을 더할 때 DEFAULT 가 필요해서 둔다
   * (displayOrder 와 같은 이유).
   */
  @Convert(converter = AppLocaleConverter.class)
  @Column(name = "language", nullable = false, length = 8, columnDefinition = "varchar(8) not null default 'ko'")
  private AppLocale language = AppLocale.KO;
```

- [ ] **Step 5: `RoutineResponse` 에 언어를 싣는다**

`RoutineResponse.java`:

1. record 의 마지막 컴포넌트 `String profileId` 뒤에 쉼표와 함께 더한다.
```java
  String profileId,

  @Schema(description = "일과의 콘텐츠 언어 코드(ko·en·ja·zh·es). 카드 글과 음성이 이 언어다. 기존 일과는 ko", example = "ko")
  String language
) {
```
(기존 `String profileId\n) {` 를 위로 바꾼다.)

2. `with*` 다섯 메서드의 `new RoutineResponse(... profileId);` 끝을 `... profileId, language);` 로 바꾼다. 레포 루트에서 실행한다.
```bash
perl -pi -e 's/, profileId\);/, profileId, language);/' \
  server/src/main/java/com/chuseok22/elumserver/routine/application/dto/response/RoutineResponse.java
grep -c "profileId, language);" server/src/main/java/com/chuseok22/elumserver/routine/application/dto/response/RoutineResponse.java
```
Expected: `5` (`withCredit`, `withImageSkippedReason`, `withoutSourceText`, `withCreatorName`, `withCreatedByMe`)

3. `from` 의 마지막 인자를 바꾼다.

기존:
```java
      // 프록시의 getId 는 이룸이를 읽지 않는다
      routine.getProfile() == null ? null : routine.getProfile().getId()
    );
```
바꿈:
```java
      // 프록시의 getId 는 이룸이를 읽지 않는다
      routine.getProfile() == null ? null : routine.getProfile().getId(),
      routine.getLanguage() == null ? AppLocale.KO.code() : routine.getLanguage().code()
    );
```
import 를 더한다: `import com.chuseok22.elumserver.common.locale.AppLocale;`

4. 직접 생성하는 테스트 세 곳의 끝에 `"ko"` 를 더한다.
   - `RoutineControllerAuthorTest.java`: `createdBy, null, null, "p1");` → `createdBy, null, null, "p1", "ko");`
   - `RoutineControllerSourceTextTest.java`: `createdBy, null, null, null);` → `createdBy, null, null, null, "ko");`
   - `RoutineAuthorResolverTest.java`: `createdBy, null, null, profileId);` → `createdBy, null, null, profileId, "ko");`

- [ ] **Step 6: `RoutineService` 에 연결한다**

import 를 더한다.
```java
import com.chuseok22.elumserver.common.locale.EnabledLocales;
```
(`CurrentLocale` import 는 Task 8 에서 더했다.) 필드(`private final PictogramPicker pictogramPicker;` 아래, 111행)에 더한다.
```java
  private final EnabledLocales enabledLocales;
```
`create` 에서 `Routine routine = new Routine();`(218행) 바로 아래에 더한다.
```java
    // 일과의 콘텐츠 언어 — 만든 요청의 화면 언어를 켜진 언어 목록에 비춰 정한다 (다국어 #521). 보호자가 고르지 않는다.
    // 헤더가 없는 옛 앱은 KO 라 지금과 같다. 필터가 심은 값이라 요청 스레드에서만 읽는다.
    routine.setLanguage(enabledLocales.resolveContentLocale(CurrentLocale.get()));
```
`duplicate` 에서 `copy.setTitle(origin.getTitle());`(341행) 아래에 더한다.
```java
    // 카드 글이 원본 그대로이므로 언어도 원본을 따른다 (복제한 사람의 화면 언어가 아니다)
    copy.setLanguage(origin.getLanguage());
```

- [ ] **Step 7: 실행해서 통과를 확인한다**

Run:
```bash
cd server && ./gradlew test \
  --tests '*RoutineLanguageMigrationTest' --tests '*AppLocaleConverterTest' --tests '*RoutineResponseTest' \
  --tests '*RoutineResponseCreatorTest' --tests '*RoutineServiceTest' --tests '*RoutineServiceCreditTest' \
  --tests '*RoutineStepImageCreditTest' --tests '*RoutineStepEditTest' --tests '*RoutineControllerAuthorTest' \
  --tests '*RoutineControllerSourceTextTest' --tests '*RoutineAuthorResolverTest' \
  --tests '*MigrationRollbackContractTest' --tests '*BeanConstructorAmbiguityTest'
```
Expected: **PASS**. `RoutineStepImageCreditTest`·`RoutineStepEditTest` 는 `create` 를 부르지 않아 `EnabledLocales` 목이 없어도(null 주입) 통과한다. 만약 NPE 가 `RoutineService.create` 에서 나는 테스트가 있으면 그 클래스에도 위의 `@Mock EnabledLocales` + 기본 스텁을 더한다. `MigrationRollbackContractTest.onlyV32DropsOrTightens` 가 V33 이 `drop column`/`set not null` 을 쓰지 않음을 함께 지킨다.

- [ ] **Step 8: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/resources/db/migration/V33__add_routine_language.sql \
        server/src/main/java/com/chuseok22/elumserver/common/locale/AppLocaleConverter.java \
        server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/entity/Routine.java \
        server/src/main/java/com/chuseok22/elumserver/routine/application/dto/response/RoutineResponse.java \
        server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineService.java \
        server/src/test/java/com/chuseok22/elumserver/routine/infrastructure/entity/RoutineLanguageMigrationTest.java \
        server/src/test/java/com/chuseok22/elumserver/common/locale/AppLocaleConverterTest.java \
        server/src/test/java/com/chuseok22/elumserver/routine/application/dto/response/RoutineResponseTest.java \
        server/src/test/java/com/chuseok22/elumserver/routine/application/service/RoutineServiceTest.java \
        server/src/test/java/com/chuseok22/elumserver/routine/application/service/RoutineServiceCreditTest.java \
        server/src/test/java/com/chuseok22/elumserver/routine/application/controller/RoutineControllerAuthorTest.java \
        server/src/test/java/com/chuseok22/elumserver/routine/application/controller/RoutineControllerSourceTextTest.java \
        server/src/test/java/com/chuseok22/elumserver/routine/application/service/RoutineAuthorResolverTest.java
```

---

## Task 12: 관리자 화면에 일과 언어 표시

운영자용 화면이라 번역하지 않는다(스펙 4.5). 일과 목록과 상세에 언어만 보인다.

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminRoutineResponse.java` (record 끝 컴포넌트, `from`)
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminRoutineDetailResponse.java` (record 끝 컴포넌트, `from`)
- Modify: `server/src/main/resources/templates/admin/routines.html` (28행 `<th>상태</th>` 뒤, 37행 `emptyRow(5, ...)`, 45-49행 상태 칸 뒤)
- Modify: `server/src/main/resources/templates/admin/routine-detail.html` (보호자 줄 아래, "원본 입력" 위)
- Test: `server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminRoutineLanguageTemplateTest.java`

**Interfaces:**
- Consumes: `Routine.getLanguage()`(Task 11)
- Produces: `AdminRoutineResponse.language()`, `AdminRoutineDetailResponse.language()`(문자열 코드)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`AdminNoticeTemplateTest` 와 같은 방식(스프링 컨텍스트 없이 템플릿 엔진만)이다.

`server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminRoutineLanguageTemplateTest.java`:

```java
package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/** 일과 목록·상세가 일과의 언어를 보이는지 (다국어 #521). 스프링 컨텍스트 없이 템플릿 엔진만으로 그린다. */
class AdminRoutineLanguageTemplateTest {

  private SpringTemplateEngine engine;

  @BeforeEach
  void setUp() {
    ClassLoaderTemplateResolver resolver = new ClassLoaderTemplateResolver();
    resolver.setPrefix("templates/");
    resolver.setSuffix(".html");
    resolver.setTemplateMode(TemplateMode.HTML);
    resolver.setCharacterEncoding("UTF-8");
    engine = new SpringTemplateEngine();
    engine.setTemplateResolver(resolver);
    engine.setLinkBuilder(new StandardLinkBuilder() {
      @Override
      protected String computeContextPath(IExpressionContext context, String base, Map<String, Object> parameters) {
        return "";
      }
    });
  }

  private Routine routine(AppLocale language) {
    Profile profile = new Profile();
    profile.setId("p1");
    profile.setNickname("하늘이");
    Routine routine = new Routine();
    routine.setId("r1");
    routine.setProfile(profile);
    routine.setCreatedBy("member-1");
    routine.setTitle("병원 다녀오기");
    routine.setRawInputText("원문");
    routine.setSanitizedInputText("원문");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setScheduledAt(LocalDateTime.of(2026, 10, 2, 9, 0));
    routine.setSteps(List.of());
    routine.setLanguage(language);
    return routine;
  }

  @Test
  @DisplayName("응답 DTO 는 일과의 언어 코드를 담는다")
  void dtos_carryLanguage() {
    assertThat(AdminRoutineResponse.from(routine(AppLocale.JA), "kimchi").language()).isEqualTo("ja");
    assertThat(AdminRoutineDetailResponse.from(routine(AppLocale.ES), "kimchi").language()).isEqualTo("es");
    assertThat(AdminRoutineResponse.from(routine(AppLocale.KO), "kimchi").language()).isEqualTo("ko");
  }

  @Test
  @DisplayName("목록은 언어 열을 보이고 빈 줄의 칸 수도 맞는다")
  void list_showsLanguageColumn() {
    Context context = new Context();
    context.setVariable("routines", new PageImpl<>(
      List.of(AdminRoutineResponse.from(routine(AppLocale.EN), "kimchi")), PageRequest.of(0, 20), 1));
    context.setVariable("keyword", null);

    String html = engine.process("admin/routines", context);

    assertThat(html).contains("<th>언어</th>").containsPattern("badge badge-outline\"[^>]*>en</span>");
  }

  @Test
  @DisplayName("목록이 비면 빈 줄이 새 칸 수(6)를 덮는다")
  void list_empty_colspanCoversNewColumn() {
    Context context = new Context();
    context.setVariable("routines", new PageImpl<AdminRoutineResponse>(List.of(), PageRequest.of(0, 20), 0));
    context.setVariable("keyword", null);

    assertThat(engine.process("admin/routines", context)).contains("colspan=\"6\"");
  }

  @Test
  @DisplayName("상세는 콘텐츠 언어를 보인다")
  void detail_showsLanguage() {
    Context context = new Context();
    context.setVariable("routine", AdminRoutineDetailResponse.from(routine(AppLocale.ZH), "kimchi"));

    String html = engine.process("admin/routine-detail", context);

    assertThat(html).contains("콘텐츠 언어").containsPattern("badge badge-outline\"[^>]*>zh</span>");
  }
}
```

- [ ] **Step 2: 실행해서 실패를 확인한다**

Run: `cd server && ./gradlew test --tests '*AdminRoutineLanguageTemplateTest'`
Expected: **FAIL** (컴파일 오류 — `language()` 없음)

- [ ] **Step 3: DTO 를 고친다**

**`AdminRoutineResponse.java`** — 마지막 컴포넌트 `LocalDateTime completedAt` 뒤에 `String language` 를 더하고 `from` 의 마지막 인자에 더한다.
```java
  LocalDateTime completedAt,
  /** 일과의 콘텐츠 언어 코드 (다국어 #521). 운영자가 어느 언어로 만들어진 일과인지 본다. */
  String language
) {
```
```java
      routine.getCompletedAt(),
      routine.getLanguage().code()
    );
```
**`AdminRoutineDetailResponse.java`** — 같은 방식으로 `List<AdminRoutineStepResponse> steps` 뒤에 `String language` 를 더하고 `from` 의 `stepResponses` 뒤에 `routine.getLanguage().code()` 를 더한다.
```java
  List<AdminRoutineStepResponse> steps,
  /** 일과의 콘텐츠 언어 코드 (다국어 #521). */
  String language
) {
```
```java
      stepResponses,
      routine.getLanguage().code()
    );
```

- [ ] **Step 4: 템플릿을 고친다**

**`routines.html`**
1. `<th>상태</th>` 다음 줄에 `<th>언어</th>` 를 더한다.
```html
          <th>상태</th>
          <th>언어</th>
```
2. `emptyRow(5, '아직 만들어진 일과가 없어요')` 를 `emptyRow(6, '아직 만들어진 일과가 없어요')` 로 바꾼다.
3. 상태 칸(`<td>` … `COMPLETED` 배지 … `</td>`) 바로 뒤에 칸을 더한다.
```html
          <td>
            <span class="badge badge-outline" th:text="${routine.language()}">ko</span>
          </td>
```
**`routine-detail.html`** — 보호자 줄(`<div class="flex items-center gap-2">` … 배지 3개 … `</div>`) 다음, `<div>` + `원본 입력` 앞에 더한다.
```html
        <div class="flex items-center gap-2">
          <span class="text-base-content/60">콘텐츠 언어</span>
          <span class="badge badge-outline" th:text="${routine.language()}">ko</span>
        </div>
```

- [ ] **Step 5: 실행해서 통과를 확인한다**

Run: `cd server && ./gradlew test --tests '*AdminRoutineLanguageTemplateTest' --tests '*AdminNoticeTemplateTest' --tests '*AdminLayoutCsrfMetaTest' --tests '*ExceptionHandlerCoverageTest'`
Expected: **PASS**

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminRoutineResponse.java \
        server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminRoutineDetailResponse.java \
        server/src/main/resources/templates/admin/routines.html \
        server/src/main/resources/templates/admin/routine-detail.html \
        server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminRoutineLanguageTemplateTest.java
```

---

## Task 13: 헤더 없음 호환 묶음과 전체 통과

이 Task 는 새 코드를 쓰지 않는다. **이미 배포된 앱(헤더 없음)이 모든 새 경로에서 `ko` 로 동작함**을 한 번에 다시 증명하고, 전체 테스트가 기준선 이하로 줄지 않았음을 확인한다.

**Files:**
- Test: (기존 테스트 실행만)

**Interfaces:**
- Consumes: Task 1~12 의 테스트
- Produces: 통과 기록

- [ ] **Step 1: 헤더 없음 = ko 인 모든 새 경로를 묶어서 돌린다**

| 새 경로 | 증명하는 테스트 |
| --- | --- |
| 에러 응답(전 ErrorCode) 바이트 동일 | `LocalizedErrorResponsesTest.headerless_everyCode_bodyIsByteIdentical` |
| 검증 오류·본문 읽기 실패 응답 바이트 동일 | `GlobalExceptionHandlerLocaleMvcTest.headerless_*` |
| 401·503·DLP 필터 응답 | `LocalizedErrorResponsesTest.entryPoint_*`, `maintenance_*`, `dlpFilter_*` |
| ko 문구 = 작업 전 문구 | `ErrorMessageParityTest`, `ValidationMessageKeysTest` |
| 추천 일과·폴백 질문 | `RoutinePhrasesParityTest`, `RoutineAiPipelineFallbackLocaleTest.headerless_*` |
| 일과 언어 | `RoutineServiceTest.create_headerless_languageIsKo`, `RoutineResponseTest.from_carriesLanguageCode` |
| 일과 생성 가능 언어 기본값 | `EnabledLocalesTest.default_isKoOnly`, `SystemConfigInitializerLocaleTest` |
| 이상한 헤더 | `AppLocaleTest`, `AcceptLanguageFilterTest`, `GlobalExceptionHandlerLocaleMvcTest.weirdHeaders_*` |
| 파일이 비면 서버가 뜨지 않음 | `RoutinePhrasesTest`, `RoutinePhrasesStartupGuardTest` |

Run:
```bash
cd server && ./gradlew test \
  --tests '*AppLocaleTest' --tests '*AcceptLanguageFilterTest' --tests '*ErrorMessagesTest' \
  --tests '*ErrorMessageParityTest' --tests '*ValidationMessageKeysTest' \
  --tests '*LocalizedErrorResponsesTest' --tests '*GlobalExceptionHandlerLocaleMvcTest' \
  --tests '*RoutinePhrasesTest' --tests '*RoutinePhrasesParityTest' --tests '*RoutineAiPipelineFallbackLocaleTest' \
  --tests '*RoutinePhrasesStartupGuardTest' --tests '*EnabledLocalesTest' --tests '*SystemConfigServiceLocaleTest' \
  --tests '*SystemConfigInitializerLocaleTest' --tests '*AdminConfigControllerLocaleTest' \
  --tests '*RoutineLanguageMigrationTest' --tests '*AppLocaleConverterTest' --tests '*AdminRoutineLanguageTemplateTest'
```
Expected: **PASS** (전부)

- [ ] **Step 2: 전체 테스트를 돌리고 기준선과 비교한다**

Run:
```bash
cd server && ./gradlew test
python3 - <<'PY'
import glob, xml.etree.ElementTree as ET
t = f = e = s = 0
for path in glob.glob("build/test-results/test/*.xml"):
    r = ET.parse(path).getroot()
    t += int(r.get("tests")); f += int(r.get("failures")); e += int(r.get("errors")); s += int(r.get("skipped"))
print("NOW tests=%d failures=%d errors=%d skipped=%d" % (t, f, e, s))
PY
```
Expected: `failures=0 errors=0`, 그리고 `tests=` 가 Task 1 Step 1 의 `BASELINE tests=` **이상**(이 계획이 테스트를 더했으므로 늘어나야 한다. 줄었으면 어떤 클래스가 사라졌거나 컴파일에서 빠진 것이다 — 원인을 찾는다).

- [ ] **Step 3: 계약 이름을 마스터 Step 1 과 같은 방법으로 대조한다**

Run: `grep -rn "AppLocale\|ENABLED_CONTENT_LOCALES" docs/superpowers/plans/ | head -20 && grep -rn "V3[3-6]__" docs/superpowers/plans/`
Expected: 각 계획이 `AppLocale` · `ENABLED_CONTENT_LOCALES` 를 같은 철자로 인용하고, V33 은 이 계획에서만 만들어진다(`V33__add_routine_language.sql`).

- [ ] **Step 4: 사용자가 정할 항목을 이슈 #521 에 남긴다 (`/pro-github`)**

다음 세 가지를 코멘트로 남긴다(구현은 이미 하나로 정해 두었다 — 결정이 달라지면 해당 Task 만 고친다).
1. `Accept-Language` 품질값을 존중할지(지금은 C1 대로 첫 태그만).
2. `zh-TW`/`zh-Hant` 를 서버가 `zh` 로 볼지 `en` 으로 볼지(지금은 C1 대로 `zh`).
3. 메시지가 없는 `@NotBlank` 3곳(`OAuthLoginRequest`, `RefreshTokenRequest`, `RedeemLinkRequest`)의 Hibernate Validator 기본 문구는 요청 언어를 따르지만 이 계획은 건드리지 않았다.

- [ ] **Step 5: 완료 보고서 (`/pro-report`) → 푸시는 사용자가 요청할 때만**

푸시·배포는 하지 않는다. 푸시를 요청받으면 non-fast-forward 는 rebase 로 통합한다.

---

## 자체 검토

**스펙 coverage (7장 하위 2)**

| 요구 | 위치 |
| --- | --- |
| `Accept-Language` 처리(품질값·`*`·빈 값·`zh-TW`·`ar` 등) | Task 1, 2, 7 |
| `ErrorCode` 문구를 `MessageSource`(키 = 코드 이름)로, 호환 유지 | Task 3, 4, 5, 6 |
| 패리티 테스트(ko 리소스 == 기존 enum 문구)를 먼저, 헤더 없는 응답 바이트 동일 | Task 4 (golden, 먼저 실패), Task 6, 7 |
| 다른 언어 파일은 만들되 비어도 대체 순서로 동작, 번역 채우기는 계획 5 | Task 4 Step 3, Task 8 Step 5, `everyLocaleAlwaysGetsAMessage` |
| 검증 오류 `detail` 경로 | Task 7 (실제 코드 확인: 17줄, 키 체계, 기본 문구 대체) |
| 서버 생성 문장(폴백 질문·추천 58개)을 언어별 파일로 | Task 8 |
| 시작 시 검증 + 기동 검사 테스트 | Task 10 (+ 관리자 화면 저장 가드 Task 9) |
| `Routine.language`(V33·엔티티·`RoutineResponse.language`·기본 ko)·관리자 표시 | Task 11, 12 |
| `ENABLED_CONTENT_LOCALES`·`EnabledLocales`·잘못된 값 | Task 9 |
| 이미 배포된 앱 호환(모든 새 경로) | Task 13 표 |

**placeholder 점검:** TBD/TODO/"적절히" 없음. 코드 단계는 모두 실제 코드. 1회용 생성 스크립트는 Python 전문을 적었고 저장소에 넣지 않는다(삭제 문제도 없다).

**타입 일관성:** `AppLocale`(C2 시그니처 그대로) · `CurrentLocale.get()` · `EnabledLocales.contains/resolveContentLocale` · `ConfigKey.ENABLED_CONTENT_LOCALES` · V33 · `RoutineResponse.language`(문자열) 모두 마스터 계약과 같다. 추가한 이름(`ErrorMessages`, `RoutinePhrases`, `RoutinePhrasesStartupGuard`, `AcceptLanguageFilter`, `AppLocaleConverter`, `ErrorCode.CONTENT_LOCALE_NOT_READY`, `ConfigGroup.LANGUAGE`, `CurrentLocale.callAs/runAs`, `EnabledLocales.parse/normalize/current`)은 마스터 표에 없는 **내부 구현 이름**이고 계획 3·4 가 소비할 때는 위 Interfaces 를 그대로 쓴다.

**Review Focus 대응:** 위 표(5줄)가 각각 Task 와 테스트 클래스를 가리킨다.
