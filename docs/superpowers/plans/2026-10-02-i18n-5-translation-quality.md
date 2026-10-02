# 다국어 5 — 번역·품질 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> 이 문서는 마스터 계획 `2026-10-02-i18n-0-master.md` 의 하위 계획 5다. 공통 계약 C1~C5 의 이름을 그대로 쓴다. 이름을 바꾸려면 마스터를 먼저 고친다.
> 선행: 계획 1(ARB·`l10n.yaml`·`AppLocalizations`·`supportedAppLocales`). Task 6 의 서버 부분은 계획 2(번역 리소스 파일)가 머지된 뒤에 실행한다. 나머지는 계획 1 만 있으면 된다.

**Goal:** 번역이 빠지거나 깨진 채로 언어가 열리지 않게 CI 와 문서로 막는다. 용어집·번역 절차·언어 오픈 체크리스트를 만들고, 번역이 길어져 화면이 깨지는지 위젯 테스트로 확인한다. 시안 대조는 `ko` 에만 적용한다.

**Architecture:** "켜진 언어"의 단일 출처를 레포 파일 `docs/i18n/launched-locales.txt` 로 둔다(서버 `ENABLED_CONTENT_LOCALES` 는 DB 값이라 CI 가 못 본다). 클라이언트 번역 검사는 순수 Dart 규칙 라이브러리(`arb_parity.dart` + `icu_message_check.dart`)와 그 규칙을 진짜 ARB 에 대는 테스트로 나눠, 규칙은 가짜 데이터로 고정하고 데이터는 규칙에 통과시키기만 한다. 서버는 같은 규칙을 `.properties` 에 대는 파일 검사 테스트를 새 워크플로가 돌린다(서버 배포 워크플로는 `-x test` 라 서버 테스트를 도는 곳이 없다). 넘침 검사는 `pumpWithLocale` 로 대표 화면을 5개 언어 × 글자 배율로 띄워 **ko 보다 나빠지지 않는지**를 본다.

**Tech Stack:** Flutter(`flutter_test`, `flutter gen-l10n`), Dart 순수 라이브러리, GitHub Actions, JUnit 5 + AssertJ(Spring 없이), Markdown 문서.

**Spec:** `docs/superpowers/specs/2026-10-02-multi-language-design.md` (5장 · 6장 · 7장 5번 · 9장)

## Global Constraints

- 지원 언어는 `ko` `en` `ja` `zh`(간체) `es` 다섯이다. RTL과 번체 중국어는 범위 밖이다.
- **앱 안에는 언어 선택 화면을 만들지 않는다.** 언어 강제 스위치는 개발자 도구(`core/dev`)에만 둔다.
- 대체 순서는 어디서든 **요청 언어 → `en` → `ko`** 이다. 단 요청 언어가 `ko` 이면 `ko` 만 본다(한국어 사용자에게 영어를 보이지 않는다).
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

## Review Focus

이 계획이 소유한 줄. 각 줄은 아래 Task 의 테스트로 고정한다.

- 번역 문자열이 길어도(스페인어) 고정 폭 위젯에서 넘치지 않는다. (계획 1, 5) → Task 7
- 번역 파일 간 키·자리표시자 불일치를 CI가 잡는다. (계획 5) → Task 3, 4, 5, 6

## 이 계획이 정한 것 (마스터와 스펙에 더한 결정)

실제 코드를 읽고 정한 것이다. 마스터·스펙과 다르게 보이는 곳은 이유를 적었다.

| 결정 | 이유 |
| --- | --- |
| "켜진 언어" CI 게이트는 `docs/i18n/launched-locales.txt` 다 | 마스터의 `ENABLED_CONTENT_LOCALES` 는 관리자 화면(DB) 값이라 CI 가 읽을 수 없다. 운영 값은 늘 이 파일의 부분집합이다 |
| **빈 값은 켜지지 않은 언어에서도 금지**, 키가 빠지는 것만 허용 | 앱은 휴대폰 언어가 5개 중 하나면 그 언어를 쓴다(켜졌는지와 무관). 빈 문자열은 `en` → `ko` 대체로 떨어지지 않고 빈 글자로 그려진다 |
| 서버 번역 검사는 **새 워크플로**(`PROJECT-ELUM-SERVER-I18N-CHECK.yaml`)가 돈다 | `PROJECT-SPRING-CICD.yaml` 이 `./gradlew clean build -x test` 로 빌드하고, 서버 테스트를 도는 워크플로가 레포에 없다 |
| 시안 대조 테스트(19개 파일)는 `Locale('ko')` 를 지정해야 한다 — 가드 테스트가 지킨다 | 계획 1 이후 MaterialApp 에 지역화가 들어가면 테스트 환경(`en_US`)이 영어로 떨어져 한글 시안과 맞댄다 |
| 넘침 검사는 "ko 보다 나빠지지 않는다"를 본다 | 아래 Task 7 에서 실측했다. 지금 `ko` 화면이 이미 큰 글자(1.5~2.0배)에서 넘치는 곳이 있다. 절대 기준으로 걸면 번역과 무관한 기존 결함에 막힌다 |

---

## Task 1: 켜진 언어 게이트 파일과 읽기 헬퍼

**Files:**
- Create: `docs/i18n/launched-locales.txt`
- Create: `client/test/helpers/launched_locales.dart`
- Test: `client/test/l10n/launched_locales_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces: `Set<String> readLaunchedLocales({String path})`, `const knownLocaleCodes` — Task 4·9 와 계획 6 의 네이티브 리소스 테스트가 쓴다. 서버 테스트(Task 6)는 같은 파일을 자바로 읽는다.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`client/test/l10n/launched_locales_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/launched_locales.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('launched'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('주석과 빈 줄을 건너뛰고 코드를 읽는다', () {
    final f = File('${tmp.path}/l.txt')..writeAsStringSync('# 주석\nko\n\nen\n');
    expect(readLaunchedLocales(path: f.path), {'ko', 'en'});
  });

  test('ko 가 없으면 실패한다', () {
    final f = File('${tmp.path}/l.txt')..writeAsStringSync('en\n');
    expect(() => readLaunchedLocales(path: f.path), throwsStateError);
  });

  test('모르는 언어 코드는 오타로 보고 실패한다', () {
    final f = File('${tmp.path}/l.txt')..writeAsStringSync('ko\nfr\n');
    expect(() => readLaunchedLocales(path: f.path), throwsStateError);
  });

  test('파일이 없으면 기본값으로 넘어가지 않고 실패한다', () {
    expect(
      () => readLaunchedLocales(path: '${tmp.path}/none.txt'),
      throwsStateError,
    );
  });

  test('레포의 게이트 파일이 유효하다', () {
    expect(readLaunchedLocales(), contains('ko'));
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd client && flutter test test/l10n/launched_locales_test.dart`
Expected: FAIL — 컴파일 오류 `Not found: '../helpers/launched_locales.dart'`

- [ ] **Step 3: 게이트 파일을 만든다**

`docs/i18n/launched-locales.txt` (지금은 `ko` 하나다. 언어를 여는 PR 이 한 줄씩 더한다):

```text
ko
```

- [ ] **Step 4: 읽기 헬퍼를 만든다**

`client/test/helpers/launched_locales.dart`:

```dart
import 'dart:io';

/// 앱이 지원하는 언어 코드 다섯. 파일 값이 이 밖이면 오타다.
const knownLocaleCodes = ['ko', 'en', 'ja', 'zh', 'es'];

/// `docs/i18n/launched-locales.txt` 에 적힌 켜진 언어를 읽는다.
///
/// 이 파일이 **CI 가 보는 '켜진 언어'의 단일 출처**다. 서버의 `ENABLED_CONTENT_LOCALES`(관리자
/// 화면 설정)는 DB 값이라 CI 가 못 본다. 그래서 언어를 켜는 PR 이 이 파일에 한 줄을 더하고,
/// 그 순간부터 그 언어의 번역 누락이 빌드를 실패시킨다.
///
/// 한 줄에 코드 하나, `#` 로 시작하는 줄과 빈 줄은 건너뛴다. 파일이 없거나 `ko` 가 없으면
/// 조용히 기본값으로 넘기지 않고 예외로 알린다 — 게이트가 사라진 채 통과하면 안 된다.
Set<String> readLaunchedLocales({
  String path = '../docs/i18n/launched-locales.txt',
}) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('$path 가 없다. 켜진 언어 게이트 파일이 지워졌다.');
  }
  final codes = file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();
  final unknown = codes.where((c) => !knownLocaleCodes.contains(c)).toList();
  if (unknown.isNotEmpty) {
    throw StateError('$path 에 모르는 언어 코드가 있다: $unknown (허용: $knownLocaleCodes)');
  }
  if (!codes.contains('ko')) {
    throw StateError('$path 에 ko 가 없다. ko 는 늘 켜져 있어야 한다.');
  }
  return codes.toSet();
}
```

- [ ] **Step 5: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/launched_locales_test.dart`
Expected: PASS — `All tests passed!` (5건)

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/launched-locales.txt client/test/helpers/launched_locales.dart client/test/l10n/launched_locales_test.dart
```

---

## Task 2: ICU 문구 검사기

**Files:**
- Create: `client/test/helpers/icu_message_check.dart`
- Test: `client/test/l10n/icu_message_check_test.dart`

**Interfaces:**
- Consumes: 없음 (순수 Dart)
- Produces: `IcuReport checkIcuMessage(String message)` — `placeholders`(Set<String>), `errors`(List<String>), `isValid`. Task 3 의 규칙이 쓴다.

`flutter gen-l10n` 도 ICU 문법을 보지만 첫 오류에서 멈추고 언어·키를 알려 주지 않는다. 번역가가 고친 문구가 어디서 깨졌는지 한 번에 보려고 같은 규칙을 테스트에서 따로 돌린다. 자리표시자 이름 집합은 언어 간 비교에도 쓴다.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`client/test/l10n/icu_message_check_test.dart`:

```dart
import '../helpers/icu_message_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('유효한 문구', () {
    test('글만 있는 문구', () {
      final r = checkIcuMessage('저장했어요');
      expect(r.isValid, isTrue);
      expect(r.placeholders, isEmpty);
    });

    test('단순 자리표시자', () {
      final r = checkIcuMessage('{name}의 휴대폰을 연결할까요?');
      expect(r.isValid, isTrue);
      expect(r.placeholders, {'name'});
    });

    test('복수형과 안쪽 자리표시자', () {
      final r = checkIcuMessage(
        '{count, plural, =0{카드가 없어요} one{카드 {count}장} other{카드 {count}장}}',
      );
      expect(r.errors, isEmpty);
      expect(r.placeholders, {'count'});
    });

    test('select 와 number', () {
      final r = checkIcuMessage(
        '{who, select, guardian{보호자} other{이룸이}} {n, number}',
      );
      expect(r.errors, isEmpty);
      expect(r.placeholders, {'who', 'n'});
    });

    test("작은따옴표 규칙: '' 와 '{'", () {
      expect(checkIcuMessage("it''s fine").isValid, isTrue);
      expect(checkIcuMessage("중괄호는 '{'로 쓴다").isValid, isTrue);
      expect(checkIcuMessage("don't").isValid, isTrue);
    });
  });

  group('깨진 문구', () {
    test('닫히지 않은 {', () {
      expect(checkIcuMessage('{name').isValid, isFalse);
      expect(checkIcuMessage('안녕 {name 님').isValid, isFalse);
    });

    test('짝 없는 }', () {
      expect(checkIcuMessage('안녕 name}').isValid, isFalse);
    });

    test('plural 에 other 가 없다', () {
      final r = checkIcuMessage('{n, plural, one{1장}}');
      expect(r.errors.single, contains('other'));
    });

    test('plural 분기 이름이 잘못됐다', () {
      final r = checkIcuMessage('{n, plural, uno{1} other{x}}');
      expect(r.errors.join(), contains('uno'));
    });

    test('분기가 중복됐다', () {
      final r = checkIcuMessage('{n, plural, one{a} one{b} other{c}}');
      expect(r.errors.join(), contains('두 번'));
    });

    test('분기 안쪽이 닫히지 않았다', () {
      expect(checkIcuMessage('{n, plural, other{카드 {n}장}').isValid, isFalse);
    });

    test('알 수 없는 형식과 잘못된 이름', () {
      expect(checkIcuMessage('{n, foo}').isValid, isFalse);
      expect(checkIcuMessage('{1x}').isValid, isFalse);
      expect(checkIcuMessage('{}').isValid, isFalse);
    });

    test('빈 분기 목록', () {
      expect(checkIcuMessage('{n, plural}').isValid, isFalse);
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd client && flutter test test/l10n/icu_message_check_test.dart`
Expected: FAIL — 컴파일 오류 `Not found: '../helpers/icu_message_check.dart'`

- [ ] **Step 3: 검사기를 만든다**

`client/test/helpers/icu_message_check.dart`:

```dart
/// ARB 문구 하나를 ICU MessageFormat 규칙으로 검사한다.
///
/// 왜 직접 읽나 — `flutter gen-l10n` 도 문법을 보지만, 오류가 첫 건에서 멈추고 어느 언어의
/// 어느 키인지 알려 주지 않는다. 번역가가 고친 문구가 어디서 깨졌는지 한 번에 보려고
/// 같은 규칙을 테스트에서 따로 돌린다. 또 자리표시자 이름 집합을 언어 간에 맞대는 데 쓴다.
///
/// 지원하는 형태: `{name}` · `{n, number}` · `{d, date, yMd}` ·
/// `{n, plural, =0{…} one{…} other{…}}` · `{g, select, a{…} other{…}}` · `selectordinal`.
/// 작은따옴표 규칙: `''` 는 작은따옴표 하나, `'{'` 는 중괄호를 글자 그대로 쓴다.
class IcuReport {
  const IcuReport(this.placeholders, this.errors);

  /// 문구가 쓰는 자리표시자 이름(복수·선택 분기 안쪽 것까지 포함).
  final Set<String> placeholders;

  /// 사람이 읽는 오류 문장. 비어 있으면 유효하다.
  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

IcuReport checkIcuMessage(String message) {
  final parser = _IcuParser(message)..parseText(nested: false);
  return IcuReport(parser.names, parser.errors);
}

class _IcuParser {
  _IcuParser(this.s);

  final String s;
  int i = 0;
  final Set<String> names = {};
  final List<String> errors = [];

  static final _nameRe = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  static final _pluralKeyRe = RegExp(r'^(zero|one|two|few|many|other|=\d+)$');

  /// 글을 읽는다. [nested] 면 분기 안쪽이라 짝이 맞는 `}` 에서 멈춘다(닫는 괄호는 호출자가 먹는다).
  void parseText({required bool nested}) {
    while (i < s.length) {
      final c = s[i];
      if (c == "'") {
        _skipQuote();
      } else if (c == '{') {
        i++;
        _parseArgument();
      } else if (c == '}') {
        if (nested) return;
        errors.add('짝 없는 } (위치 $i)');
        i++;
      } else {
        i++;
      }
    }
    if (nested) errors.add('닫히지 않은 { 가 있다');
  }

  void _skipQuote() {
    final next = i + 1 < s.length ? s[i + 1] : '';
    if (next == "'") {
      i += 2; // '' → '
    } else if (next == '{' || next == '}') {
      final end = s.indexOf("'", i + 1);
      if (end == -1) {
        errors.add("닫히지 않은 따옴표(') (위치 $i)");
        i = s.length;
      } else {
        i = end + 1;
      }
    } else {
      i++; // 중괄호와 상관없는 아포스트로피는 글자다
    }
  }

  /// `,` 또는 `}` 앞까지 읽어 앞뒤 공백을 뗀 값을 돌려준다. [i] 는 구분자 위에 놓인다.
  String _readUntilDelimiter() {
    final start = i;
    while (i < s.length && s[i] != ',' && s[i] != '}') {
      i++;
    }
    return s.substring(start, i).trim();
  }

  void _parseArgument() {
    final name = _readUntilDelimiter();
    if (i >= s.length) {
      errors.add('닫히지 않은 { (자리표시자 "$name")');
      return;
    }
    if (_nameRe.hasMatch(name)) {
      names.add(name);
    } else {
      errors.add('자리표시자 이름이 올바르지 않다: "$name"');
    }
    if (s[i] == '}') {
      i++;
      return;
    }

    i++; // ','
    final type = _readUntilDelimiter();
    if (i >= s.length) {
      errors.add('닫히지 않은 { (자리표시자 "$name")');
      return;
    }
    final isBranching =
        type == 'plural' || type == 'select' || type == 'selectordinal';
    if (isBranching) {
      if (s[i] != ',') {
        errors.add('$name: $type 에 분기가 없다');
        i++;
        return;
      }
      i++; // ','
      _parseBranches(name, type);
    } else if (type == 'number' || type == 'date' || type == 'time') {
      // 형식 이름(compact, yMd …)은 닫는 괄호까지 건너뛴다
      while (i < s.length && s[i] != '}') {
        i++;
      }
      if (i >= s.length) {
        errors.add('닫히지 않은 { (자리표시자 "$name")');
      } else {
        i++;
      }
    } else {
      errors.add('$name: 알 수 없는 형식 "$type"');
      while (i < s.length && s[i] != '}') {
        i++;
      }
      if (i < s.length) i++;
    }
  }

  void _parseBranches(String name, String type) {
    final keys = <String>{};
    while (true) {
      while (i < s.length && s[i].trim().isEmpty) {
        i++;
      }
      if (i >= s.length) {
        errors.add('$name: 닫히지 않은 { (분기 목록)');
        return;
      }
      if (s[i] == '}') {
        i++;
        break;
      }
      final keyStart = i;
      while (i < s.length && s[i] != '{' && s[i] != '}') {
        i++;
      }
      final key = s.substring(keyStart, i).trim();
      if (i >= s.length || s[i] != '{' || key.isEmpty) {
        errors.add('$name: 분기 이름 뒤에 { 가 없다 ("$key")');
        return;
      }
      if (type != 'select' && !_pluralKeyRe.hasMatch(key)) {
        errors.add('$name: plural 에서 쓸 수 없는 분기 "$key"');
      }
      if (!keys.add(key)) errors.add('$name: 분기 "$key" 가 두 번 나온다');
      i++; // '{'
      parseText(nested: true);
      if (i >= s.length) return; // 닫히지 않은 오류는 parseText 가 이미 적었다
      i++; // '}'
    }
    if (!keys.contains('other')) {
      errors.add('$name: $type 에 other 분기가 없다');
    }
  }
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/icu_message_check_test.dart && flutter analyze test/helpers test/l10n`
Expected: PASS — 13건, analyze `No issues found!`

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/test/helpers/icu_message_check.dart client/test/l10n/icu_message_check_test.dart
```

---

## Task 3: ARB 규칙 라이브러리와 규칙 테스트

**Files:**
- Create: `client/test/helpers/arb_parity.dart`
- Test: `client/test/l10n/arb_parity_rules_test.dart`
- Test: `client/test/l10n/arb_loading_test.dart`

**Interfaces:**
- Consumes: Task 2 의 `checkIcuMessage`, C4 의 파일 이름 `app_<언어>.arb`(템플릿 `ko`)
- Produces: `typedef ArbSet`, `ArbSet loadArbSet(Directory)`, `List<String> arbViolations(ArbSet, {required Set<String> launched, String template})` — 위반은 `[언어] 키: 이유` 문장 목록이다.

규칙:

| 대상 | 규칙 |
| --- | --- |
| 모든 언어 | ko 에 없는 키 금지 · **빈 값 금지** · ICU 문법 · 자리표시자 이름이 ko 와 같다 |
| 켜진 언어 | 위에 더해 키가 ko 와 정확히 같다(빠진 키 금지) |
| 켜지지 않은 언어 | 키를 **빼는 것**은 허용(대체 문구 `en` → `ko` 로 떨어진다) |

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`client/test/l10n/arb_parity_rules_test.dart`:

```dart
import '../helpers/arb_parity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = {
    'hello': '안녕하세요',
    'linkAsk': '{name}의 휴대폰을 연결할까요?',
    'cards': '{count, plural, other{카드 {count}장}}',
  };

  test('모두 맞으면 위반이 없다', () {
    final v = arbViolations(
      {
        'ko': ko,
        'en': {
          'hello': 'Hello',
          'linkAsk': "Connect {name}''s phone?",
          'cards': '{count, plural, one{{count} card} other{{count} cards}}',
        },
      },
      launched: {'ko', 'en'},
    );
    expect(v, isEmpty);
  });

  test('ko 에 없는 키를 잡는다', () {
    final v = arbViolations(
      {
        'ko': ko,
        'en': {'extra': 'x'},
      },
      launched: {'ko'},
    );
    expect(v.single, contains('ko 에 없는 키'));
  });

  test('켜지지 않은 언어는 키가 빠져도 되지만 켜진 언어는 안 된다', () {
    final en = {'hello': 'Hello'};
    expect(arbViolations({'ko': ko, 'en': en}, launched: {'ko'}), isEmpty);
    final v = arbViolations({'ko': ko, 'en': en}, launched: {'ko', 'en'});
    expect(v.length, 2);
    expect(v.join(), contains('켜진 언어인데 번역이 없다'));
  });

  test('빈 값은 켜지지 않은 언어에서도 잡는다', () {
    final v = arbViolations(
      {
        'ko': ko,
        'ja': {'hello': '  '},
      },
      launched: {'ko'},
    );
    expect(v.single, contains('값이 비어 있다'));
  });

  test('자리표시자 이름이 다르면 잡는다', () {
    final v = arbViolations(
      {
        'ko': ko,
        'es': {'linkAsk': '¿Conectar el teléfono de {nombre}?'},
      },
      launched: {'ko'},
    );
    expect(v.single, contains('빠짐 [name]'));
    expect(v.single, contains('더함 [nombre]'));
  });

  test('자리표시자를 빼먹어도 잡는다', () {
    final v = arbViolations(
      {
        'ko': ko,
        'ja': {'linkAsk': '携帯を接続しますか?'},
      },
      launched: {'ko'},
    );
    expect(v.single, contains('빠짐 [name]'));
  });

  test('ICU 문법 오류를 언어와 키로 알려 준다', () {
    final v = arbViolations(
      {
        'ko': ko,
        'zh': {'cards': '{count, plural, one{{count}张}}'},
      },
      launched: {'ko'},
    );
    expect(v.single, startsWith('[zh] cards:'));
    expect(v.single, contains('other'));
  });

  test('템플릿 언어가 없으면 그것부터 알린다', () {
    expect(arbViolations({'en': {}}, launched: {}).single, contains('템플릿'));
  });
}
```

`client/test/l10n/arb_loading_test.dart`:

```dart
import 'dart:io';
import '../helpers/arb_parity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('arb'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('loadArbSet: 메타데이터 키를 빼고 읽는다', () {
    File(
      '${tmp.path}/app_ko.arb',
    ).writeAsStringSync('{"@@locale":"ko","a":"가","@a":{"description":"x"}}');
    File('${tmp.path}/app_en.arb').writeAsStringSync('{"a":"A"}');
    File('${tmp.path}/notes.txt').writeAsStringSync('무시');
    final set = loadArbSet(tmp);
    expect(set.keys.toSet(), {'ko', 'en'});
    expect(set['ko'], {'a': '가'});
  });

  test('loadArbSet: 깨진 JSON 은 파일 이름을 알린다', () {
    File('${tmp.path}/app_ja.arb').writeAsStringSync('{"a": }');
    expect(
      () => loadArbSet(tmp),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'm',
          contains('app_ja.arb'),
        ),
      ),
    );
  });

  test('loadArbSet: 문자열이 아닌 값', () {
    File('${tmp.path}/app_es.arb').writeAsStringSync('{"a": 3}');
    expect(() => loadArbSet(tmp), throwsA(isA<FormatException>()));
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd client && flutter test test/l10n/arb_parity_rules_test.dart test/l10n/arb_loading_test.dart`
Expected: FAIL — 컴파일 오류 `Not found: '../helpers/arb_parity.dart'`

- [ ] **Step 3: 규칙 라이브러리를 만든다**

`client/test/helpers/arb_parity.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'icu_message_check.dart';

/// 언어 코드 → (ARB 키 → 문구). `@` 로 시작하는 메타데이터 키는 담지 않는다.
typedef ArbSet = Map<String, Map<String, String>>;

/// `lib/l10n/app_<code>.arb` 를 모두 읽는다.
///
/// JSON 이 깨졌거나 값이 문자열이 아니면 [FormatException] 으로 파일 이름을 알린다 —
/// 번역가가 쉼표 하나를 빠뜨려도 어느 파일인지 바로 보이게 한다.
ArbSet loadArbSet(Directory dir) {
  final set = <String, Map<String, String>>{};
  final fileRe = RegExp(r'^app_([a-z]{2})\.arb$');
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    final match = fileRe.firstMatch(name);
    if (match == null) continue;
    final Object? json;
    try {
      json = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      throw FormatException('$name 이 올바른 JSON 이 아니다: ${e.message}');
    }
    if (json is! Map<String, dynamic>) {
      throw FormatException('$name 의 최상위가 객체가 아니다');
    }
    final messages = <String, String>{};
    json.forEach((key, value) {
      if (key.startsWith('@')) return;
      if (value is! String) {
        throw FormatException('$name 의 "$key" 값이 문자열이 아니다');
      }
      messages[key] = value;
    });
    set[match.group(1)!] = messages;
  }
  return set;
}

/// 번역 파일 규칙을 어긴 곳을 문장 목록으로 돌려준다. 비어 있으면 통과다.
///
/// - 모든 언어: 템플릿(ko)에 없는 키 금지 · 빈 값 금지 · ICU 문법 · 자리표시자 이름이 ko 와 같다
/// - 켜진 언어([launched]): 키가 ko 와 정확히 같다(빠진 키 금지)
///
/// 켜지지 않은 언어는 **키를 빼는 것**은 허용하지만 **빈 값은 안 된다.** 빈 문자열은
/// 대체 문구(`en` → `ko`)로 떨어지지 않고 화면에 빈 글자로 그려지기 때문이다.
List<String> arbViolations(
  ArbSet byLocale, {
  required Set<String> launched,
  String template = 'ko',
}) {
  final out = <String>[];
  final base = byLocale[template];
  if (base == null) return ['템플릿 언어($template) 번역 파일이 없다'];

  final baseHolders = <String, Set<String>>{};
  base.forEach((key, value) {
    final report = checkIcuMessage(value);
    baseHolders[key] = report.placeholders;
    for (final e in report.errors) {
      out.add('[$template] $key: $e');
    }
    if (value.trim().isEmpty) out.add('[$template] $key: 값이 비어 있다');
  });

  for (final entry in byLocale.entries) {
    final code = entry.key;
    if (code == template) continue;
    final messages = entry.value;

    for (final key in messages.keys) {
      if (!base.containsKey(key)) out.add('[$code] $key: $template 에 없는 키다');
    }
    if (launched.contains(code)) {
      for (final key in base.keys) {
        if (!messages.containsKey(key)) {
          out.add('[$code] $key: 켜진 언어인데 번역이 없다');
        }
      }
    }
    messages.forEach((key, value) {
      if (value.trim().isEmpty) {
        out.add('[$code] $key: 값이 비어 있다');
        return;
      }
      final report = checkIcuMessage(value);
      for (final e in report.errors) {
        out.add('[$code] $key: $e');
      }
      final expected = baseHolders[key];
      if (report.isValid && expected != null) {
        final missing = expected.difference(report.placeholders);
        final extra = report.placeholders.difference(expected);
        if (missing.isNotEmpty || extra.isNotEmpty) {
          out.add(
            '[$code] $key: 자리표시자가 $template 와 다르다 '
            '(빠짐 ${missing.toList()..sort()}, 더함 ${extra.toList()..sort()})',
          );
        }
      }
    });
  }
  return out;
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/arb_parity_rules_test.dart test/l10n/arb_loading_test.dart && flutter analyze test/helpers test/l10n`
Expected: PASS — 규칙 8건 + 읽기 3건, analyze `No issues found!`

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/test/helpers/arb_parity.dart client/test/l10n/arb_parity_rules_test.dart client/test/l10n/arb_loading_test.dart
```

---

## Task 4: 실제 번역 파일 검사 테스트

**Files:**
- Create or Overwrite: `client/test/l10n/arb_parity_test.dart` (계획 1 이 골격을 만들었으면 아래 내용으로 **덮어쓴다**)

**Interfaces:**
- Consumes: 계획 1 의 `client/lib/l10n/app_{ko,en,ja,zh,es}.arb`, Task 1·3 의 헬퍼
- Produces: CI 가 도는 번역 검사. 위반이 있으면 `[언어] 키: 이유` 목록을 한꺼번에 보여 준다.

- [ ] **Step 1: 계획 1 의 골격이 있는지 보고, 있으면 내용을 읽어 둔다**

Run: `ls client/lib/l10n client/test/l10n; sed -n 1,80p client/test/l10n/arb_parity_test.dart`
Expected: 골격이 있으면 그 파일의 검사 항목을 확인한다. 아래 파일이 **같은 항목을 모두 포함**하므로 덮어써도 된다(키 일치 · 자리표시자 · ICU · 빈 값). 골격에만 있는 검사가 있으면 Task 3 의 `arbViolations` 에 규칙으로 더하고 그 규칙 테스트를 먼저 쓴다.

- [ ] **Step 2: 실제 파일 테스트를 쓴다**

`client/test/l10n/arb_parity_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/arb_parity.dart';
import '../helpers/launched_locales.dart';

/// 실제 번역 파일(`lib/l10n/app_*.arb`)이 규칙을 지키는지 본다.
///
/// 규칙 자체는 `arb_parity_rules_test.dart` 가 가짜 데이터로 고정한다. 여기서는 진짜 파일을
/// 규칙에 통과시키기만 한다. 실패하면 위반 목록이 `[언어] 키: 이유` 로 한꺼번에 나온다.
///
/// 어느 언어가 '켜졌는지'는 `docs/i18n/launched-locales.txt` 가 정한다. 언어를 여는 PR 이 그 파일에
/// 코드를 더하면 그 순간부터 그 언어의 빠진 번역이 CI 를 막는다.
void main() {
  final arbDir = Directory('lib/l10n');

  test('번역 파일 다섯 개가 모두 있다', () {
    final set = loadArbSet(arbDir);
    expect(
      set.keys.toSet(),
      knownLocaleCodes.toSet(),
      reason: 'lib/l10n/app_<언어>.arb 가 ko en ja zh es 다섯 개여야 한다',
    );
  });

  test('번역 파일이 규칙을 지킨다', () {
    final violations = arbViolations(
      loadArbSet(arbDir),
      launched: readLaunchedLocales(),
    );
    expect(violations, isEmpty, reason: '\n${violations.join('\n')}');
  });
}
```

- [ ] **Step 3: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/arb_parity_test.dart`
Expected: PASS — 지금은 `ko` 만 켜져 있으므로 ko 의 ICU·빈 값과, 나머지 언어에 ko 에 없는 키나 빈 값이 없는지만 본다.

위반이 나오면 **번역 파일(ARB)을 고친다**(테스트를 느슨하게 만들지 않는다). 위반 종류별 고치는 법:

| 메시지 | 고치는 법 |
| --- | --- |
| `ko 에 없는 키다` | 오타이거나 ko 에서 지운 키다. 그 언어 파일에서 지운다 |
| `값이 비어 있다` | 번역이 없으면 빈 문자열로 두지 말고 **키를 지운다** |
| `자리표시자가 ko 와 다르다` | `{name}` 처럼 이름·철자가 ko 와 같아야 한다 |
| `other 분기가 없다` | `plural`·`select` 에는 `other{…}` 가 꼭 필요하다 |
| `켜진 언어인데 번역이 없다` | 그 언어를 켠 PR 이면 번역을 채운다. 아니면 `launched-locales.txt` 줄을 되돌린다 |

- [ ] **Step 4: 일부러 깨 보고 잡히는지 확인한다 (되돌린다)**

Run:
```bash
cd client
cp ../docs/i18n/launched-locales.txt /tmp/launched.bak
printf 'ko\nen\n' > ../docs/i18n/launched-locales.txt
flutter test test/l10n/arb_parity_test.dart
cp /tmp/launched.bak ../docs/i18n/launched-locales.txt
```
Expected: `en` 에 번역이 없는 키가 있으면 FAIL 하고 `[en] <키>: 켜진 언어인데 번역이 없다` 가 나온다(`en` 번역이 이미 완성돼 있으면 통과한다 — 그 경우 `launched-locales.txt` 를 되돌렸는지만 확인한다). 마지막 줄이 파일을 원래대로 돌린다.

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/test/l10n/arb_parity_test.dart
```

---

## Task 5: Flutter CI 에 번역 검사 연결

**Files:**
- Modify: `.github/workflows/PROJECT-FLUTTER-CI.yaml` (`analyze` 잡, `Run Flutter Analyze` 앞)

**Interfaces:**
- Consumes: 계획 1 의 `client/l10n.yaml`, Task 2~4·7·8·9 의 테스트 전부(`client/test/l10n/`)
- Produces: PR 마다 `Generate localizations` · `Check translations` 단계. 번역 PR 은 여기서 먼저 빨개진다.

기존 `Run Flutter Test` 단계(`flutter test --exclude-tags golden`)가 `test/l10n` 도 돌리므로 **검사가 빠지는 것은 아니다.** 이 단계를 따로 두는 이유는 두 가지다: 번역 PR 이 긴 테스트 로그 속에서 오류를 찾지 않게 맨 위에서 실패시키고, `gen-l10n` 이 ICU 오류를 만나면 생성 단계에서 멈춰 같은 오류를 일찍 알려 준다. 새 테스트 파일은 `golden` 태그가 없어 CI 에서 돈다.

- [ ] **Step 1: 지금 YAML 이 문법적으로 맞는지 확인한다 (기준선)**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/PROJECT-FLUTTER-CI.yaml', encoding='utf-8')); print('YAML OK')"`
Expected: `YAML OK`

- [ ] **Step 2: 단계를 더한다**

`.github/workflows/PROJECT-FLUTTER-CI.yaml` 의 아래 두 줄(analyze 잡 안, 한 번만 나온다)을

```yaml
      # Flutter Analyze 실행
      - name: Run Flutter Analyze
```

다음으로 바꾼다.

```yaml
      # 번역 파일 검사 (이슈 #521). 아래 전체 단위 테스트에도 같은 테스트가 들어 있지만,
      # 번역 PR 은 여기서 먼저 실패해야 어느 언어·키가 틀렸는지 로그 맨 위에서 바로 보인다.
      # gen-l10n 은 ICU 문법 오류를 만나면 생성 단계에서 멈춰 같은 오류를 일찍 알려 준다.
      - name: Generate localizations
        run: flutter gen-l10n

      - name: Check translations
        id: l10n_check
        run: |
          echo "🌐 번역 파일 검사 시작... (키·자리표시자·ICU·켜진 언어 누락·글자 넘침)"
          flutter test test/l10n
          echo "✅ 번역 파일 검사 완료"

      # Flutter Analyze 실행
      - name: Run Flutter Analyze
```

- [ ] **Step 3: YAML 문법과 단계 순서를 확인한다**

Run:
```bash
python3 - <<'EOF'
import yaml
d = yaml.safe_load(open('.github/workflows/PROJECT-FLUTTER-CI.yaml', encoding='utf-8'))
names = [s.get('name') for s in d['jobs']['analyze']['steps']]
print(names)
assert names.index('Generate localizations') < names.index('Check translations') < names.index('Run Flutter Analyze')
print('순서 OK')
EOF
```
Expected: 단계 목록에 `Generate localizations`, `Check translations` 가 `Install dependencies` 뒤 `Run Flutter Analyze` 앞에 있고 `순서 OK`

- [ ] **Step 4: 같은 두 명령을 로컬에서 돌려 본다**

Run: `cd client && flutter gen-l10n && flutter test test/l10n`
Expected: PASS. 단, `figma_ko_only_guard_test.dart` 는 계획 1 이 19개 시안 대조 테스트에 `Locale('ko')` 를 넣기 전에는 실패한다 — 그 전제는 Task 8 에 있다.

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add .github/workflows/PROJECT-FLUTTER-CI.yaml
```

---

## Task 6: 서버 번역 리소스 검사와 CI 워크플로

> 계획 2(서버 언어 기반)가 `MessageSource` 리소스 파일을 만든 뒤에 실행한다.

**Files:**
- Create: `server/src/test/java/com/chuseok22/elumserver/common/locale/I18nResourceParityTest.java`
- Create: `.github/workflows/PROJECT-ELUM-SERVER-I18N-CHECK.yaml`

**Interfaces:**
- Consumes: 계획 2 의 `server/src/main/resources/i18n/messages_{ko,en,ja,zh,es}.properties`(에러 문구, 키 = `ErrorCode` 이름)와 `routine-phrases_{ko,en,ja,zh,es}.properties`(폴백 질문·추천 목록, 한 파일이 "한 벌"), 계획 2 의 `ErrorMessageParityTest` · `RoutinePhrasesParityTest` · `RoutinePhrasesStartupGuardTest`, Task 1 의 `docs/i18n/launched-locales.txt`
- Produces: 서버 번역 파일 검사(키·인자·빈 값·작은따옴표), 이를 계획 2 의 번역 리소스 검사와 함께 PR 에서 돌리는 워크플로

계획 2 와 맞춘 것(계획 2 문서를 읽고 확인했다 — 계획 2 가 바뀌면 이 Task 의 상수·이름만 고친다):

1. 번역 리소스는 `src/main/resources/i18n/<묶음>_<언어코드>.properties` 이고 묶음은 `messages`(에러 문구)와 `routine-phrases`(폴백 질문·추천)다. 아래 테스트는 폴더 안의 모든 묶음을 훑는다. 계획 2 가 처음 만드는 `en` `ja` `zh` `es` 파일은 **머리 주석만** 있어(키 없음) 지금은 통과한다 — 번역이 채워지면서 규칙이 작동한다.
2. 계획 2 에는 이미 번역 리소스 테스트가 있다: `ErrorMessageParityTest`(ko 문구·상태가 이전과 같음을 golden 으로 고정) · `RoutinePhrasesParityTest` · `RoutinePhrasesStartupGuardTest`("한 벌" 규칙과 기동 검사). **그 테스트들은 이름에 `I18n` 이 없어** 아래 워크플로가 이름으로 따로 넣는다. 계획 2 의 테스트 이름이 바뀌면 워크플로의 `--tests` 목록도 바꾼다(하나도 안 맞으면 Gradle 이 실패한다). 그 테스트가 스프링 컨텍스트나 DB 를 띄워 CI 에서 못 돈다면 목록에서 빼고 이유를 워크플로 주석에 적는다.

이 계획의 테스트가 더하는 것: 계획 2 는 ko 를 기준으로 고정하고 "한 벌"을 검사하지만 **언어 간 인자(`{0}`) 일치와 작은따옴표 오류, 빈 값**은 보지 않는다.

서버 규칙은 클라이언트와 같다. 추가로 `MessageFormat` 의 함정을 잡는다: 작은따옴표 하나(`don't {0}`)가 뒤의 `{0}` 을 통째로 삼킨다. 영어권 번역가가 가장 자주 내는 오류다.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`server/src/test/java/com/chuseok22/elumserver/common/locale/I18nResourceParityTest.java`:

```java
package com.chuseok22.elumserver.common.locale;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.text.MessageFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * 서버 번역 리소스(`i18n/<묶음>_<언어>.properties`)가 규칙을 지키는지 본다.
 *
 * <p>스프링을 띄우지 않고 파일만 읽는다 — DB 나 비밀 설정 없이 CI 에서 돈다.
 * 규칙은 클라이언트 ARB 검사와 같다: ko 가 기준이고, 켜진 언어는 키가 빠지면 안 되며,
 * 모든 언어에서 빈 값 금지·인자({@code {0}}) 일치.
 *
 * <p>MessageFormat 은 작은따옴표를 따옴표로 읽는다. 번역에 {@code don't {0}} 처럼 하나만 쓰면
 * 뒤의 {@code {0}} 이 통째로 사라진다. 영어·프랑스어권 번역가가 가장 자주 내는 오류라 따로 잡는다.
 *
 * <p>켜진 언어는 레포 루트 {@code docs/i18n/launched-locales.txt} 가 정한다(서버 DB 설정은 CI 가 못 본다).
 */
class I18nResourceParityTest {

  /** 서버 번역 리소스 위치. 계획 2 가 다른 경로를 쓰면 이 한 줄만 바꾼다. */
  private static final Path I18N_DIR = Path.of("src/main/resources/i18n");

  private static final Path LAUNCHED_FILE = Path.of("../docs/i18n/launched-locales.txt");
  private static final Set<String> KNOWN = Set.of("ko", "en", "ja", "zh", "es");
  private static final Pattern FILE = Pattern.compile("^(.+)_(ko|en|ja|zh|es)\\.properties$");
  private static final Pattern ARG = Pattern.compile("\\{(\\d+)(?:,[^}]*)?}");

  @Test
  @DisplayName("실제 번역 리소스가 규칙을 지킨다")
  void realBundlesFollowRules() throws IOException {
    assertThat(I18N_DIR).as("번역 리소스 폴더(계획 2 가 만든다)").isDirectory();

    List<String> violations = violations(I18N_DIR, readLaunched(LAUNCHED_FILE));

    assertThat(violations).as("\n" + String.join("\n", violations)).isEmpty();
  }

  @Test
  @DisplayName("켜진 언어 파일을 읽고, 없거나 ko 가 빠지면 실패한다")
  void readsLaunchedFile(@TempDir Path tmp) throws IOException {
    Path file = tmp.resolve("launched.txt");
    Files.writeString(file, "# 주석\nko\n\nen\n");
    assertThat(readLaunched(file)).containsExactlyInAnyOrder("ko", "en");

    Files.writeString(file, "en\n");
    org.assertj.core.api.Assertions.assertThatThrownBy(() -> readLaunched(file))
      .hasMessageContaining("ko");
    Files.writeString(file, "ko\nfr\n");
    org.assertj.core.api.Assertions.assertThatThrownBy(() -> readLaunched(file))
      .hasMessageContaining("fr");
    org.assertj.core.api.Assertions.assertThatThrownBy(() -> readLaunched(tmp.resolve("none.txt")))
      .isInstanceOf(IllegalStateException.class);
  }

  @Test
  @DisplayName("규칙이 위반을 실제로 잡는다")
  void rulesCatchViolations(@TempDir Path dir) throws IOException {
    write(dir, "errors_ko.properties", "A=안녕\nB={0}님 환영해요\nC=값\n");
    write(dir, "errors_en.properties", "A=Hello\nB=Welcome {1}\nD=extra\nC=\n");
    write(dir, "errors_es.properties", "A=Hola\n");
    write(dir, "errors_ja.properties", "A=こんにちは\nB=Don't {0}\n");

    // en 과 es 를 켠다: es 는 B·C 가 빠졌다
    List<String> v = violations(dir, Set.of("ko", "en", "es"));
    String all = String.join("\n", v);

    assertThat(all).contains("[errors/en] D: ko 에 없는 키");
    assertThat(all).contains("[errors/en] B: 인자가 ko 와 다르다");
    assertThat(all).contains("[errors/en] C: 값이 비어 있다");
    assertThat(all).contains("[errors/es] B: 켜진 언어인데 번역이 없다");
    assertThat(all).contains("[errors/es] C: 켜진 언어인데 번역이 없다");
    // ja 는 꺼져 있어 키가 빠진 것은 괜찮지만 작은따옴표가 {0} 을 삼키는 것은 잡는다
    assertThat(all).contains("[errors/ja] B: 작은따옴표");
    assertThat(all).doesNotContain("[errors/ja] C");
  }

  @Test
  @DisplayName("ko 파일이 없는 묶음은 위반이다")
  void missingKoIsViolation(@TempDir Path dir) throws IOException {
    write(dir, "errors_en.properties", "A=Hello\n");
    assertThat(violations(dir, Set.of("ko"))).anyMatch(s -> s.contains("errors") && s.contains("ko 파일이 없다"));
  }

  @Test
  @DisplayName("묶음이 하나도 없으면 위반이다")
  void emptyDirIsViolation(@TempDir Path dir) throws IOException {
    assertThat(violations(dir, Set.of("ko"))).isNotEmpty();
  }

  static List<String> violations(Path dir, Set<String> launched) throws IOException {
    // 묶음 이름 → (언어 → 속성)
    Map<String, Map<String, Properties>> bundles = new TreeMap<>();
    try (Stream<Path> files = Files.list(dir)) {
      for (Path path : (Iterable<Path>) files::iterator) {
        Matcher m = FILE.matcher(path.getFileName().toString());
        if (!m.matches()) {
          continue;
        }
        Properties props = new Properties();
        try (Reader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8)) {
          props.load(reader);
        }
        bundles.computeIfAbsent(m.group(1), k -> new TreeMap<>()).put(m.group(2), props);
      }
    }

    List<String> out = new ArrayList<>();
    if (bundles.isEmpty()) {
      out.add(dir + " 에 번역 리소스(<묶음>_<언어>.properties)가 하나도 없다");
      return out;
    }

    bundles.forEach((bundle, byLocale) -> {
      Properties ko = byLocale.get("ko");
      if (ko == null) {
        out.add("[" + bundle + "] ko 파일이 없다");
        return;
      }
      Set<String> koKeys = new TreeSet<>(ko.stringPropertyNames());
      byLocale.forEach((code, props) -> {
        String tag = "[" + bundle + "/" + code + "] ";
        Set<String> keys = new TreeSet<>(props.stringPropertyNames());
        if (!code.equals("ko")) {
          keys.stream().filter(k -> !koKeys.contains(k)).forEach(k -> out.add(tag + k + ": ko 에 없는 키다"));
          if (launched.contains(code)) {
            koKeys.stream().filter(k -> !keys.contains(k)).forEach(k -> out.add(tag + k + ": 켜진 언어인데 번역이 없다"));
          }
        }
        for (String key : keys) {
          String value = props.getProperty(key);
          if (value.isBlank()) {
            out.add(tag + key + ": 값이 비어 있다");
            continue;
          }
          checkFormat(tag, key, value, ko.getProperty(key), code.equals("ko"), out);
        }
      });
    });
    return out;
  }

  private static void checkFormat(String tag, String key, String value, String koValue, boolean isKo, List<String> out) {
    int rawArgs = argCount(value);
    int effectiveArgs;
    try {
      effectiveArgs = new MessageFormat(value).getFormatsByArgumentIndex().length;
    } catch (IllegalArgumentException e) {
      out.add(tag + key + ": MessageFormat 형식이 깨졌다 (" + e.getMessage() + ")");
      return;
    }
    if (effectiveArgs != rawArgs) {
      out.add(tag + key + ": 작은따옴표가 {0} 같은 인자를 삼킨다. 따옴표는 ''로 두 번 쓴다");
    }
    if (!isKo && koValue != null && argSet(value).equals(argSet(koValue)) == false) {
      out.add(tag + key + ": 인자가 ko 와 다르다 (ko " + argSet(koValue) + ", 여기 " + argSet(value) + ")");
    }
  }

  private static Set<Integer> argSet(String value) {
    Set<Integer> set = new TreeSet<>();
    Matcher m = ARG.matcher(value);
    while (m.find()) {
      set.add(Integer.parseInt(m.group(1)));
    }
    return set;
  }

  /** 글에 적힌 인자 개수 — {@code {2}} 만 있어도 0·1 자리를 포함해 3개로 센다(MessageFormat 과 같은 셈법). */
  private static int argCount(String value) {
    return argSet(value).stream().mapToInt(i -> i + 1).max().orElse(0);
  }

  static Set<String> readLaunched(Path file) throws IOException {
    if (!Files.exists(file)) {
      throw new IllegalStateException(file + " 가 없다. 켜진 언어 게이트 파일이 지워졌다.");
    }
    Set<String> codes = new TreeSet<>();
    for (String line : Files.readAllLines(file, StandardCharsets.UTF_8)) {
      String t = line.trim();
      if (t.isEmpty() || t.startsWith("#")) {
        continue;
      }
      if (!KNOWN.contains(t)) {
        throw new IllegalStateException(file + " 에 모르는 언어 코드가 있다: " + t);
      }
      codes.add(t);
    }
    if (!codes.contains("ko")) {
      throw new IllegalStateException(file + " 에 ko 가 없다. ko 는 늘 켜져 있어야 한다.");
    }
    return codes;
  }

  private static void write(Path dir, String name, String content) throws IOException {
    Files.writeString(dir.resolve(name), content, StandardCharsets.UTF_8);
  }
}
```

- [ ] **Step 2: 번역 리소스 폴더 위치를 계획 2 결과와 맞춘다**

Run: `ls server/src/main/resources/i18n/ && grep -n "I18N_DIR" server/src/test/java/com/chuseok22/elumserver/common/locale/I18nResourceParityTest.java`
Expected: `messages_ko.properties` · `routine-phrases_ko.properties` 와 나머지 언어 파일이 보인다. 폴더 이름이 다르면 `I18N_DIR` 상수를 그 경로로 고친다.

- [ ] **Step 3: 테스트를 돌린다**

Run: `cd server && ./gradlew test --tests '*I18nResourceParityTest'`
Expected: PASS — 5건(`realBundlesFollowRules` 포함). 위반이 있으면 메시지가 `[묶음/언어] 키: 이유` 로 나온다. **번역 파일을 고친다**(테스트를 느슨하게 만들지 않는다).

- [ ] **Step 4: 일부러 깨 보고 잡히는지 확인한다 (되돌린다)**

Run:
```bash
cd server
cp ../docs/i18n/launched-locales.txt /tmp/launched.bak
printf 'ko\nen\n' > ../docs/i18n/launched-locales.txt
./gradlew test --tests '*I18nResourceParityTest'
cp /tmp/launched.bak ../docs/i18n/launched-locales.txt
```
Expected: `en` 번역이 아직 없으면 FAIL 하고 `켜진 언어인데 번역이 없다` 가 나온다. 마지막 줄이 파일을 되돌린다.

- [ ] **Step 5: 워크플로를 만든다**

`.github/workflows/PROJECT-ELUM-SERVER-I18N-CHECK.yaml`:

```yaml
# ===================================================================
# 서버 번역 리소스 검사 (이슈 #521 · 하위 계획 5)
# ===================================================================
#
# 서버가 내려보내는 문장(에러 문구·AI 폴백 질문·추천 목록)의 언어별 파일이 어긋나지 않는지 본다.
# 서버 배포 워크플로(PROJECT-SPRING-CICD)는 `-x test` 로 빌드하고 서버 테스트를 돌리는 워크플로가
# 따로 없어서, 번역 검사를 여기서 맡는다.
#
# 무엇을 보나
# - 언어 간 키 일치 · 인자({0}) 일치 · 빈 값 금지 · 작은따옴표가 인자를 삼키는 오류
# - 폴백 문구 파일이 한 언어라도 비면 서버가 뜨지 않는 기동 검사(계획 2)
#
# 어떤 테스트를 도나: 클래스 이름에 `I18n` 이 든 것(이 계획의 파일 검사)과, 계획 2 가 만든
# 번역 리소스 검사(ErrorMessageParityTest · RoutinePhrasesParityTest · RoutinePhrasesStartupGuardTest).
# 테스트 이름이 바뀌어 하나도 안 맞으면 Gradle 이 실패하므로 조용히 통과하지 않고 빨개진다.
# ===================================================================

name: PROJECT-ELUM-SERVER-I18N-CHECK

on:
  pull_request:
    branches: [develop]
    paths:
      - 'server/src/main/resources/i18n/**'
      - 'server/src/test/resources/i18n/**'
      - 'server/src/test/java/**/I18n*'
      - 'server/src/test/java/**/ErrorMessageParityTest.java'
      - 'server/src/test/java/**/RoutinePhrases*'
      - 'docs/i18n/launched-locales.txt'
      - '.github/workflows/PROJECT-ELUM-SERVER-I18N-CHECK.yaml'
  push:
    branches: [develop]
    paths:
      - 'server/src/main/resources/i18n/**'
      - 'server/src/test/resources/i18n/**'
      - 'server/src/test/java/**/I18n*'
      - 'server/src/test/java/**/ErrorMessageParityTest.java'
      - 'server/src/test/java/**/RoutinePhrases*'
      - 'docs/i18n/launched-locales.txt'
      - '.github/workflows/PROJECT-ELUM-SERVER-I18N-CHECK.yaml'
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: server-i18n-${{ github.ref }}
  cancel-in-progress: true

jobs:
  i18n:
    name: 서버 번역 리소스 검사
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: server

    steps:
      - name: 코드 체크아웃
        uses: actions/checkout@v4

      - name: JDK 설정
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: 'gradle'

      - name: Gradle Wrapper 실행권한 부여
        run: chmod +x gradlew

      # 스프링 컨텍스트를 띄우지 않는 파일 검사라 DB·비밀 설정이 필요 없다.
      - name: 번역 리소스와 폴백 파일 검사
        run: >-
          ./gradlew test
          --tests '*I18n*'
          --tests '*ErrorMessageParityTest'
          --tests '*RoutinePhrasesParityTest'
          --tests '*RoutinePhrasesStartupGuardTest'
```

- [ ] **Step 6: YAML 문법을 확인하고, 워크플로가 돌리는 명령을 로컬에서 그대로 돌린다**

Run:
```bash
python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/PROJECT-ELUM-SERVER-I18N-CHECK.yaml', encoding='utf-8')); print(list(d['jobs']))"
cd server && ./gradlew test --tests '*I18n*' --tests '*ErrorMessageParityTest' --tests '*RoutinePhrasesParityTest' --tests '*RoutinePhrasesStartupGuardTest'
```
Expected: `['i18n']`, 그리고 위 네 패턴에 걸리는 테스트(이 계획의 `I18nResourceParityTest` 5건 + 계획 2 의 세 클래스)가 모두 PASS. 하나도 안 걸리면 Gradle 이 `No tests found` 로 실패한다.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add server/src/test/java/com/chuseok22/elumserver/common/locale/I18nResourceParityTest.java .github/workflows/PROJECT-ELUM-SERVER-I18N-CHECK.yaml
```

---

## Task 7: `pumpWithLocale` 와 넘침 검사 하네스

**Files:**
- Create (계획 1 이 이미 만들었으면 **읽고 아래 계약에 맞게 고친다**): `client/test/helpers/pump_with_locale.dart`
- Test: `client/test/l10n/pump_with_locale_test.dart`
- Create: `client/test/l10n/locale_overflow_test.dart`

**Interfaces:**
- Consumes: C4 의 `AppLocalizations`(`package:elum/l10n/app_localizations.dart`), `supportedAppLocales`(`package:elum/core/l10n/app_locales.dart`), 기존 `useFigmaViewport`, `testStorageOverride`, `flutter_test_config.dart`(넘침을 예외로 던진다)
- Produces: `Future<int> pumpWithLocale(WidgetTester, Widget, {required Locale locale, double textScale, List<Override> overrides, String path, bool failOnOverflow})`(돌려주는 값은 이번 pump 의 넘침 횟수), `List<String> truncatedParagraphs(WidgetTester)`

**실측한 사실 (이 Task 를 이렇게 만든 이유).** 계획 1 이전 코드에 대역 지역화를 입혀 대표 화면 일곱 개를 `ko` 로 1.0·1.5·2.0배 띄워 보았다(테스트 환경 글꼴 기준). `ko` 인데도 **역할 선택(2.0배)·약관 동의(1.5·2.0배)·연결 암호 넣기(1.5·2.0배)가 이미 넘친다.** 번역과 무관한 기존 결함이다. 그래서 절대 기준("넘치면 실패")으로 걸면 번역 PR 이 기존 결함에 막힌다. 이 하네스는 **ko 를 기준선으로 삼아 다른 언어가 더 나빠지는 것만** 실패로 본다. 기존 결함은 이 계획에서 고치지 않고 이슈로 따로 올린다(구현 보고서에 목록을 남긴다).

- [ ] **Step 1: 계획 1 이 헬퍼를 이미 만들었는지 본다**

Run: `ls client/test/helpers/pump_with_locale.dart 2>&1; grep -rn "pumpWithLocale" client/test | head`
Expected: 없으면 Step 3 에서 아래 파일을 그대로 만든다. 있으면 그 파일을 읽고, 아래 계약(`failOnOverflow` 와 정수 반환, `truncatedParagraphs`)이 없을 때만 더한다. 기존 호출부(`await pumpWithLocale(...)`)는 반환값을 무시하므로 깨지지 않는다.

- [ ] **Step 2: 실패하는 양성 대조 테스트를 먼저 쓴다**

하네스가 **실제로 넘침과 잘림을 잡는지** 확인하는 테스트다. 이게 없으면 하네스가 고장 나 늘 0 을 돌려줘도 넘침 검사가 초록불이다.

`client/test/l10n/pump_with_locale_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

/// 넘침 검사 하네스가 **실제로 넘침과 잘림을 잡는지** 양성 대조로 확인한다.
///
/// 이 확인이 없으면 하네스가 고장 나 늘 0 을 돌려줘도 `locale_overflow_test` 는 초록불이다.
void main() {
  useFigmaViewport();

  const ko = Locale('ko');

  testWidgets('좁은 상자에 긴 글을 넣은 Row 의 넘침을 센다', (tester) async {
    final overflows = await pumpWithLocale(
      tester,
      const Scaffold(body: Row(children: [SizedBox(width: 400, height: 20)])),
      locale: ko,
      failOnOverflow: false,
    );
    expect(overflows, greaterThan(0));
  });

  testWidgets('넘치지 않으면 0 이다', (tester) async {
    final overflows = await pumpWithLocale(
      tester,
      const Scaffold(body: Text('짧은 글')),
      locale: ko,
      failOnOverflow: false,
    );
    expect(overflows, 0);
  });

  testWidgets('failOnOverflow 기본값은 넘침을 실패로 흘려 보낸다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(body: Row(children: [SizedBox(width: 400, height: 20)])),
      locale: ko,
    );
    // 기본 설정은 넘침을 예외로 바꾸므로, 여기서 꺼내 확인하고 비운다.
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('말줄임으로 잘린 문단을 찾는다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(
        body: SizedBox(
          width: 80,
          child: Text(
            'Esta frase es demasiado larga para una sola línea',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      locale: ko,
    );
    expect(truncatedParagraphs(tester), hasLength(1));
  });
}
```

Run: `cd client && flutter test test/l10n/pump_with_locale_test.dart`
Expected: FAIL — 컴파일 오류 `Not found: '../helpers/pump_with_locale.dart'`(Step 1 에서 이미 있으면 `failOnOverflow`·`truncatedParagraphs` 미정의 오류)

- [ ] **Step 3: 헬퍼를 만든다**

`client/test/helpers/pump_with_locale.dart`:

```dart
import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 화면 하나를 **지정한 언어·글자 배율**로 띄운다.
///
/// 언어마다 문장 길이가 달라 고정 폭·고정 높이 위젯이 넘치는지 보려는 용도다
/// (넘침은 `test/flutter_test_config.dart` 가 자동으로 테스트 실패로 바꾼다).
/// 화면이 `context.push` 로 다음 화면을 여는 경우가 있어 라우터를 한 겹 깐다.
///
/// [overrides] 에는 화면이 읽는 저장소·리포지토리 대역을 넣는다.
/// [textScale] 은 시스템 글자 크기다 — 50대 보호자가 켜 두는 1.5~2.0 을 본다.
///
/// 돌려주는 값은 이번 pump 에서 보고된 **넘침 횟수**다. [failOnOverflow] 를 끄면 넘침을 실패로
/// 만들지 않고 세기만 한다 — 언어 간 비교(`locale_overflow_test`)가 ko 를 기준선으로 쓰려고 켠다.
Future<int> pumpWithLocale(
  WidgetTester tester,
  Widget screen, {
  required Locale locale,
  double textScale = 1.0,
  List<Override> overrides = const [],
  String path = '/under-test',
  bool failOnOverflow = true,
}) async {
  // 넘침 보고를 가로채 센다. 기본은 그대로 흘려 보내 테스트를 실패시킨다.
  final original = FlutterError.onError;
  var overflows = 0;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) {
      overflows++;
      if (!failOnOverflow) return;
    }
    original?.call(details);
  };

  final router = GoRouter(
    initialLocation: path,
    routes: [GoRoute(path: path, builder: (_, _) => screen)],
  );
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            locale: locale,
            supportedLocales: supportedAppLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    // 끝나지 않는 애니메이션(오로라 등)이 있는 화면이 있어 pumpAndSettle 대신 시간을 정해 흘린다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  } finally {
    FlutterError.onError = original;
  }
  return overflows;
}

/// 글이 `maxLines` 에 걸려 잘린 문단을 모은다.
///
/// 넘침(RenderFlex overflow)은 예외로 잡히지만 **말줄임(…)으로 잘리는 것은 조용하다.**
/// 번역이 길어져 글이 말줄임으로 사라져도 테스트가 초록불이라 따로 센다.
List<String> truncatedParagraphs(WidgetTester tester) {
  final out = <String>[];
  // 상위 Element 마다 같은 RenderObject 를 돌려주므로 중복을 걷는다.
  for (final object in tester.allRenderObjects.toSet()) {
    if (object is RenderParagraph && object.didExceedMaxLines) {
      out.add(object.text.toPlainText());
    }
  }
  return out;
}
```

- [ ] **Step 4: 양성 대조 테스트 통과를 확인한다**

Run: `cd client && flutter test test/l10n/pump_with_locale_test.dart && flutter analyze test/helpers test/l10n`
Expected: PASS — 4건, analyze `No issues found!`

- [ ] **Step 5: 넘침 검사 테스트를 쓴다**

대표 화면은 **고정 폭·고정 높이 위젯이 많아 번역이 길어지면 먼저 깨지는 곳**으로 골랐고, 모두 기존 위젯 테스트가 이미 같은 대역으로 띄우는 화면이다(로그인 · 역할 선택 · 약관 동의 · 이름 · 도움 목표 · 비밀암호 · 연결 암호 넣기). 화면을 더하려면 `_cases()` 에 한 줄을 더한다. 화면의 문구가 ARB 에서 나오므로(계획 1) 언어를 바꾸면 실제 번역 길이로 레이아웃이 다시 잡힌다.

`client/test/l10n/locale_overflow_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/consent_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/presentation/consent_screen.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:elum/features/auth/presentation/role_select_screen.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/presentation/link_enter_screen.dart';
import 'package:elum/features/onboarding/presentation/goals_screen.dart';
import 'package:elum/features/onboarding/presentation/name_screen.dart';
import 'package:elum/features/onboarding/presentation/pin_screen.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';

/// 화면 몇 개를 **5개 언어 × 큰 글자**로 띄워 넘치거나 잘리지 않는지 본다.
///
/// 시안 대조(`figma_conformance_test`)는 ko 에만 적용하므로, 다른 언어는 "넘치지 않는다"만 이
/// 테스트가 지킨다(스펙 6장). 넘침은 `flutter_test_config.dart` 가 예외로 바꿔 주고, 말줄임으로
/// 잘리는 것은 [truncatedParagraphs] 로 센다.
///
/// 대표 화면은 **고정 폭·고정 높이 위젯이 많아 번역이 길어지면 먼저 깨지는 곳**으로 골랐다.
/// 로그인(버튼 문구), 역할 선택(카드 두 장), 약관(체크 줄), 이름·목표(입력과 칩), 비밀암호(안내 문구),
/// 연결 암호 넣기(이룸이가 쓰는 화면). 화면을 더하려면 아래 [_cases] 에 한 줄을 더한다.
///
/// 한계 — 일본어·중국어는 테스트 환경 글꼴로 폭을 잰다. 실제 글꼴이 다르면 폭도 다르므로
/// 이 테스트는 **필요조건**이고, 마지막 확인은 실기기 스크린샷이다(언어 오픈 체크리스트).
void main() {
  useFigmaViewport();

  const scales = [1.0, 1.5, 2.0];
  final others = supportedAppLocales.where((l) => l.languageCode != 'ko');

  for (final screen in _cases()) {
    group(screen.name, () {
      for (final scale in scales) {
        testWidgets('글자 $scale 배 — ko 보다 나빠지지 않는다', (tester) async {
          // 기준선: ko. ko 가 이미 넘치는 화면은 번역 탓이 아니므로, 다른 언어는 ko 보다
          // **더 나빠지는 것만** 실패로 본다. 기준선 자체의 결함은 따로 이슈로 올린다.
          Future<(int, int)> measure(Locale locale) async {
            final overflows = await pumpWithLocale(
              tester,
              screen.build(),
              locale: locale,
              textScale: scale,
              overrides: screen.overrides(),
              failOnOverflow: false,
            );
            return (overflows, truncatedParagraphs(tester).length);
          }

          final (koOverflows, koTruncated) = await measure(const Locale('ko'));

          final problems = <String>[];
          for (final locale in others) {
            final (overflows, truncated) = await measure(locale);
            if (overflows > koOverflows) {
              problems.add(
                '${locale.toLanguageTag()}: 레이아웃이 ko 보다 더 넘친다 '
                '($overflows곳, ko $koOverflows곳)',
              );
            }
            if (truncated > koTruncated) {
              problems.add(
                '${locale.toLanguageTag()}: 글이 ko 보다 더 잘린다 '
                '($truncated곳, ko $koTruncated곳)',
              );
            }
          }
          expect(problems, isEmpty, reason: '${screen.name} · 글자 $scale 배');
        });
      }
    });
  }
}

/// 검사할 화면 한 칸.
class _Case {
  const _Case(this.name, this.build, {this.overrides = _noOverrides});

  final String name;
  final Widget Function() build;
  final List<Override> Function() overrides;
}

List<Override> _noOverrides() => const [];

List<_Case> _cases() => [
  _Case('로그인', () {
    LoginScreen.debugPretendIos = true;
    addTearDown(() => LoginScreen.debugPretendIos = null);
    return const LoginScreen();
  }, overrides: () => [testStorageOverride()]),
  _Case(
    '역할 선택',
    () => const RoleSelectScreen(),
    overrides: () => [testStorageOverride()],
  ),
  _Case(
    '약관 동의',
    () => const ConsentScreen(),
    overrides: () => [
      testStorageOverride(),
      consentRepositoryProvider.overrideWithValue(_NoopConsent()),
      consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
    ],
  ),
  _Case(
    '이름',
    () => const NameScreen(),
    overrides: () => [testStorageOverride()],
  ),
  _Case(
    '도움 목표',
    () => const GoalsScreen(),
    overrides: () => [testStorageOverride()],
  ),
  _Case(
    '비밀암호',
    () => const PinScreen(),
    overrides: () => [testStorageOverride()],
  ),
  _Case(
    '연결 암호 넣기',
    () => const LinkEnterScreen(),
    overrides: () => [
      deviceLinkRepositoryProvider.overrideWithValue(_NoopLink()),
    ],
  ),
];

/// 동의 저장을 삼키는 대역 — 이 테스트는 글자 배치만 본다.
class _NoopConsent extends ConsentRepository {
  _NoopConsent() : super(dio: Dio());

  @override
  Future<AppFailure?> agree({
    required Set<String> agreedKeys,
    required String version,
  }) async => null;
}

class _NoopLink extends DeviceLinkRepository {
  _NoopLink()
    : super(
        dio: Dio(),
        tokens: InMemoryTokenStore(),
        storage: InMemoryStorage(),
      );
}
```

- [ ] **Step 6: 돌려서 통과를 확인한다**

Run: `cd client && flutter test test/l10n/locale_overflow_test.dart`
Expected: PASS — 화면 7개 × 글자 배율 3 = 21건. 번역이 아직 없는 언어는 대체 문구(ko)로 그려지므로 ko 와 같아 통과한다. 번역이 채워져 길어지면 이 테스트가 `[es] ... ko 보다 더 넘친다` 로 알려 준다.

실패하면 고치는 순서: ① 문구를 줄일 수 있으면 번역을 줄인다 ② 위젯이 고정 폭이면 줄바꿈·`Flexible` 로 고친다(`ko` 화면이 픽셀로 같아야 한다 — 시안 대조 테스트가 지킨다) ③ 도저히 안 되면 개발 담당과 상의한다.

- [ ] **Step 7: 한계가 테스트 주석과 체크리스트에 적혀 있는지 확인한다**

일본어·중국어는 테스트 환경 글꼴로 폭을 잰다. 실제 글꼴(계획 1 의 폰트 fallback)과 다르면 폭도 다르다. 이 테스트는 **필요조건**이고 마지막 확인은 실기기 스크린샷이다.

Run: `grep -n "필요조건" client/test/l10n/locale_overflow_test.dart && grep -n "실기기 스크린샷" docs/i18n/language-launch-checklist.md`
Expected: 첫 grep 은 위 테스트 파일의 주석 한 줄을 찾는다. 두 번째 grep 은 Task 11 을 끝낸 뒤에 통과한다(그 전에는 파일이 없어 실패해도 된다).

- [ ] **Step 8: 커밋 (`/pro-commit`)**

```bash
git add client/test/helpers/pump_with_locale.dart client/test/l10n/pump_with_locale_test.dart client/test/l10n/locale_overflow_test.dart
```

---

## Task 8: 시안 대조는 ko 에만 — 가드 테스트와 문서

**Files:**
- Create: `client/test/l10n/figma_ko_only_guard_test.dart`
- Modify: `client/docs/figma-frames.md` (「대조 현황」 첫 문단)
- Modify: `client/tool/figma_diff.py` (모듈 독스트링 끝)

**Interfaces:**
- Consumes: 계획 1 이 `*_conformance_test.dart` 와 `*_golden_test.dart` 19개의 `MaterialApp` 에 `locale: const Locale('ko')` 를 넣었다는 전제
- Produces: 시안 대조 범위(ko 만)를 파일로 못 박는 가드, 문서의 범위 명시

**왜 가드가 필요한가.** 시안(Figma export)은 한국어로만 그려져 있다. 계획 1 이후 `MaterialApp` 에 지역화가 들어가면 `locale` 을 지정하지 않은 테스트는 테스트 환경 언어(`en_US`)를 따라가 영어 화면을 한글 시안과 맞대거나, 언어가 바뀐 줄 모르고 통과한다. 5개 언어의 픽셀 시안은 만들지 않으므로(스펙 6장) 이 범위를 테스트로 고정한다. 계획 1 이 지정 방식을 다르게 잡았다면(공용 헬퍼 등) 가드의 정규식 `Locale\(\s*'ko'\s*\)` 만 그에 맞게 바꾼다 — 가드의 목적은 "ko 로 고정돼 있다"는 사실을 파일에서 읽는 것이다.

- [ ] **Step 1: 실패하는 가드 테스트를 쓴다**

`client/test/l10n/figma_ko_only_guard_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 시안 대조·골든 테스트는 **ko 로 고정**한다(스펙 6장).
///
/// 시안(Figma export)은 한국어로만 그려져 있다. 이 테스트들이 기기 언어(테스트 환경은 en_US)를
/// 따라가면 영어 화면을 한국어 시안과 맞대서 전부 붉어지거나, 반대로 언어가 바뀐 줄 모르고
/// 통과한다. 다섯 언어의 픽셀 시안은 만들지 않으므로, 이 범위를 파일로 못 박는다.
///
/// 규칙: `*_conformance_test.dart` · `*_golden_test.dart` 중 `MaterialApp` 을 직접 띄우는
/// 파일은 `Locale('ko')` 를 지정해야 한다. 새 시안 대조 테스트를 더하면 여기서 바로 걸린다.
void main() {
  test('시안 대조·골든 테스트가 ko 로 고정돼 있다', () {
    final pattern = RegExp(r'_(conformance|golden)_test\.dart$');
    final ko = RegExp(r"Locale\(\s*'ko'\s*\)");

    final missing =
        Directory('test')
            .listSync()
            .whereType<File>()
            .where((f) => pattern.hasMatch(f.path))
            .where((f) {
              final text = f.readAsStringSync();
              return text.contains('MaterialApp') && !ko.hasMatch(text);
            })
            .map((f) => f.uri.pathSegments.last)
            .toList()
          ..sort();

    expect(
      missing,
      isEmpty,
      reason:
          "MaterialApp 에 locale: const Locale('ko') 를 지정해야 한다:\n"
          '${missing.join('\n')}',
    );
  });

  test('가드가 대상 파일을 실제로 찾는다', () {
    final found = Directory('test')
        .listSync()
        .whereType<File>()
        .where(
          (f) => RegExp(r'_(conformance|golden)_test\.dart$').hasMatch(f.path),
        )
        .length;
    // 파일명 규칙이 바뀌어 아무것도 못 찾으면 가드가 늘 초록불이 된다.
    expect(found, greaterThanOrEqualTo(10));
  });
}
```

- [ ] **Step 2: 실패(또는 통과)를 확인한다**

Run: `cd client && flutter test test/l10n/figma_ko_only_guard_test.dart`
Expected: 계획 1 이 시안 대조 테스트에 `Locale('ko')` 를 아직 넣지 않았다면 FAIL 하고 파일 이름 목록이 나온다(이 레포 `origin/develop` 기준 19개: `figma_conformance_test.dart`, `login_screen_golden_test.dart` 등). 계획 1 이 이미 넣었다면 PASS 한다. 두 번째 테스트(`가드가 대상 파일을 실제로 찾는다`)는 어느 쪽이든 통과해야 한다.

실패하면 **그 파일의 `MaterialApp` 에 `locale: const Locale('ko')` 를 더한다**(그 외 코드는 건드리지 않는다). 더한 뒤에는 해당 골든·시안 대조 테스트가 ko 에서 그대로 통과해야 한다:
`cd client && flutter test test/figma_conformance_test.dart <고친 파일>`

- [ ] **Step 3: 시안 대조 안내 문서에 범위를 적는다**

`client/docs/figma-frames.md` 에서 아래 두 줄을

```markdown
`대조` 칸이 ✅면 `test/figma_conformance_test.dart`가 그림으로 맞대본다.
빈 칸은 **아무도 확인하지 않는 화면**이다 — 어긋나도 드러나지 않는다.
```

다음으로 바꾼다.

```markdown
`대조` 칸이 ✅면 `test/figma_conformance_test.dart`가 그림으로 맞대본다.
빈 칸은 **아무도 확인하지 않는 화면**이다 — 어긋나도 드러나지 않는다.

> **시안 대조는 한국어(`ko`) 화면에만 적용한다 (#521).** 시안은 한국어로만 그려져 있고, 다섯 언어의
> 픽셀 시안은 만들지 않는다. `*_conformance_test.dart` · `*_golden_test.dart` 는 `Locale('ko')` 로
> 고정돼 있고 `test/l10n/figma_ko_only_guard_test.dart` 가 그것을 지킨다. 다른 언어는
> `test/l10n/locale_overflow_test.dart` 가 "ko 보다 더 넘치거나 잘리지 않는다"만 본다.
> 새 언어를 열 때는 시안을 새로 받지 않고 실기기 스크린샷으로 확인한다
> (`docs/i18n/language-launch-checklist.md`).
```

- [ ] **Step 4: 비교 도구 설명에 범위를 적는다**

`client/tool/figma_diff.py` 모듈 독스트링의 마지막 문단

```python
읽는 법 — `diff%`는 글자 안티에일리어싱 때문에 절대 0이 되지 않는다. 숫자 자체보다
**어디가 다른가**가 중요하므로, 임계를 넘은 덩어리를 좌표와 크기로 뽑아 준다.
덩어리가 글자 자리면 대개 무해하고, 덩어리가 도형·여백 자리면 실제로 틀린 것이다.
"""
```

을 다음으로 바꾼다.

```python
읽는 법 — `diff%`는 글자 안티에일리어싱 때문에 절대 0이 되지 않는다. 숫자 자체보다
**어디가 다른가**가 중요하므로, 임계를 넘은 덩어리를 좌표와 크기로 뽑아 준다.
덩어리가 글자 자리면 대개 무해하고, 덩어리가 도형·여백 자리면 실제로 틀린 것이다.

범위 — **한국어(`ko`) 렌더만 맞댄다.** 시안은 한국어로만 그려져 있어 다른 언어 렌더를 대면
글자 자리가 전부 붉어진다. 다른 언어는 시안 대조가 아니라 위젯 테스트(`test/l10n/`)가
"넘치거나 잘리지 않는다"만 본다 (#521).
"""
```

- [ ] **Step 5: 도구가 여전히 로드되는지 확인한다**

Run: `cd client && python3 -c "import ast,sys; ast.parse(open('tool/figma_diff.py', encoding='utf-8').read()); print('PY OK')" && flutter test test/l10n/figma_ko_only_guard_test.dart`
Expected: `PY OK`, 가드 테스트 PASS(Step 2 에서 고친 뒤)

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add client/test/l10n/figma_ko_only_guard_test.dart client/docs/figma-frames.md client/tool/figma_diff.py
```

(Step 2 에서 `MaterialApp` 을 고친 테스트 파일이 있으면 그 경로도 명시해 더한다.)

---

## Task 9: 용어집과 형식 검사

**Files:**
- Create: `docs/i18n/glossary.md`
- Test: `client/test/l10n/glossary_format_test.dart`

**Interfaces:**
- Consumes: 루트 `CLAUDE.md` 용어 규칙, `docs/08-design-principles.md` 3장, Task 1 의 `readLaunchedLocales`
- Produces: 번역가·검수자·AI 초안이 따르는 용어집. 형식 규칙을 테스트가 지킨다.

용어집은 사람이 채운다. **빈 칸은 허용한다.** 대신 두 규칙을 테스트가 건다: `확정` 줄은 네 언어 칸이 모두 차 있고, **켜진 언어의 칸은 모든 줄에서 차 있으며 `결정필요` 줄이 남아 있지 않다.** 용어집이 비어 있는 채로, 또는 `이룸이`를 어떻게 부를지 정하지 않은 채로 언어를 열 수 없게 하는 장치다.

`이룸이` 를 번역할지 고유명사로 둘지는 **결정 항목**이다(표의 `결정필요`). 이 계획이 정하지 않는다.

- [ ] **Step 1: 실패하는 형식 테스트를 먼저 쓴다**

`client/test/l10n/glossary_format_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/launched_locales.dart';

/// `docs/i18n/glossary.md` 의 용어표가 형식을 지키는지 본다.
///
/// 번역 값은 사람이 채우므로 **빈 칸은 허용**한다. 대신 두 가지를 못 박는다.
/// - `확정` 인 줄은 네 언어 칸이 모두 차 있다 (확정인데 비어 있으면 검수가 빠진 것이다).
/// - **켜진 언어의 칸은 모든 줄에서 차 있다.** 용어집이 비어 있는 채로 언어를 켤 수 없다.
///   (`결정필요` 줄이 남아 있어도 켤 수 없다 — `이룸이`를 어떻게 부를지 정하지 않은 번역은 위험하다.)
void main() {
  const header = [
    '용어(ko)',
    '뜻과 쓰는 자리',
    '쓰지 않는 말(ko)',
    'en',
    'ja',
    'zh',
    'es',
    '상태',
  ];
  const statuses = {'미입력', '초안', '확정', '결정필요'};
  const langColumns = {'en': 3, 'ja': 4, 'zh': 5, 'es': 6};

  List<List<String>> readRows() {
    final lines = File('../docs/i18n/glossary.md').readAsLinesSync();
    final start = lines.indexWhere((l) => l.startsWith('| 용어(ko) |'));
    expect(start, isNonNegative, reason: '용어표 머리글(| 용어(ko) |)을 찾지 못했다');
    final rows = <List<String>>[];
    for (final line in lines.skip(start)) {
      if (!line.startsWith('|')) break;
      final cells = line.split('|').sublist(1, line.split('|').length - 1);
      rows.add(cells.map((c) => c.trim()).toList());
    }
    return rows;
  }

  test('머리글이 약속한 열과 같다', () {
    expect(readRows().first, header);
  });

  test('모든 줄이 여덟 칸이고 상태 값이 올바르다', () {
    final rows = readRows().skip(2); // 머리글과 구분선
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(row, hasLength(header.length), reason: '칸 수가 다르다: $row');
      expect(
        statuses,
        contains(row[7]),
        reason: '${row[0]}: 모르는 상태 "${row[7]}"',
      );
    }
  });

  test('용어(ko)가 중복되지 않는다', () {
    final names = readRows().skip(2).map((r) => r[0]).toList();
    expect(names.toSet(), hasLength(names.length));
  });

  test('확정인 줄은 네 언어 칸이 모두 차 있다', () {
    for (final row in readRows().skip(2).where((r) => r[7] == '확정')) {
      for (final entry in langColumns.entries) {
        expect(
          row[entry.value],
          isNotEmpty,
          reason: '${row[0]}: ${entry.key} 칸이 비었는데 확정이다',
        );
      }
    }
  });

  test('켜진 언어의 칸은 모든 줄에서 차 있고 결정필요가 남지 않았다', () {
    final launched = readLaunchedLocales()..remove('ko');
    final rows = readRows().skip(2).toList();
    for (final code in launched) {
      for (final row in rows) {
        expect(
          row[langColumns[code]!],
          isNotEmpty,
          reason: '$code 는 켜졌는데 용어집 "${row[0]}" 칸이 비었다',
        );
      }
      expect(
        rows.where((r) => r[7] == '결정필요'),
        isEmpty,
        reason: '$code 를 켜려면 용어집의 결정필요 줄을 먼저 정해야 한다',
      );
    }
  });
}
```

Run: `cd client && flutter test test/l10n/glossary_format_test.dart`
Expected: FAIL — `../docs/i18n/glossary.md` 가 없어 파일 읽기 오류

- [ ] **Step 2: 용어집을 만든다**

`docs/i18n/glossary.md`:

````markdown
# 다국어 용어집

> 이슈 [#521](https://github.com/Twin-Fang/elum/issues/521) · 스펙 `docs/superpowers/specs/2026-10-02-multi-language-design.md`
>
> **번역 문구의 기준 문서다.** 번역가·검수자·AI 초안 모두 이 표의 낱말을 쓴다. 표에 없는 낱말이 반복되면
> 먼저 이 표에 한 줄을 더하고 번역한다. 한국어(`ko`) 낱말은 루트 `CLAUDE.md` 의 용어 규칙과
> `docs/08-design-principles.md` 3장이 원본이다 — 이 표가 그것과 다르면 이 표가 틀린 것이다.

## 읽는 법

- **빈 칸은 아직 안 채운 것이다.** 번역 값은 사람이 채운다. 빈 칸으로 두는 것은 허용하지만,
  **켜진 언어(`docs/i18n/launched-locales.txt`)의 칸은 전부 채워져 있어야 한다.** 테스트
  (`client/test/l10n/glossary_format_test.dart`)가 이것을 지킨다.
- **상태** 칸은 넷 중 하나다: `미입력`(칸이 비어 있다) · `초안`(채웠지만 검수 전) · `확정`(원어민 검수 끝) ·
  `결정필요`(번역할지 말지부터 정해야 한다). `확정`은 네 언어 칸이 모두 차 있어야 한다.
- **쓰지 않는 말**은 ko 기준이다. 다른 언어의 금지어는 아래 「언어별 가이드」가 정한다.
- 법적 효력이 있는 문장(약관·개인정보방침·법정대리인 동의)은 이 표로 번역하지 않는다. 법무가 확인한
  게시본이 원본이다(하위 계획 7).

## 용어표

| 용어(ko) | 뜻과 쓰는 자리 | 쓰지 않는 말(ko) | en | ja | zh | es | 상태 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 이룸 | 서비스 이름. 스토어 이름은 `이룸(ELUM)` | | | | | | 결정필요 |
| 이룸이 | 앱을 쓰는 당사자. 이름을 모를 때 부르는 말. 이름을 알면 이름을 쓴다 | 아이 · 아동 · 우리 아이 | | | | | 결정필요 |
| 보호자 | 계정을 만들고 일과를 만드는 사람. 가족·복지사 포함 | | | | | | 미입력 |
| 일과 | 하루에 할 일 하나의 묶음. 카드 여러 장으로 이뤄진다 | | | | | | 미입력 |
| 카드 | 행동 하나를 그림과 짧은 글로 보여 주는 한 장. 한 카드에는 하나의 행동만 | | | | | | 미입력 |
| 단계 | 일과 안에서 카드가 놓인 순서 | | | | | | 미입력 |
| 보상 | 일과를 끝내면 받는 것(보호자가 정한다) | 강화 · 강화물 · 행동중재 | | | | | 미입력 |
| 별 | 이룸이가 카드를 끝낼 때마다 모으는 것 | | | | | | 미입력 |
| 휴대폰 | 앱이 깔린 기기. 문구에서는 늘 이 낱말 | 기기 | | | | | 미입력 |
| 연결 암호 | 이룸이 휴대폰을 보호자와 잇는 여섯 글자. 시안 일부는 `코드`로 쓴다(2026-09-18 합의 예외) | 코드(새 문구에서) | | | | | 미입력 |
| 비밀암호 | 이룸이 화면에서 보호자 화면으로 돌아올 때 쓰는 네 자리 | PIN · 비밀번호 | | | | | 미입력 |
| 보호자 화면 | 보호자가 쓰는 화면. 시안은 `보호자모드`로 쓴다(2026-09-18 합의 예외) | 모드(새 문구에서) | | | | | 미입력 |
| 이룸이 화면 | 이룸이가 쓰는 화면. 시안은 `이룸이모드`로 쓴다(같은 예외) | 모드(새 문구에서) | | | | | 미입력 |
| 임시저장 | 만들다 만 일과를 두는 곳 | 승인 · 승인 대기 | | | | | 미입력 |
| 이어서 | 임시저장한 일과를 다시 여는 동작 | | | | | | 미입력 |
| 도움 목표 | 보호자가 고르는 도움 방식. 이것만으로 개인화한다 | 진단 · 장애 유형 · 장애 등급 | | | | | 미입력 |
| 이룸이 이름 | 보호자가 이룸이를 부르려고 적는 이름(별명) | | | | | | 미입력 |
| 캐릭터 | 보호자가 고르는 안내 캐릭터. 포포 · 루루 · 루미 | | | | | | 결정필요 |
| AI | 카드 글과 그림을 만드는 도구. 사용자 문구에서는 `AI`로 쓴다 | 인공지능(문구가 길어질 때만 예외) | | | | | 미입력 |
| 크레딧 | AI로 카드를 만들 때 쓰는 횟수 | | | | | | 미입력 |
| 카드 그림 | 카드에 들어가는 그림. 만화 · 실사 · 사진 중 고른다 | | | | | | 미입력 |
| 픽토그램 | 무료로 쓰는 단순한 그림(Mulberry Symbols) | | | | | | 미입력 |
| 공지 | 앱 안에서 운영자가 띄우는 안내 | | | | | | 미입력 |
| 초대 | 다른 보호자를 같은 이룸이에게 이어 주는 일 | | | | | | 미입력 |
| 탈퇴하기 | 계정을 지우는 동작 | | | | | | 미입력 |
| 광고 | 보호자 화면에만 나온다. 이룸이 화면에는 없다 | | | | | | 미입력 |
| 로그인 수단 | 카카오 · 네이버 · 구글 · 애플. 이름은 고유명사 그대로 | | | | | | 미입력 |

## 언어별 가이드

번역가는 아래를 먼저 읽는다. ko 의 말투(해요체 · 능동형 · 긍정형)에 **대응하는 수준**을 언어마다 적었다.
"친근한 존댓말"의 정도는 원어민 검수자가 최종으로 정한다 — 아래는 출발점이다.

공통 원칙

- **연령을 암시하지 않는다.** 이룸이 당사자는 20대일 수 있다. 아이 · 아동에 해당하는 낱말은 어느 언어에서도 쓰지 않는다.
  (법적 문구는 예외 — 법무 확정본을 그대로 쓴다.)
- 진단명 · 장애 유형을 묻거나 짐작하게 하는 말을 만들지 않는다.
- 겁주는 말 · 명령조를 피한다(`docs/08-design-principles.md` 철학 ⑥). 할 수 있는 것을 말한다(긍정형).
- 한 문장에 행동 하나. 문장이 길어지면 나눈다.
- 자리표시자(`{name}` 등)는 번역하지 않고 그대로 둔다. 순서는 언어에 맞게 바꿔도 된다.
- 조사 · 성 · 복수는 문구 안에서 ICU(`plural`, `select`)로 푼다. 코드에서 붙이지 않는다.

| 언어 | 말투 출발점 | 쓰지 않는 말 | 결정할 것 |
| --- | --- | --- | --- |
| ko | 해요체 · 능동형 · 긍정형. `~했어요`, `~할까요?` | 아이 · 아동 · 우리 아이 · 기기 · 강화물 | 없음(기준) |
| en | 쉬운 말의 2인칭(`you`) · 줄임말 허용 · 능동형. 문장 첫 글자만 대문자 | child · kid · kids · patient · disorder · disability(당사자를 가리킬 때) | `이룸이`를 어떻게 부르는가 |
| ja | です・ます体. 지나친 경어(尊敬語·謙譲語 겹침)는 피한다 | 子ども · 子供 · お子さん · 児童 · 障害者(당사자를 가리킬 때) | `이룸이` 표기, 보호자 호칭(保護者 · ご家族) |
| zh | 간체. 지나치게 문어체이지 않은 평이한 문장 | 孩子 · 儿童 · 小孩 · 患者 | 2인칭 `你`/`您`(보호자에게 `您`, 이룸이에게 `你`를 권한다) |
| es | 친근한 존댓말. 이룸이 화면은 `tú`, 보호자의 삭제·동의 안내는 `usted`를 권한다 | niño · niña · niños · menor · paciente | 변종(스페인 · 라틴아메리카), `tú`/`usted` 범위 |

## 결정 항목

| 항목 | 선택지 | 정하는 사람 | 기한 |
| --- | --- | --- | --- |
| `이룸이`를 번역할까, 고유명사로 둘까 | (가) 언어마다 번역 · (나) 모든 언어에서 `Elumi` 같은 한 표기로 고정 | 사용자 | `en` 을 켜기 전 |
| 서비스 이름을 현지 표기로 바꿀까 | `이룸` 유지 · `ELUM` 로만 · 언어별 병기 | 사용자 | `en` 을 켜기 전 |
| 캐릭터 이름(포포 · 루루 · 루미) | 그대로 · 음역 | 사용자 + 디자이너(예람) | `en` 을 켜기 전 |
| 스페인어 변종 | 중립 `es` · 스페인 `es-ES` · 중남미 `es-419` | 사용자 + 법무(하위 계획 7) | `es` 를 켜기 전 |
| 번역을 누가 하는가 | 사람 번역 · AI 초안 + 사람 검수 | 사용자 | `en` 을 켜기 전 |
````

- [ ] **Step 3: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/glossary_format_test.dart`
Expected: PASS — 5건(지금은 `ko` 만 켜져 있어 번역 칸이 비어 있어도 통과한다)

- [ ] **Step 4: 게이트가 실제로 막는지 확인한다 (되돌린다)**

Run:
```bash
cd client
cp ../docs/i18n/launched-locales.txt /tmp/launched.bak
printf 'ko\nen\n' > ../docs/i18n/launched-locales.txt
flutter test test/l10n/glossary_format_test.dart
cp /tmp/launched.bak ../docs/i18n/launched-locales.txt
```
Expected: FAIL — `en 는 켜졌는데 용어집 "이룸" 칸이 비었다`. 마지막 줄이 파일을 되돌린다.

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/glossary.md client/test/l10n/glossary_format_test.dart
```

---

## Task 10: 번역 작업 절차 문서

**Files:**
- Create: `docs/i18n/translation-workflow.md`

**Interfaces:**
- Consumes: Task 9 의 용어집, Task 3·4·7 의 CI 검사
- Produces: 누가 · 어떤 순서로 · 무엇을 검수하는지의 절차. 번역 담당·검수 담당은 `미정`으로 둔다(사용자가 정한다).

번역 방식(사람 번역 vs AI 초안 + 사람 검수)은 열린 질문이다(스펙 8장). 이 문서는 **어느 쪽이든 검수 체크리스트를 같게** 쓰도록 짰다.

- [ ] **Step 1: 문서를 만든다**

`docs/i18n/translation-workflow.md`:

````markdown
# 번역 작업 절차

> 이슈 [#521](https://github.com/Twin-Fang/elum/issues/521) · 용어는 [glossary.md](./glossary.md)를 따른다.
> 언어를 여는 순서는 [language-launch-checklist.md](./language-launch-checklist.md).

번역은 **개발 작업이 아니라 콘텐츠 작업**이다. 코드를 건드리지 않고 번역 파일(ARB)과 용어집만 고친다.
그래서 담당이 개발자가 아니어도 되고, 검수자가 원어민이어도 PR 을 열 수 있어야 한다.

## 누가 무엇을 하나

| 역할 | 하는 일 | 담당 |
| --- | --- | --- |
| 번역 책임 | 언어 하나의 번역 파일·용어집 칸·말투를 끝까지 책임진다 | 미정 |
| 검수자 | 그 언어의 원어민. 초안을 읽고 용어집·말투·어색함을 고친다. `확정`을 찍는다 | 미정 |
| 개발 담당 | CI 오류 해석, 넘침 검사 결과 전달, 문구 길이 때문에 화면을 고쳐야 할 때 | 사용자 |

AI 초안을 쓰든 사람이 처음부터 번역하든 **검수자가 읽고 `확정`을 찍기 전에는 언어를 열지 않는다.**
(번역 방식 — 사람 번역인지, AI 초안 + 검수인지 — 은 용어집의 결정 항목이다.)

## 순서

1. **ko 를 먼저 고정한다.** 번역 중에 ko 문구가 바뀌면 모든 언어를 다시 본다. ko 를 고치려면 `app_ko.arb` 를 먼저 고치고,
   애매한 키에는 `@키` 항목의 `description` 에 번역가가 볼 맥락(어느 화면, 누가 읽는지)을 적는다.
2. **용어집을 채운다.** `docs/i18n/glossary.md` 에서 그 언어 열을 채우고 상태를 `초안` → `확정`으로 올린다.
   `결정필요` 줄(이룸이, 서비스 이름, 캐릭터)은 사용자 결정 뒤에 채운다. 용어집이 먼저다 —
   번역을 시작한 뒤에 용어가 바뀌면 파일 전체를 다시 훑어야 한다.
3. **초안을 만든다.** `lib/l10n/app_<언어>.arb` 에 키를 채운다. 모르는 키는 **비워 두지 말고 빼 둔다**
   (빈 문자열은 대체 문구로 떨어지지 않고 빈 글자로 그려진다 — CI 가 막는다).
   AI 로 초안을 만들 때는 **용어집 표와 ko ARB 를 함께** 넣고, 자리표시자·ICU 형식을 건드리지 말라고 지시한다.
   앱의 생성 API(카드 만들기)는 쓰지 않는다 — 그 호출은 돈이다.
4. **검수한다.** 아래 체크리스트를 검수자가 줄마다 확인한다.
5. **PR 을 올린다.** 번역 파일과 용어집만 담는다. PR 설명에 언어 · 검수자 · 넘침 검사 결과를 적는다.
   아직 언어를 열지 않는 PR 이면 `launched-locales.txt` 는 건드리지 않는다.
6. **CI 를 본다.** `Check translations` 단계가 키 · 자리표시자 · ICU · 빈 값을 검사한다(켜진 언어는 빠진 키까지).
7. **화면을 본다.** 번역이 길어져 깨지는 곳은 넘침 검사가 걸러 주지만, 최종 확인은 실기기 스크린샷이다
   ([체크리스트](./language-launch-checklist.md) 6번).
8. **언어를 연다.** 체크리스트의 순서를 따른다. 이 문서의 일은 7번까지다.

## 검수 체크리스트 (AI 초안이든 사람 초안이든 같다)

줄마다 확인한다. 하나라도 어긋나면 고쳐서 다시 올린다.

- [ ] **용어집**: 표에 있는 낱말은 표의 번역만 쓴다. 같은 뜻을 두 낱말로 번갈아 쓰지 않았다.
- [ ] **금지어**: 해당 언어의 「쓰지 않는 말」이 없다(아이 · 아동에 해당하는 낱말, 진단·장애 유형을 짐작하게 하는 낱말).
- [ ] **말투**: 언어별 가이드의 수준이다. 명령조 · 겁주는 말이 없고, 할 수 있는 것을 말한다.
- [ ] **자리표시자**: `{name}` · `{count}` 가 그대로 있다. 이름이 바뀌거나 번역되지 않았다.
- [ ] **복수 · 성 · 조사**: 개수에 따라 달라지는 문구는 ICU `plural`(`other` 분기 필수)로 풀었다. 코드에서 붙일 말이 남지 않았다.
- [ ] **길이**: 버튼 · 칩 · 팝업 제목처럼 자리가 정해진 문구가 ko 보다 터무니없이 길지 않다. 길면 줄이거나 개발 담당에게 알린다.
- [ ] **한 문장 한 행동**: 카드 문구는 한 문장에 행동 하나다. 번역하며 두 행동을 합치지 않았다.
- [ ] **숫자 · 날짜 · 시간**: 직접 적은 형식이 없다(날짜·숫자는 ICU 형식으로 둔다). 전각·반각 문장부호가 언어 규칙에 맞다.
- [ ] **개인정보 · 법적 문구**: 약관 · 개인정보방침 · 동의 문장은 번역하지 않았다(법무 확정본만 쓴다). "가린다 · 안전하게 보호한다"처럼 사실과 다른 약속을 만들지 않았다.
- [ ] **서버 문구를 옮기지 않았다**: 에러 문구는 서버가 번역한다(#347). ARB 에 에러 코드 문장을 더하지 않았다.
- [ ] **소리 내어 읽었다**: 이 앱은 문구를 TTS 로 읽기도 한다. 읽어서 어색하면 고친다.
````

- [ ] **Step 2: 문서의 링크와 CI 이름이 실제와 맞는지 확인한다**

Run:
```bash
test -f docs/i18n/glossary.md && test -f docs/i18n/language-launch-checklist.md || echo "language-launch-checklist.md 는 Task 11 에서 만든다"
grep -n "Check translations" .github/workflows/PROJECT-FLUTTER-CI.yaml
```
Expected: 두 번째 명령이 Task 5 에서 더한 단계 이름을 한 줄 찾는다. 첫 줄은 Task 11 전이면 안내 문구가 나와도 된다.

- [ ] **Step 3: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/translation-workflow.md
```

---

## Task 11: 언어 오픈 체크리스트

**Files:**
- Create: `docs/i18n/language-launch-checklist.md`

**Interfaces:**
- Consumes: 스펙 5장의 세 조건, 계획 7 의 `docs/i18n/legal/launch-gates.md`, 계획 6 의 네이티브·스토어 문구, Task 1 의 `launched-locales.txt`
- Produces: 언어를 여는 게이트(7개)와 켜는 순서(A~F). 켜는 스위치가 **둘**(`launched-locales.txt` 와 `ENABLED_CONTENT_LOCALES`)임을 못 박는다.

- [ ] **Step 1: 문서를 만든다**

`docs/i18n/language-launch-checklist.md`:

````markdown
# 언어를 여는 절차

> 이슈 [#521](https://github.com/Twin-Fang/elum/issues/521) · 스펙 5장 「언어를 여는 조건」 + 법무.
> **순서: `en` → `es` → `ja` → `zh`.** 한 번에 한 언어만 연다. 앞 언어에서 구조 결함이 나오면 멈춘다.

## 열기 전에 켜져 있어야 하는 것 (게이트)

모두 충족해야 한다. 하나라도 비면 그 언어는 열지 않는다.

| # | 조건 | 어디서 확인하나 | 확인자 | 기록 |
| --- | --- | --- | --- | --- |
| 1 | 번역 파일이 모든 키를 채웠다 | `lib/l10n/app_<언어>.arb` — CI `Check translations` 통과 | 번역 책임 | PR |
| 2 | 용어집 그 언어 열이 `확정`이다 | `docs/i18n/glossary.md` | 검수자 | PR |
| 3 | 그 언어의 약관이 **법무 확인을 거쳐 게시**됐다 | 관리자 > 약관(언어별) · 외부 게시 페이지 | 법무 · 개발 | `docs/i18n/legal/launch-gates.md` |
| 4 | 그 언어의 AI 프롬프트 행이 검증됐다 | 관리자 > 프롬프트(언어별) · 언어당 가장 싼 모델로 **최소 횟수만** 호출 | 개발 | 이슈 댓글 |
| 5 | 법무 항목이 그 언어에 대해 닫혔다 | `docs/i18n/legal/launch-gates.md` | 법무 | 같은 파일 |
| 6 | 네이티브·스토어 문구가 채워졌다 | 계획 6 — `InfoPlist.strings` · `strings.xml` · 스토어 문구 · 심사 노트 | 번역 책임 | PR |
| 7 | 대표 화면이 넘치거나 잘리지 않는다 | `flutter test test/l10n` 통과 + **실기기 스크린샷**(아래) | 개발 | 이슈 댓글 |

실기기 스크린샷 대상: 로그인 · 역할 선택 · 약관 동의 · 보호자 홈 · 일과 만들기 입력 · 카드 검토 · 이룸이 카드 · 설정.
기기는 가장 작은 휴대폰과 글자 크기 최대로 한 번씩 본다. 일본어 · 중국어는 실제 글꼴로 본다(테스트 환경 글꼴과 다르다).

## 여는 순서

켜는 스위치가 둘이다. **섞지 않는다.**

- `docs/i18n/launched-locales.txt` — CI 가 "번역이 다 찼다"를 강제하기 시작하는 시점. **앱 릴리스 전에** 켠다.
- 서버 시스템 설정 `ENABLED_CONTENT_LOCALES`(관리자 화면, DB) — 운영에서 그 언어의 일과 생성을 허용하는 시점. **맨 마지막에** 켠다.
  운영 값은 늘 위 파일의 부분집합이다. 파일에 없는 언어를 운영에서 켜지 않는다.

| 단계 | 하는 일 | 되돌리는 법 |
| --- | --- | --- |
| A | 게이트 1·2·6·7 을 채운 PR 에서 `launched-locales.txt` 에 언어 코드를 더한다. CI 통과를 확인하고 머지한다 | 그 줄을 지운다 |
| B | **앱 릴리스.** 새 언어 문구가 든 앱이 스토어에 올라가야 한다. 배포는 사용자가 요청할 때만 한다(앱 배포는 개별 확인) | 앱 버전을 되돌릴 수 없으면 C·D 를 늦춘다 |
| C | 관리자 화면에서 그 언어의 약관을 게시한다(게이트 3). 게시 전에는 그 언어로 가입할 수 없다 — 의도된 동작이다. 약관 본문 폴더 `consent/<언어>/` 를 함께 커밋하면 계획 4 의 게시 페이지 검사가 그 언어의 외부 게시본(`/<언어>/privacy.html` 등)도 요구한다 | 게시를 내린다 |
| D | 관리자 화면에서 프롬프트를 검증하고(게이트 4) `ENABLED_CONTENT_LOCALES` 에 코드를 더한다. 앱 업데이트가 필요 없다 | 코드를 지운다. 곧바로 `en` 처리로 돌아간다 |
| E | 스토어 문구 언어를 더하고(계획 6) 심사 노트의 언어 문장을 바꾼다 | 스토어 문구는 심사를 다시 거친다 |
| F | 첫 24시간 동안 서버 로그 · 일과 생성 실패율 · 약관 불러오기 실패를 본다 | D 를 되돌린다 |

## 열고 나서

- [ ] 그 언어 휴대폰(또는 앱별 언어 설정)으로 가입 → 일과 만들기 → 이룸이 화면까지 끝까지 밟았다.
- [ ] 보호자 휴대폰과 이룸이 휴대폰의 언어가 다를 때 카드 글과 음성이 **일과 언어**를 따른다.
- [ ] 이슈에 결과를 남긴다(`/pro-report`).
````

- [ ] **Step 2: 체크리스트가 Task 7 의 한계(실기기 스크린샷)를 요구하는지 확인한다**

Run: `grep -n "실기기 스크린샷" docs/i18n/language-launch-checklist.md`
Expected: 게이트 7번과 「열기 전에」 아래 문단에서 최소 두 줄이 걸린다.

- [ ] **Step 3: 링크를 확인한다**

Run: `for f in glossary translation-workflow launched-locales; do ls docs/i18n/$f.* ; done`
Expected: 세 파일이 모두 있다. `docs/i18n/legal/launch-gates.md` 는 계획 7 이 만든다(아직 없으면 정상).

- [ ] **Step 4: 전체 번역 검사를 한 번 돌린다**

Run: `cd client && flutter test test/l10n && flutter analyze`
Expected: `figma_ko_only_guard_test.dart` 외에는 모두 PASS(가드는 Task 8 Step 2 에서 처리한 뒤 PASS). analyze `No issues found!`

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/language-launch-checklist.md
```

---

## 끝낸 뒤

- [ ] 이슈 #521 에 이 계획의 결과를 남긴다(`/pro-report`): 추가한 테스트 수, CI 단계, **실측으로 찾은 `ko` 기존 넘침 목록**(역할 선택 2.0배 · 약관 동의 1.5/2.0배 · 연결 암호 넣기 1.5/2.0배, 테스트 글꼴 기준)을 별도 버그 이슈 후보로 적는다.
- [ ] 사용자 결정이 필요한 항목은 `docs/i18n/glossary.md` 「결정 항목」 표에 모여 있다: `이룸이` 번역 여부, 서비스 이름 표기, 캐릭터 이름, 스페인어 변종, 번역 방식.
- 배포는 하지 않는다. 이 계획의 산출물은 테스트·CI·문서이며 앱 동작은 바뀌지 않는다.
