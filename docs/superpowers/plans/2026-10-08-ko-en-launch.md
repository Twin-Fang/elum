# 한국어·영어 두 언어 먼저 열기 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 화면 언어 `ko`·`en` 두 개만 연다. 클라이언트에 "열린 언어 목록"을 두고 영어 번역(ARB 516키)과 서버 에러·검증 문구 영어본을 채운다. 언어를 더 열 때는 번역 파일과 목록 한 줄만 더하면 된다.

**Architecture:** 구조(5개 언어 ARB, 일과 언어, `Accept-Language`·`X-Elum-Region`)는 #525·#526으로 이미 있다. 클라이언트는 `supportedAppLocales`(ARB가 있는 5개, gen-l10n 입력)와 별개로 `openedAppLocales`(실제로 여는 언어)를 두고 휴대폰 언어 판정을 후자로 한다. 서버는 이미 키 단위 대체(요청 언어 → en → ko)를 하므로 영어 문구만 채운다.

**Tech Stack:** Flutter(`gen-l10n`, ARB), Spring Boot(`MessageSource`, `messages_*.properties`).

**Spec:** `docs/superpowers/specs/2026-10-08-ko-en-launch-design.md` (상위: `2026-10-02-multi-language-design.md`)

## Global Constraints

- 지금 여는 언어는 `ko` `en` 둘뿐이다. `ja` `zh` `es`는 ARB 파일을 그대로 두고(5줄 골격) 열지 않는다.
- 열리지 않은 언어 휴대폰·번체 중국어는 `en`이다. 헤더가 없는 요청은 서버에서 `ko`다(이미 배포된 앱 보호).
- `ko` 화면은 이 작업 뒤에도 지금과 같다. 기존 골든·앱 테스트가 그대로 통과한다.
- 새 문구는 `app_ko.arb`가 원본이다. 영어는 같은 키·같은 자리표시자를 가진다. `batchim`(한국어 조사용)은 영어에서 쓰지 않는다.
- 영어 문구는 **이룸이를 `Elumi`로** 쓰고 `child` `kid`를 쓰지 않는다. 용어는 `docs/i18n/glossary.md`를 따른다.
- 법적 문구(약관·동의)는 이번 범위에서 번역하지 않는다. `consent*` 키는 화면 안내 문구만 번역한다.
- 서버 `routine-phrases_en`과 AI 콘텐츠 언어(`ENABLED_CONTENT_LOCALES`, 운영 값 `ko`)는 건드리지 않는다.
- 코드 주석은 간결한 한국어(WHY 중심), 이슈 번호·과거 경위는 쓰지 않는다. 커밋은 `/pro-commit`, 이슈 #521 연결, `Co-Authored-By` 금지, 푸시는 사용자 요청 시에만.
- 병렬 테스트 실행 금지. 테스트는 한 번에 하나씩 돌리고, 전체 테스트는 마지막에 1회만 돌린다.

## Review Focus

- 일본어·스페인어·간체·번체 휴대폰이 영어로 간다 (Task 1 테스트).
- 영어 휴대폰에서 한국어 일과(콘텐츠 언어 ko)의 카드 글이 한국어로 나오고 화면 문구만 영어다 — 기존 `content_language_*` 테스트가 계속 통과한다 (Task 4).
- 영어 문구가 한국어보다 길어 좁은 자리에서 잘린다 — 시뮬레이터 스크린샷으로 확인한다 (Task 4).
- ICU `plural`/`select` 키가 영어에서 `one`/`other`를 갖춘다 — 복수 14개 키 (Task 2 검사 스크립트).
- 서버 영어 문구에 한국어가 섞여 나간다 — 영어 문구에 한글이 없다 (Task 3 테스트).

---

### Task 1: 클라이언트 열린 언어 목록

**Files:**
- Modify: `client/lib/core/l10n/app_locales.dart`
- Modify: `client/lib/core/l10n/app_l10n.dart:37-43`
- Modify: `client/lib/core/l10n/effective_locale.dart:14-19`
- Modify: `client/test/l10n/locale_policy_test.dart`

**Interfaces:**
- Produces: `const openedAppLocales = <Locale>[Locale('ko'), Locale('en')]` — 휴대폰 언어 판정이 고르는 언어. `supportedAppLocales`의 부분집합이어야 한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/locale_policy_test.dart` 맨 위 `resolve` 정의와 첫 `group`을 아래로 바꾼다(번체·빈 목록 등 이후 그룹은 기대값을 `en`으로 맞춘다).

```dart
  Locale resolve(List<Locale>? phone) => resolveAppLocale(phone, openedAppLocales);

  group('열린 언어', () {
    test('한국어·영어는 지역과 무관하게 그 언어다', () {
      expect(resolve(const [Locale('ko', 'KR')]), const Locale('ko'));
      expect(resolve(const [Locale('en', 'US')]), const Locale('en'));
      expect(resolve(const [Locale('en', 'GB')]), const Locale('en'));
    });

    test('ARB 만 있고 열지 않은 언어는 영어다 — 일본어·스페인어·중국어(간체·번체)', () {
      expect(resolve(const [Locale('ja', 'JP')]), const Locale('en'));
      expect(resolve(const [Locale('es', 'MX')]), const Locale('en'));
      expect(resolve(const [Locale('zh', 'CN')]), const Locale('en'));
      expect(resolve(const [Locale('zh', 'TW')]), const Locale('en'));
    });

    test('앞선 후보가 닫혀 있으면 다음 후보를 본다', () {
      expect(resolve(const [Locale('ja'), Locale('ko')]), const Locale('ko'));
    });

    test('열린 언어는 ARB 가 있는 지원 언어의 부분집합이다', () {
      final supported = supportedAppLocales.map((l) => l.languageCode).toSet();
      expect(openedAppLocales.every((l) => supported.contains(l.languageCode)), isTrue);
    });
  });
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd client && flutter test test/l10n/locale_policy_test.dart`
Expected: FAIL — `openedAppLocales` 가 정의되지 않았다는 컴파일 오류.

- [ ] **Step 3: 구현한다**

`client/lib/core/l10n/app_locales.dart` 끝에 더한다.

```dart
/// 지금 실제로 여는 언어. 휴대폰 언어 판정은 이 목록에서만 고른다.
///
/// 언어를 더 열 때는 그 언어 ARB 번역을 채운 뒤 여기에 한 줄 더한다.
/// [supportedAppLocales] 의 부분집합이다 — ARB 가 있어야 열 수 있다.
const openedAppLocales = <Locale>[
  Locale('ko'),
  Locale('en'),
];
```

`client/lib/core/l10n/app_l10n.dart` 의 `resolveLocales` 를 바꾼다(`MaterialApp` 이 넘기는 `supported` 는 5개 전체라 쓰지 않는다).

```dart
  /// 휴대폰 언어 목록 → 앱 언어. 열린 언어 밖이면 en.
  /// MaterialApp 이 넘기는 지원 언어(ARB 5개)가 아니라 [openedAppLocales] 에서 고른다.
  static Locale? resolveLocales(
    List<Locale>? locales,
    Iterable<Locale> supported,
  ) => resolveAppLocale(locales, openedAppLocales);
```

`client/lib/core/l10n/effective_locale.dart` 의 판정 인자를 바꾼다.

```dart
  return resolveAppLocale(
    WidgetsBinding.instance.platformDispatcher.locales,
    openedAppLocales,
  );
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/locale_policy_test.dart test/l10n/app_locales_test.dart test/l10n/dev_locale_override_test.dart test/l10n/l10n_context_test.dart`
Expected: PASS. 실패하는 기존 기대(일본어 → ja 등)가 있으면 열린 언어 규칙에 맞게 `en` 으로 고친다.

- [ ] **Step 5: 커밋한다**

```bash
git add client/lib/core/l10n/app_locales.dart client/lib/core/l10n/app_l10n.dart client/lib/core/l10n/effective_locale.dart client/test/l10n/locale_policy_test.dart
git commit -m "5개 언어 지원 구조 설계 및 적용 : feat : 휴대폰 언어 판정이 ARB가 있는 5개가 아니라 실제로 여는 언어 목록(ko, en)에서 고르게 했다. 열지 않은 일본어·스페인어·중국어는 영어가 된다. 언어를 더 열 때는 번역을 채우고 목록에 한 줄만 더하면 된다 https://github.com/Twin-Fang/elum/issues/521"
```
(실제 커밋은 `/pro-commit` 으로 한다.)

---

### Task 2: 용어집과 영어 ARB 번역

**Files:**
- Create: `docs/i18n/glossary.md`
- Modify: `client/lib/l10n/app_en.arb`
- Modify: `client/test/l10n/arb_parity_test.dart:13`
- Modify (생성물): `client/lib/l10n/app_localizations*.dart` (`flutter gen-l10n`)

**Interfaces:**
- Consumes: Task 1 의 `openedAppLocales`
- Produces: `app_en.arb` 가 `app_ko.arb` 의 516개 키를 모두 갖는다. 키 이름은 바꾸지 않는다.

- [ ] **Step 1: 용어집을 만든다** — `docs/i18n/glossary.md`

```markdown
# 번역 용어집

문구를 옮기기 전에 이 표를 따른다. 새 용어는 여기에 먼저 더한다.

| 한국어 | English | 비고 |
| --- | --- | --- |
| 이룸 (앱 이름) | elum | 소문자 |
| 이룸이 | Elumi | 이용하는 당사자. `child` `kid` 금지 |
| 보호자 | guardian | |
| 함께하는 보호자 | co-guardian | 공동 보호자 |
| 일과 | routine | |
| 카드 | card | 한 카드에는 행동 하나 |
| 보상 | reward | 강화·강화물 표현 금지 |
| 별 | star | |
| 연결 암호 / 코드 | link code | 초대 코드는 invite code |
| 비밀암호 | passcode | 보호자 화면 잠금 |
| 보호자 화면 / 이룸이 화면 | Guardian mode / Elumi mode | 시안 문구 그대로 |
| 휴대폰 | phone | device 금지 |
| 임시저장 | draft | |
| 크레딧 | credit | AI 생성에 쓰는 횟수 |

문체: 짧고 평이한 문장, 능동형, 긍정형. 한국어 `-해요` 체의 부드러움은 `Please`를 남발하지 않고 명령형 + 이유로 옮긴다.
금지: 진단명·장애를 가리키는 말, "아이/child/kid", 기술 용어(server, error code 설명).
```

- [ ] **Step 2: 빠진 키를 세는 검사 스크립트를 만든다** (번역 중 진행 확인용, 저장소에 넣지 않는다)

```bash
cd client && cat > /tmp/en_check.py <<'E'
import json,re
ko=json.load(open('lib/l10n/app_ko.arb',encoding='utf-8'))
en=json.load(open('lib/l10n/app_en.arb',encoding='utf-8'))
keys=[k for k in ko if not k.startswith('@')]
missing=[k for k in keys if k not in en]
extra=[k for k in en if not k.startswith('@') and k!='@@locale' and k not in ko]
print('전체',len(keys),'빠짐',len(missing),'ko에 없는 키',extra)
ph=re.compile(r'\{\s*([A-Za-z_]\w*)\s*(?=[,}])')
bad=[]
for k in keys:
    if k in en and isinstance(en[k],str):
        want={p for p in ph.findall(ko[k])}-{'batchim'}
        got=set(ph.findall(en[k]))
        if want-got: bad.append((k,want-got))
        if re.search('[가-힣]',en[k]): bad.append((k,'한글 남음'))
        if 'plural' in en[k] and '{count, plural' in en[k] and 'other{' not in en[k]: bad.append((k,'plural other 없음'))
print('자리표시자·한글·plural 문제',bad)
E
python3 /tmp/en_check.py
```
Expected: `빠짐 516` (영어 파일에 대체 문구 2개만 있음).

- [ ] **Step 3: 번역을 다섯 묶음으로 채운다**

`app_ko.arb` 의 키를 접두사 묶음으로 나눠 `app_en.arb` 에 **키·`@키` 메타(placeholders, plural 선언)를 ko 와 똑같이** 복사하고 값만 영어로 옮긴다. 묶음마다 값을 옮긴 뒤 `python3 /tmp/en_check.py` 로 해당 묶음이 사라졌는지 본다. 한 묶음이 끝나면 커밋한다.

규칙:
- 값은 용어집을 따른다. 줄바꿈(`\n`)은 ko 와 같은 자리에 둔다(좁은 화면에서 의도한 끊김).
- 한국어 조사 `{batchim, select, …}` 는 영어에서 통째로 지우고 `{name}` 만 쓴다. 예: ko `{name}{batchim, select, yes{이} other{가}} 만든 일과예요` → en `A routine made by {name}`. 이때 `@키` 메타의 `batchim` 선언은 그대로 둔다(생성 시그니처를 ko 와 같게 유지한다).
- `plural` 은 영어 문법에 맞게 `one{…} other{…}` 둘 다 쓴다. 예: ko `{count, plural, other{크레딧 {count}개를 받았어요}}` → en `{count, plural, one{You got {count} credit} other{You got {count} credits}}`.
- 앱 이름 `appTitle` 은 `elum`.

묶음 (516키):
1. `card` `routine` — 111키
2. `invite` `link` `pin` — 99키
3. `guardians` `guardian` `credit` — 76키
4. `reward` `today` `consent` `common` `onboarding` `login` — 95키
5. 나머지 전부(`child` `elumi` `draft` `app` `ad` `image` `suggestion` `mode` `role` `coach` `profile` `question` `character` `goal` `notice` `failure` `home` `date` `installation` `weekday` `sentence` `agent` `ai`) — 135키

묶음의 키 목록 뽑기 (예: 1번):
```bash
cd client && python3 - <<'E'
import json,re
ko=json.load(open('lib/l10n/app_ko.arb',encoding='utf-8'))
want={'card','routine'}
for k,v in ko.items():
    if k.startswith('@'): continue
    if re.match(r'[a-z]+',k).group(0) in want: print(k,'=',json.dumps(v,ensure_ascii=False))
E
```

- [ ] **Step 4: 모든 묶음이 끝났는지 확인한다**

Run: `cd client && python3 /tmp/en_check.py`
Expected: `빠짐 0 ko에 없는 키 []` 그리고 `문제 []`.

- [ ] **Step 5: 패리티 테스트에서 영어를 연다 (실패 → 통과)**

`client/test/l10n/arb_parity_test.dart` 의 `openedLocales` 를 바꾼다.

```dart
const openedLocales = <String>{'ko', 'en'};
```

Run: `cd client && flutter gen-l10n && flutter test test/l10n/arb_parity_test.dart test/l10n/missing_key_fallback_test.dart test/l10n/locale_policy_test.dart`
Expected: PASS. (`missing_key_fallback_test` 는 키가 채워진 언어를 건너뛴다.) 패리티가 실패하면 출력의 빠진 키·자리표시자를 고친다.

- [ ] **Step 6: 커밋한다** — 생성물(`app_localizations*.dart`)을 포함한다.

```bash
git add docs/i18n/glossary.md client/lib/l10n/app_en.arb client/lib/l10n/app_localizations.dart client/lib/l10n/app_localizations_en.dart client/test/l10n/arb_parity_test.dart
git commit -m "5개 언어 지원 구조 설계 및 적용 : feat : 화면 문구 516개를 영어로 옮기고 용어집을 만들었다 https://github.com/Twin-Fang/elum/issues/521"
```
(실제 커밋은 `/pro-commit` 으로 한다.)

---

### Task 3: 서버 에러·검증 문구 영어본

**Files:**
- Modify: `server/src/main/resources/i18n/messages_en.properties`
- Create: `server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/EnglishMessagesCompletenessTest.java`

**Interfaces:**
- Consumes: `messages_ko.properties` 의 키(원본). `ErrorMessages.of(String, AppLocale, String)`.
- Produces: `messages_en.properties` 가 `messages_ko.properties` 의 모든 키(123개)에 영어 값을 갖는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```java
package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Properties;
import java.util.TreeSet;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 영어 문구가 한국어 원본의 모든 키를 갖고, 한글이 섞이지 않는다. */
class EnglishMessagesCompletenessTest {

  private static final Pattern HANGUL = Pattern.compile("[가-힣]");

  private static Properties load(String locale) throws IOException {
    Properties p = new Properties();
    try (var in = EnglishMessagesCompletenessTest.class.getResourceAsStream("/i18n/messages_" + locale + ".properties")) {
      p.load(new InputStreamReader(in, StandardCharsets.UTF_8));
    }
    return p;
  }

  @Test
  @DisplayName("영어 문구는 한국어 원본의 모든 키에 비어 있지 않은 값을 준다")
  void everyKoreanKeyHasEnglishText() throws IOException {
    Properties ko = load("ko");
    Properties en = load("en");
    var missing = new TreeSet<String>();
    for (String key : ko.stringPropertyNames()) {
      String text = en.getProperty(key);
      if (text == null || text.isBlank()) {
        missing.add(key);
      }
    }
    assertThat(missing).as("영어 문구가 없는 키").isEmpty();
  }

  @Test
  @DisplayName("영어 문구에는 한글이 없다")
  void englishTextHasNoHangul() throws IOException {
    Properties en = load("en");
    var bad = new TreeSet<String>();
    for (String key : en.stringPropertyNames()) {
      if (HANGUL.matcher(en.getProperty(key)).find()) {
        bad.add(key);
      }
    }
    assertThat(bad).as("한글이 남은 영어 문구").isEmpty();
  }

  @Test
  @DisplayName("영어 문구는 한국어 원본에 없는 키를 만들지 않는다")
  void noExtraKeys() throws IOException {
    var extra = new TreeSet<>(load("en").stringPropertyNames());
    extra.removeAll(load("ko").stringPropertyNames());
    assertThat(extra).isEmpty();
  }
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd server && ./gradlew test --tests '*EnglishMessagesCompletenessTest'`
Expected: FAIL — 영어 문구가 없는 키 123개.

- [ ] **Step 3: 영어 문구를 채운다**

`messages_ko.properties` 의 123개 키를 `messages_en.properties` 에 **같은 키**로 옮기고 값만 영어로 쓴다(맨 위 주석 두 줄은 유지하되 "계획 5에서 채운다" 문장은 지운다). 규칙:
- 사용자에게 직접 보이는 문장이다. 짧고 평이하게, 사과·원인 설명을 늘이지 않는다. 내부 용어(서버, 토큰, 예외)를 쓰지 않는다.
- `MessageFormat` 자리표시자 `{0}` 등이 ko 에 있으면 그대로 유지한다.
- 예: `MEMBER_NOT_FOUND=존재하지 않는 회원입니다.` → `MEMBER_NOT_FOUND=We couldn't find this account.`, `validation.routineCreateRequest.rawInputText.Size=일과 내용은 1000자를 넘을 수 없습니다.` → `validation.routineCreateRequest.rawInputText.Size=Routine text can't be longer than 1000 characters.`
- 용어는 `docs/i18n/glossary.md` 를 따른다.

- [ ] **Step 4: 통과를 확인한다**

Run: `cd server && ./gradlew test --tests '*EnglishMessagesCompletenessTest' --tests '*ErrorMessageParityTest' --tests '*ErrorMessagesTest' --tests '*ErrorMessagesStartupGuardTest' --tests '*ValidationMessageKeysTest'`
Expected: PASS. ko golden(`ErrorMessageParityTest`)은 바뀌지 않는다.

- [ ] **Step 5: 커밋한다**

```bash
git add server/src/main/resources/i18n/messages_en.properties server/src/test/java/com/chuseok22/elumserver/common/infrastructure/exception/EnglishMessagesCompletenessTest.java
git commit -m "5개 언어 지원 구조 설계 및 적용 : feat : 서버 에러·검증 문구 123개를 영어로 옮기고, 한국어 원본의 모든 키에 영어가 있고 한글이 섞이지 않음을 테스트로 고정했다 https://github.com/Twin-Fang/elum/issues/521"
```
(실제 커밋은 `/pro-commit` 으로 한다.)

---

### Task 4: 검증과 이슈 기록

**Files:** 없음 (검증·기록)

- [ ] **Step 1: 클라이언트 정적 분석과 전체 테스트를 한 번 돌린다**

Run: `cd client && flutter analyze && flutter test`
Expected: analyze 0건, 전체 테스트 실패 0. 한국어 화면 골든이 바뀌었으면 원인을 찾는다(이번 작업은 `ko` 화면을 바꾸지 않는다).

- [ ] **Step 2: 서버 전체 테스트를 한 번 돌린다**

Run: `cd server && ./gradlew test`
Expected: 전체 통과.

- [ ] **Step 3: 영어 휴대폰 화면을 시뮬레이터로 확인한다**

`/pro-launch` 로 iOS 시뮬레이터(사용자가 정한 기기)를 영어로 바꿔 앱을 띄우고 아래를 찍는다. 기기 ID 는 사용자에게 받는다.
1. 온보딩·역할 선택·로그인 안내 — 영어이고 글자가 잘리지 않는다.
2. 보호자 홈·일과 만들기 입력 — 좁은 버튼과 탭 글자가 잘리지 않는다.
3. 한국어 일과가 있는 홈 — 카드 글은 한국어, 화면 문구는 영어.
4. 같은 시뮬레이터를 한국어로 되돌려 같은 화면이 지금과 같다.
확인하지 못한 화면은 이슈에 못 했다고 적는다.

- [ ] **Step 4: 이슈 #521 에 정리 댓글을 남긴다** — `/pro-report`

범위(ko·en만 열기), 바뀐 것(열린 언어 목록·영어 ARB 516키·서버 영어 문구 123키), 검증(테스트 수·시뮬레이터 스크린샷), 남은 일(영어 AI 생성 계획 3, 영어 약관·공지 계획 4, ja·zh·es 번역)을 담는다. `작업중` 라벨은 유지한다 — 계획 3~7 이 남아 있다.

---

## Self-Review

- **스펙 범위**: 3.1(열린 목록) → Task 1, 3.2(서버 목록 없음) → 서버는 Task 3 만, 3.3(영어 번역·용어집) → Task 2·3, 3.4(실패 경로) → 패리티·완결성 테스트, 4(테스트) → Task 1~4. 5(열어 둔 것)은 이슈 댓글에 기록.
- **용어 일관**: `openedAppLocales`(코드), `openedLocales`(패리티 테스트의 기존 이름)는 서로 다른 계층의 이름이다 — 테스트 쪽 이름은 바꾸지 않는다.
- **번역 본문**: 516키·123키의 영어 값은 번역 작업 자체이므로 계획에 싣지 않고, 규칙·예시·묶음·검사 스크립트·완결성 테스트로 완료 기준을 고정했다.
