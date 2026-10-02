# 다국어 6 — 네이티브·스토어 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> 이 문서는 마스터 계획 `2026-10-02-i18n-0-master.md` 의 하위 계획 6이다. 공통 계약 C1~C5 의 이름을 그대로 쓴다. 이름을 바꾸려면 마스터를 먼저 고친다.
> 선행 없음(마스터 순서표). 단 `docs/i18n/launched-locales.txt` 는 계획 5 가 만든다 — 아직 없으면 Task 1 이 같은 내용으로 만든다.
> **이 계획은 배포를 하지 않는다.** 앱 배포(스토어 심사로 이어지는 배포)는 사용자가 "배포해줘"라고 명시했을 때만 한다. 이 계획은 파일과 CI 설정만 바꾸며, iOS 심사 제출 설정(`submit_for_review` · `submission_information` · `DEPLOY_MODE` · 레포 변수 `IOS_DEPLOY_MODE`)은 건드리지 않는다.

**Goal:** 앱 이름과 권한 문구를 5개 언어로 갈아 끼울 수 있게 iOS·Android 네이티브 구조를 만들고, OS 의 앱별 언어 설정에 5개 언어가 뜨게 등록하며, 스토어 문구·출시 노트·심사 노트를 언어별로 올릴 수 있는 틀을 만든다. 한국어(`ko`)의 값은 한 글자도 바뀌지 않는다.

**Architecture:** 네이티브 문자열은 **데이터**다. iOS 는 `<언어>.lproj/InfoPlist.strings`, Android 는 `values-<언어>/strings.xml` 이 앱 이름·권한 문구를 담고, 매니페스트·Info.plist 는 그 리소스를 가리킬 뿐이다. 번역 전 언어는 **비우지 않고 영어 값(대체 문구)** 을 담고 `i18n:untranslated` 표식을 단다 — 빈 앱 이름이 홈 화면에 뜨는 일을 막고, 켜진 언어에서 표식이 남으면 테스트가 실패한다. 스토어 쪽은 fastlane 의 로케일 규칙을 순수 Ruby(`store_locales.rb`)로 떼어 fastlane 없이 시험한다. 기본값(`ko` 하나)에서는 동작이 이전과 같다.

**Tech Stack:** iOS(`Info.plist`, `InfoPlist.strings`, `project.pbxproj`), Android(`strings.xml`, `locales_config.xml`, AGP 8.11), fastlane(Ruby), GitHub Actions, Flutter 테스트(`flutter_test`).

**Spec:** `docs/superpowers/specs/2026-10-02-multi-language-design.md` (2장 네이티브·스토어 행 · 4.1 · 5장 · 7장 6번)

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

마스터 `Review Focus` 8줄은 모두 다른 계획(1·2·3·4·5)이 소유한다. 이 계획이 소유한 줄은 없다. 아래는 **이 계획이 더한** 항목이며 Task 1 의 테스트로 고정한다.

- ko 앱 이름과 권한 문구는 이전과 같다 — iOS 는 `Info.plist` 원본과, Android 는 iOS ko 값과 같다. (Task 1)
- 번역 전 언어가 **빈 앱 이름·빈 권한 문구**를 만들지 않는다. 대체 문구는 영어다. (Task 1)
- 언어를 하나라도 열면 심사 노트가 `Korean-only` 를 말하지 않는다. (Task 1, 7)

## 이 계획이 정한 것 (스펙·요청과 다르게 보이는 곳)

| 결정 | 이유 |
| --- | --- |
| Android 기본 `values/strings.xml` 은 **영어**, 한국어는 `values-ko` | 요청에는 "`values/strings.xml`(ko 기본)"이 있었으나, 기본 폴더는 **5개 밖 언어 휴대폰의 마지막 대체 자리**다. 스펙 4.1 은 5개 밖이면 `en` 이라 했으므로 기본이 한국어이면 번체 중국어 휴대폰이 한국어 앱 이름을 본다. ko 휴대폰은 `values-ko` 가 같은 값을 준다 |
| iOS 도 같은 이유로 `developmentRegion = en`(지금 값) 유지, Info.plist 원본(한국어)은 그대로 | 5개 밖 언어는 개발 언어 `en.lproj` 로 떨어진다. Info.plist 원본을 건드리지 않아 ko 가 달라질 여지가 없다 |
| 번역 전 파일은 영어 값 + `i18n:untranslated` 표식 | 빈 값을 담으면 홈 화면 앱 이름이 빈 칸이 된다. 요청의 "빈 값 금지는 켜진 언어에만" 을 **더 안전하게** 지켰다 — 켜지지 않은 언어도 빈 값은 두지 않고, "번역 전"은 표식으로 구분한다 |
| 중국어 폴더는 `values-b+zh+Hans`, 언어 목록은 `zh-Hans-CN` | `values-zh-rCN` 은 싱가포르 등 다른 간체 지역을 놓친다. `b+zh+Hans` 는 간체 전체를 받고 번체(zh-TW·zh-HK)는 받지 않는다 |
| Android 12 이하는 OS 앱별 언어가 없다 | 한계. 이 기기에서는 휴대폰 언어를 바꿔야 앱 언어가 바뀐다(스펙 4.1 의 알려진 한계) |
| `locales_config.xml` 과 `CFBundleLocalizations` 에 **다섯 개를 지금 모두** 등록한다 | 스펙 4.1-3 그대로다. 단 이 앱이 스토어에 올라가는 순간 설정 > 이룸 > 언어에 **아직 열지 않은 언어까지** 뜬다 — 스펙 5장(언어를 하나씩 연다)과 어긋난다. **사용자 결정 D1**: 그대로 올릴지, 등록 두 곳(plist 배열·XML)을 `ko` 만 남기고 언어를 열 때마다 더할지 |

---

## Task 1: 네이티브 계약 테스트 (먼저 실패시킨다)

**Files:**
- Create (계획 5 가 아직 안 만들었을 때만): `docs/i18n/launched-locales.txt`, `client/test/helpers/launched_locales.dart`
- Create: `client/test/native_locale_resources_test.dart` (Task 4 끝에서 초록이 되면 커밋한다)

**Interfaces:**
- Consumes: 기존 `ios/Runner/Info.plist` · `project.pbxproj` · `AndroidManifest.xml`, 계획 5 의 `readLaunchedLocales()`
- Produces: 네이티브 문자열·언어 등록·스토어 문구의 약속을 파일에서 읽어 고정하는 테스트(22건)

- [ ] **Step 1: 계획 5 가 게이트 파일을 이미 만들었는지 본다**

Run: `ls docs/i18n/launched-locales.txt client/test/helpers/launched_locales.dart`
Expected: 둘 다 있으면 Step 2 를 건너뛴다(내용이 계획 5 Task 1 과 같아야 한다 — 다르면 계획 5 의 것을 따른다).

- [ ] **Step 2: 없을 때만 만든다**

`docs/i18n/launched-locales.txt`:

```text
ko
```

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

- [ ] **Step 3: 계약 테스트를 쓴다**

`client/test/native_locale_resources_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/launched_locales.dart';

/// 네이티브 문자열(iOS `InfoPlist.strings` · Android `strings.xml`)과 언어 등록이 서로 맞는지 본다.
///
/// 위젯 테스트로는 OS 가 앱 이름과 권한 문구를 고르는 길을 볼 수 없다. 설정 파일을 직접 읽어
/// 약속을 고정한다 — 누가 권한 키를 하나 더하고 번역을 안 달아도, 언어를 한 곳에만 등록해도 여기서 걸린다.
/// (`invite_link_native_config_test.dart` 와 같은 방식이다.)
///
/// 약속
/// - 다섯 언어(ko en ja zh es)가 iOS 와 Android 양쪽에 같은 목록으로 등록돼 있다.
/// - **ko 는 이전 값 그대로다.** iOS 는 Info.plist 원본과, Android 는 iOS ko 값과 같다.
/// - 번역 전 파일은 `i18n:untranslated` 표식이 있고 영어 값을 담는다(빈 값 금지 — 빈 앱 이름이 홈 화면에 뜬다).
///   **켜진 언어(`docs/i18n/launched-locales.txt`)는 표식이 없어야 한다.**
/// - 켜진 언어는 스토어 문구 파일과 출시 노트가 있고, 심사 노트가 "Korean-only" 를 말하지 않는다.
void main() {
  const codes = ['ko', 'en', 'ja', 'zh', 'es'];
  const iosFolder = {
    'ko': 'ko',
    'en': 'en',
    'ja': 'ja',
    'zh': 'zh-Hans',
    'es': 'es',
  };
  // 영어는 기본 폴더(values)다 — 5개 밖 언어 휴대폰이 영어로 떨어지게 하려는 것이다(스펙 4.1).
  const androidFolder = {
    'ko': 'values-ko',
    'en': 'values',
    'ja': 'values-ja',
    'zh': 'values-b+zh+Hans',
    'es': 'values-es',
  };
  const marker = 'i18n:untranslated';

  final launched = readLaunchedLocales();

  String read(String path) => File(path).readAsStringSync();
  String noComments(String xml) =>
      xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  /// `"KEY" = "값";` 줄을 읽는다. 블록 주석은 건너뛴다.
  Map<String, String> parseStrings(String text) {
    final body = text.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    return {
      for (final m in RegExp(
        r'^\s*"([A-Za-z]+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$',
        multiLine: true,
      ).allMatches(body))
        m.group(1)!: m.group(2)!,
    };
  }

  final plist = noComments(read('ios/Runner/Info.plist'));

  /// Info.plist 에서 `<key>X</key><string>값</string>` 의 값.
  String plistString(String key) {
    final m = RegExp(
      '<key>$key</key>\\s*<string>([^<]*)</string>',
    ).firstMatch(plist);
    expect(m, isNotNull, reason: 'Info.plist 에 $key 가 없다');
    return m!.group(1)!;
  }

  /// 번역해야 하는 iOS 키 — 앱 이름과 모든 `NS…UsageDescription`.
  /// 권한 키를 새로 더하면 이 목록이 늘어 번역 파일에 없다고 걸린다.
  final iosKeys = <String>{
    'CFBundleDisplayName',
    for (final m in RegExp(
      r'<key>(NS\w+UsageDescription)</key>',
    ).allMatches(plist))
      m.group(1)!,
  };

  group('iOS', () {
    String stringsPath(String code) =>
        'ios/Runner/${iosFolder[code]}.lproj/InfoPlist.strings';

    test('Info.plist 의 CFBundleLocalizations 가 다섯 언어다', () {
      final block = RegExp(
        r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist);
      expect(block, isNotNull, reason: 'CFBundleLocalizations 가 없다');
      final listed = RegExp(
        r'<string>([^<]+)</string>',
      ).allMatches(block!.group(1)!).map((m) => m.group(1)!).toSet();
      expect(listed, iosFolder.values.toSet());
    });

    test('번역해야 하는 키가 하나도 안 빠졌다(앱 이름 + 권한 문구)', () {
      expect(iosKeys, contains('NSCameraUsageDescription'));
      expect(iosKeys, contains('NSPhotoLibraryUsageDescription'));
      expect(iosKeys, contains('NSUserTrackingUsageDescription'));
    });

    for (final code in codes) {
      test('$code — InfoPlist.strings 가 모든 키를 비어 있지 않게 담는다', () {
        final text = read(stringsPath(code));
        final values = parseStrings(text);
        expect(values.keys.toSet(), iosKeys);
        for (final e in values.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$code ${e.key} 가 비었다');
        }
      });
    }

    test('ko 값은 Info.plist 원본과 같다(ko 휴대폰에서 달라지지 않는다)', () {
      final ko = parseStrings(read(stringsPath('ko')));
      for (final key in iosKeys) {
        expect(ko[key], plistString(key), reason: 'ko $key 가 원본과 다르다');
      }
    });

    test('번역 전 파일은 영어 값을 담고, 켜진 언어에는 표식이 없다', () {
      final en = parseStrings(read(stringsPath('en')));
      for (final code in codes.where((c) => c != 'ko')) {
        final text = read(stringsPath(code));
        final untranslated = text.contains(marker);
        if (launched.contains(code)) {
          expect(untranslated, isFalse, reason: '$code 는 켜졌는데 번역 전 표식이 남았다');
        } else if (untranslated && code != 'en') {
          expect(
            parseStrings(text),
            en,
            reason: '$code 는 번역 전이므로 영어 값과 같아야 한다(대체 문구)',
          );
        }
      }
    });

    test('project.pbxproj 가 언어 폴더를 등록한다', () {
      final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
      final regions = RegExp(
        r'knownRegions = \((.*?)\);',
        dotAll: true,
      ).firstMatch(pbx);
      expect(regions, isNotNull);
      final listed = regions!
          .group(1)!
          .split(',')
          .map((s) => s.trim().replaceAll('"', ''))
          .where((s) => s.isNotEmpty)
          .toSet();
      expect(listed, {
        'en',
        'Base',
        ...iosFolder.values.where((v) => v != 'en'),
      });
      expect(pbx, contains('developmentRegion = en;'));
      for (final code in codes) {
        expect(
          pbx,
          contains('path = ${_q(iosFolder[code]!)}.lproj/InfoPlist.strings'),
          reason: '$code InfoPlist.strings 가 프로젝트에 등록되지 않았다',
        );
      }
      expect(pbx, contains('InfoPlist.strings in Resources'));
    });
  });

  group('Android', () {
    String stringsPath(String code) =>
        'android/app/src/main/res/${androidFolder[code]}/strings.xml';
    String? appName(String code) => RegExp(
      r'<string name="app_name">([^<]*)</string>',
    ).firstMatch(noComments(read(stringsPath(code))))?.group(1);

    test('매니페스트가 앱 이름 리소스와 언어 목록을 가리킨다', () {
      final manifest = noComments(
        read('android/app/src/main/AndroidManifest.xml'),
      );
      expect(manifest, contains('android:label="@string/app_name"'));
      expect(manifest, contains('android:localeConfig="@xml/locales_config"'));
    });

    test('locales_config.xml 이 다섯 언어를 담는다(iOS 와 같은 목록)', () {
      final xml = noComments(
        read('android/app/src/main/res/xml/locales_config.xml'),
      );
      final names = RegExp(
        r'android:name="([^"]+)"',
      ).allMatches(xml).map((m) => m.group(1)!).toSet();
      expect(names, {'ko', 'en', 'ja', 'zh-Hans-CN', 'es'});
    });

    for (final code in codes) {
      test('$code — app_name 이 비어 있지 않다', () {
        expect(
          appName(code)?.trim(),
          isNotEmpty,
          reason: '$code app_name 이 없다',
        );
      });
    }

    test('ko 앱 이름은 iOS ko 값과 같다', () {
      expect(appName('ko'), plistString('CFBundleDisplayName'));
    });

    test('번역 전 파일은 영어 값을 담고, 켜진 언어에는 표식이 없다', () {
      for (final code in codes) {
        if (code == 'ko') continue;
        final untranslated = read(stringsPath(code)).contains(marker);
        if (launched.contains(code)) {
          expect(untranslated, isFalse, reason: '$code 는 켜졌는데 번역 전 표식이 남았다');
        } else if (untranslated && code != 'en') {
          expect(
            appName(code),
            appName('en'),
            reason: '$code 는 번역 전이므로 영어 값이어야 한다',
          );
        }
      }
    });
  });

  group('스토어 문구', () {
    // 앱 언어 → App Store Connect(deliver) 로케일 / Play 로케일. es 변종은 결정 대기라 둘 다 받는다.
    const ascCodes = {
      'en': ['en-US'],
      'ja': ['ja'],
      'zh': ['zh-Hans'],
      'es': ['es-ES', 'es-MX'],
    };
    const playCodes = {
      'en': ['en-US'],
      'ja': ['ja-JP'],
      'zh': ['zh-CN'],
      'es': ['es-ES', 'es-419'],
    };
    final others = launched.where((c) => c != 'ko');

    test('켜진 언어는 App Store 문구 파일을 모두 갖고 글자 수 한도 안이다', () {
      for (final code in others) {
        final dir = ascCodes[code]!
            .map((c) => Directory('ios/fastlane/store/$c'))
            .firstWhere((d) => d.existsSync(), orElse: () => Directory(''));
        expect(dir.path, isNotEmpty, reason: '$code App Store 문구 폴더가 없다');
        String f(String n) => File('${dir.path}/$n').existsSync()
            ? File('${dir.path}/$n').readAsStringSync().trim()
            : '';
        for (final n in const [
          'name.txt',
          'subtitle.txt',
          'description.txt',
          'keywords.txt',
          'release_notes.txt',
          'support_url.txt',
          'privacy_url.txt',
        ]) {
          expect(f(n), isNotEmpty, reason: '${dir.path}/$n 가 없거나 비었다');
        }
        expect(f('name.txt').length, lessThanOrEqualTo(30));
        expect(f('subtitle.txt').length, lessThanOrEqualTo(30));
        expect(f('keywords.txt').length, lessThanOrEqualTo(100));
        expect(f('promotional_text.txt').length, lessThanOrEqualTo(170));
      }
    });

    test('켜진 언어는 Play 출시 노트 원본을 갖고 500자 안이다', () {
      for (final code in others) {
        final file = playCodes[code]!
            .map((c) => File('android/fastlane/store/$c/changelog.txt'))
            .firstWhere((f) => f.existsSync(), orElse: () => File(''));
        expect(file.path, isNotEmpty, reason: '$code Play 출시 노트 원본이 없다');
        final text = file.readAsStringSync().trim();
        expect(text, isNotEmpty);
        expect(text.length, lessThanOrEqualTo(500));
      }
    });

    test('다른 언어가 켜지면 심사 노트가 Korean-only 를 말하지 않는다', () {
      final notes = read('ios/fastlane/review_notes.txt');
      if (others.isNotEmpty) {
        expect(
          notes,
          isNot(contains('Korean-only')),
          reason: '언어를 열었는데 심사 노트가 아직 Korean-only 라고 한다',
        );
      } else {
        expect(
          notes,
          contains('Korean-only'),
          reason: '지금은 ko 만 켜져 있어 이 문장이 사실이다',
        );
      }
    });
  });
}

/// pbxproj 는 하이픈이 든 값을 따옴표로 감싼다(`"zh-Hans"`).
String _q(String s) => s.contains('-') ? '"$s' : s;
```

- [ ] **Step 4: 실패를 확인한다**

Run: `cd client && flutter test test/native_locale_resources_test.dart`
Expected: FAIL — iOS `CFBundleLocalizations` 가 없고, `ko.lproj/InfoPlist.strings` 등이 없어 `FileSystemException`, Android `strings.xml`·`locales_config.xml` 이 없다. (`스토어 문구` 그룹의 `Play 출시 노트` 등은 지금 ko 만 켜져 있어 통과한다.)

- [ ] **Step 5: 게이트 파일을 이 계획이 만든 경우에만 커밋한다 (`/pro-commit`)**

```bash
git add docs/i18n/launched-locales.txt client/test/helpers/launched_locales.dart
```

(`native_locale_resources_test.dart` 는 아직 빨간 상태이므로 Task 4 에서 함께 커밋한다.)

---

## Task 2: iOS — InfoPlist.strings 5개 언어와 언어 목록

**Files:**
- Create: `client/ios/Runner/ko.lproj/InfoPlist.strings`, `en.lproj/…`, `ja.lproj/…`, `zh-Hans.lproj/…`, `es.lproj/…`
- Modify: `client/ios/Runner/Info.plist`

**Interfaces:**
- Consumes: `Info.plist` 의 번역 대상 키 4개 — `CFBundleDisplayName`(앱 이름), `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSUserTrackingUsageDescription`
- Produces: 언어별 `InfoPlist.strings`, `CFBundleLocalizations`(`ko` `en` `ja` `zh-Hans` `es`)

**값의 규칙**

| 언어 | 값 |
| --- | --- |
| ko | 지금 `Info.plist` 문구 **그대로**(바꾸지 않는다) |
| en | 영어 초안 + `i18n:untranslated` 표식. 5개 밖 언어 휴대폰이 개발 언어로 떨어질 때 보이는 문구이기도 하다 |
| ja · zh-Hans · es | **영어 값의 복사본** + 표식. 번역가가 채우면 표식 줄을 지운다 |

`Info.plist` 원본(한국어)은 그대로 둔다. 새 권한 키(`NS…UsageDescription`)를 더할 때는 다섯 파일에 같은 키를 더해야 하고, Task 1 의 테스트가 이를 강제한다.

영어 앱 이름은 임시로 `ELUM`(스토어 이름 `이룸(ELUM)` 의 영문 표기)이다. **사용자 결정 D2**: 번역 단계에서 서비스 이름 표기를 확정한다(용어집 결정 항목 「서비스 이름」).

- [ ] **Step 1: 한국어 파일을 만든다**

`client/ios/Runner/ko.lproj/InfoPlist.strings`:

```text
/* 한국어 — 현재 Info.plist 문구와 같다. 바꾸면 ko 화면이 달라지는 것이므로 번역 단계에서도 건드리지 않는다. */
"CFBundleDisplayName" = "이룸";
"NSCameraUsageDescription" = "카드 그림으로 쓸 사진을 찍으려고 카메라를 사용해요";
"NSPhotoLibraryUsageDescription" = "카드 그림으로 쓸 사진을 고르려고 사진 보관함을 사용해요";
"NSUserTrackingUsageDescription" = "보호자 화면에 알맞은 광고를 보여드리는 데 사용해요. 이룸이의 정보는 사용하지 않아요.";
```

- [ ] **Step 2: 영어 파일을 만든다**

`client/ios/Runner/en.lproj/InfoPlist.strings`:

```text
/* i18n:untranslated */
/* 영어 초안. 번역 검수가 끝나면 위 표식 줄을 지운다. 5개 밖 언어 휴대폰의 대체 문구이기도 하다. */
"CFBundleDisplayName" = "ELUM";
"NSCameraUsageDescription" = "ELUM uses the camera to take a photo for a card picture.";
"NSPhotoLibraryUsageDescription" = "ELUM uses your photo library so you can choose a photo for a card picture.";
"NSUserTrackingUsageDescription" = "We use this to show ads that fit the guardian screen. We never use any information about the person using ELUM.";
```

- [ ] **Step 3: 일본어·중국어(간체)·스페인어 파일을 만든다 (영어 복사본)**

세 파일의 내용은 같다. 경로: `client/ios/Runner/ja.lproj/InfoPlist.strings`, `client/ios/Runner/zh-Hans.lproj/InfoPlist.strings`, `client/ios/Runner/es.lproj/InfoPlist.strings`.

```text
/* i18n:untranslated */
/* 영어 문구의 복사본이다. 번역가가 채우면 위 표식 줄을 지운다. */
"CFBundleDisplayName" = "ELUM";
"NSCameraUsageDescription" = "ELUM uses the camera to take a photo for a card picture.";
"NSPhotoLibraryUsageDescription" = "ELUM uses your photo library so you can choose a photo for a card picture.";
"NSUserTrackingUsageDescription" = "We use this to show ads that fit the guardian screen. We never use any information about the person using ELUM.";
```

- [ ] **Step 4: Info.plist 에 언어 목록을 더한다**

레포 루트에서 아래 스크립트를 실행한다(치환이 한 곳과 맞지 않으면 멈추고 파일을 쓰지 않는다).

```python
# client/ios/Runner/Info.plist 에 언어 목록을 더하고 앱 이름 주석을 고친다.
# 레포 루트에서 실행: python3 이 파일. 치환이 정확히 한 곳과 맞지 않으면 멈춘다.
import pathlib

path = pathlib.Path('client/ios/Runner/Info.plist')
s = path.read_text(encoding='utf-8')

old = '''	<!-- 홈 화면에 보이는 이름. 한국어만 지원하는 서비스라 한글로 둔다 (이슈 #289). -->
	<key>CFBundleDisplayName</key>
	<string>이룸</string>
'''
new = '''	<!-- 홈 화면에 보이는 기본 이름. 언어별 이름은 <언어>.lproj/InfoPlist.strings 가 덮어쓴다
	     (이슈 #289, #521). 여기 값은 ko 와 같게 둔다 — ko 휴대폰에서 달라지지 않는다. -->
	<key>CFBundleDisplayName</key>
	<string>이룸</string>
	<!-- 설정 > 이룸 > 언어(앱별 언어)에 뜨는 언어 목록 (#521). 앱 문구는 Flutter 가 그리므로
	     선언이 있어야 OS 가 다국어 앱으로 안다. 값은 <언어>.lproj 폴더 이름과 같다.
	     InfoPlist.strings · knownRegions(project.pbxproj) 와 함께 움직인다 — 하나만 바꾸지 않는다. -->
	<key>CFBundleLocalizations</key>
	<array>
		<string>ko</string>
		<string>en</string>
		<string>ja</string>
		<string>zh-Hans</string>
		<string>es</string>
	</array>
'''
assert s.count(old) == 1, 'CFBundleDisplayName 블록이 한 곳과 맞아야 한다'
path.write_text(s.replace(old, new), encoding='utf-8')
print('Info.plist 수정 완료')
```

Run: 위 스크립트를 `/tmp/ios_plist_edit.py` 로 저장하고 레포 루트에서 `python3 /tmp/ios_plist_edit.py`
Expected: `Info.plist 수정 완료`

- [ ] **Step 5: 문법을 확인한다**

Run: `plutil -lint client/ios/Runner/Info.plist client/ios/Runner/*.lproj/InfoPlist.strings`
Expected: 파일 6개 모두 `OK`

- [ ] **Step 6: iOS 계약 테스트를 돌린다**

Run: `cd client && flutter test test/native_locale_resources_test.dart --name '^iOS '`
Expected: `project.pbxproj 가 언어 폴더를 등록한다` **한 건만** FAIL(Task 3 에서 고친다), 나머지 iOS 테스트는 PASS. 이 한 건이 실패하는 것이 정상이다.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/ios/Runner/Info.plist client/ios/Runner/ko.lproj client/ios/Runner/en.lproj client/ios/Runner/ja.lproj client/ios/Runner/zh-Hans.lproj client/ios/Runner/es.lproj
```

(`Runner.xcodeproj` 는 Task 3 에서 커밋한다. 이 커밋만으로는 Xcode 가 새 파일을 번들에 넣지 않으므로 앱 동작이 바뀌지 않는다.)

---

## Task 3: iOS — project.pbxproj 등록

**Files:**
- Modify: `client/ios/Runner.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Task 2 의 `<언어>.lproj/InfoPlist.strings` 5개
- Produces: `knownRegions`(`en` `Base` `ko` `ja` `zh-Hans` `es`), `InfoPlist.strings` 변형 그룹(`PBXVariantGroup`), Runner 타깃 Resources 단계 등록

**앱별 언어 설정에 5개 언어가 뜨는 조건 (iOS).** 세 가지가 모두 있어야 한다: ① `Info.plist` 의 `CFBundleLocalizations` ② `knownRegions` 에 그 언어 ③ 그 언어의 `lproj` 리소스가 Resources 단계에 들어간 것(변형 그룹). 하나만 있으면 설정 목록에 안 뜨거나, 떠도 앱 이름이 안 바뀐다. Xcode 가 새 폴더를 보고 `pbxproj` 를 자동 수정하지 않으므로(명령줄 작업) 직접 등록한다. `developmentRegion = en` 은 그대로 둔다.

새 ID 24자리는 접두사 `5A00…` 로 묶었다(기존 ID 와 겹치지 않는다 — 스크립트가 치환 앵커를 검증한다).

- [ ] **Step 1: 등록 스크립트를 실행한다**

레포 루트에서 실행한다. 치환 여섯 곳 중 하나라도 한 곳과 맞지 않으면 `AssertionError` 로 멈추고 파일을 쓰지 않는다.

```python
# client/ios/Runner.xcodeproj/project.pbxproj 에 InfoPlist.strings(5개 언어)를 등록한다.
# 레포 루트에서 실행: python3 이 파일
# 각 치환은 정확히 한 곳과 맞아야 한다. 어긋나면 AssertionError 로 멈추고 파일을 쓰지 않는다.
import pathlib

path = pathlib.Path('client/ios/Runner.xcodeproj/project.pbxproj')
s = path.read_text(encoding='utf-8')


def rep(old, new):
    global s
    assert s.count(old) == 1, f'한 곳과 맞아야 한다({s.count(old)}곳): {old[:60]!r}'
    s = s.replace(old, new)


# 새 ID 는 접두사 5A00… 로 묶어 둔다(24자리 16진수, 기존 ID 와 겹치지 않는다).
BUILD = '5A0000000000000000000001'   # InfoPlist.strings in Resources
GROUP = '5A0000000000000000000002'   # InfoPlist.strings (PBXVariantGroup)
KO, EN, JA, ZH, ES = (f'5A00000000000000000000{n:02d}' for n in range(3, 8))

# 1) 빌드 파일 — Resources 단계에 들어가는 항목
rep(
    '\t\t97C147011CF9000F007C117D /* LaunchScreen.storyboard in Resources */ = {isa = PBXBuildFile;',
    f'\t\t{BUILD} /* InfoPlist.strings in Resources */ = {{isa = PBXBuildFile; fileRef = {GROUP} /* InfoPlist.strings */; }};\n'
    '\t\t97C147011CF9000F007C117D /* LaunchScreen.storyboard in Resources */ = {isa = PBXBuildFile;',
)

# 2) 파일 참조 — 언어별 InfoPlist.strings 다섯 개
refs = ''
for ident, name, folder in [(KO, 'ko', 'ko'), (EN, 'en', 'en'), (JA, 'ja', 'ja'), (ZH, 'zh-Hans', 'zh-Hans'), (ES, 'es', 'es')]:
    q = f'"{name}"' if '-' in name else name          # 하이픈이 든 값은 따옴표로 감싼다
    p = f'"{folder}.lproj/InfoPlist.strings"' if '-' in folder else f'{folder}.lproj/InfoPlist.strings'
    refs += (f'\t\t{ident} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; '
             f'name = {q}; path = {p}; sourceTree = "<group>"; }};\n')
rep('\t\t97C146EE1CF9000F007C117D /* Runner.app */ = {isa = PBXFileReference;',
    refs + '\t\t97C146EE1CF9000F007C117D /* Runner.app */ = {isa = PBXFileReference;')

# 3) Runner 그룹(파일 목록)에 변형 그룹을 더한다
rep('\t\t\t\t97C147021CF9000F007C117D /* Info.plist */,\n\t\t\t\t1498D2321E8E86230040F4C2',
    f'\t\t\t\t97C147021CF9000F007C117D /* Info.plist */,\n\t\t\t\t{GROUP} /* InfoPlist.strings */,\n\t\t\t\t1498D2321E8E86230040F4C2')

# 4) 프로젝트가 아는 언어 — 개발 언어(developmentRegion = en)는 그대로 둔다
rep('\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);',
    '\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t\tko,\n\t\t\t\tja,\n\t\t\t\t"zh-Hans",\n\t\t\t\tes,\n\t\t\t);')

# 5) Runner 타깃의 Resources 단계
rep('\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n\t\t\t);',
    f'\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n\t\t\t\t{BUILD} /* InfoPlist.strings in Resources */,\n\t\t\t);')

# 6) 변형 그룹 본체
rep('/* End PBXVariantGroup section */',
    f'\t\t{GROUP} /* InfoPlist.strings */ = {{\n\t\t\tisa = PBXVariantGroup;\n\t\t\tchildren = (\n'
    f'\t\t\t\t{KO} /* ko */,\n\t\t\t\t{EN} /* en */,\n\t\t\t\t{JA} /* ja */,\n\t\t\t\t{ZH} /* zh-Hans */,\n\t\t\t\t{ES} /* es */,\n'
    '\t\t\t);\n\t\t\tname = InfoPlist.strings;\n\t\t\tsourceTree = "<group>";\n\t\t};\n/* End PBXVariantGroup section */')

path.write_text(s, encoding='utf-8')
print('pbxproj 등록 완료')
```

Run: 위 스크립트를 `/tmp/pbxproj_edit.py` 로 저장하고 레포 루트에서 `python3 /tmp/pbxproj_edit.py`
Expected: `pbxproj 등록 완료`

- [ ] **Step 2: pbxproj 가 파싱되는지, Xcode 가 프로젝트를 읽는지 확인한다**

Run:
```bash
plutil -convert json -o /dev/null client/ios/Runner.xcodeproj/project.pbxproj && echo "PLUTIL OK"
(cd client/ios && xcodebuild -project Runner.xcodeproj -list | sed -n 1,12p)
```
Expected: `PLUTIL OK`, 그리고 `Targets: Runner / RunnerTests`, `Build Configurations: Debug / Release / Profile` 이 보인다. (`-list` 는 프로젝트를 파싱만 한다. 빌드는 Pods·서명이 필요해 이 계획에서 돌리지 않는다.)

- [ ] **Step 3: 변경 범위를 확인한다**

Run: `git diff --stat client/ios/Runner.xcodeproj/project.pbxproj && git diff client/ios/Runner.xcodeproj/project.pbxproj | grep '^[-+]' | grep -v '^+++\|^---' | grep -c '^-'`
Expected: 삭제된 줄 수는 `0`(추가만 있다). 0 이 아니면 스크립트 밖의 변경이 섞인 것이다 — 되돌리고 다시 확인한다.

- [ ] **Step 4: iOS 계약 테스트 전체를 돌린다**

Run: `cd client && flutter test test/native_locale_resources_test.dart --name '^iOS '`
Expected: PASS — iOS 그룹 10건 전부(`project.pbxproj 가 언어 폴더를 등록한다` 포함)

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/ios/Runner.xcodeproj/project.pbxproj
```

---

## Task 4: Android — 앱 이름 리소스, 언어 목록, AAB 언어 분할

**Files:**
- Create: `client/android/app/src/main/res/values/strings.xml` (영어, 기본)
- Create: `client/android/app/src/main/res/values-ko/strings.xml`, `values-ja/…`, `values-b+zh+Hans/…`, `values-es/…`
- Create: `client/android/app/src/main/res/xml/locales_config.xml`
- Modify: `client/android/app/src/main/AndroidManifest.xml` (`android:label`, `android:localeConfig`)
- Modify: `client/android/app/build.gradle.kts` (`bundle { language { enableSplit = false } }`)

**Interfaces:**
- Consumes: Task 2 의 iOS ko 앱 이름 `이룸`(두 플랫폼이 같아야 한다)
- Produces: `@string/app_name`, `@xml/locales_config`

현재 `build.gradle.kts` 에는 `resourceConfigurations`·`localeFilters` 가 **없다** — 모든 언어 리소스가 들어가므로 새 폴더가 잘리지 않는다. 앞으로 앱 용량을 줄이려고 필터를 넣게 되면 **다섯 언어를 모두** 포함해야 한다(그러지 않으면 앱별 언어를 골라도 이름이 안 바뀐다).

Android 13 미만(API 33 미만)에는 OS 의 앱별 언어가 없다. 이 기기에서는 `locales_config.xml` 이 무시되고 **휴대폰 언어를 바꿔야** 앱 이름·언어가 바뀐다. 문서화된 한계다(스펙 4.1).

- [ ] **Step 1: 리소스 파일을 만든다**

`client/android/app/src/main/res/values/strings.xml`(기본 = 영어):

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- i18n:untranslated -->
<!-- 기본(= 영어, 5개 밖 언어 휴대폰의 대체 문구). 영어 초안이라 번역 검수가 끝나면 위 표식 줄을 지운다.
     한국어는 values-ko 가 덮어쓴다. 이 폴더에 값이 비면 안 된다 — 안드로이드의 마지막 대체 자리다. -->
<resources>
    <string name="app_name">ELUM</string>
</resources>
```

`client/android/app/src/main/res/values-ko/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- 한국어 — 이전 android:label="이룸" 과 같은 값이다. 바꾸면 ko 휴대폰의 앱 이름이 달라진다. -->
<resources>
    <string name="app_name">이룸</string>
</resources>
```

`client/android/app/src/main/res/values-ja/strings.xml`, `values-b+zh+Hans/strings.xml`, `values-es/strings.xml` — 세 파일의 내용은 같다(영어 복사본):

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- i18n:untranslated -->
<!-- 영어 문구의 복사본이다. 번역가가 채우면 위 표식 줄을 지운다. -->
<resources>
    <string name="app_name">ELUM</string>
</resources>
```

`client/android/app/src/main/res/xml/locales_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- 설정 > 앱 > 이룸 > 언어(Android 13+ 앱별 언어)에 뜨는 언어 (이슈 #521).
     iOS 의 CFBundleLocalizations 와 같은 다섯 개다. 하나만 더하거나 빼지 않는다.
     중국어는 간체만 연다(번체는 범위 밖). -->
<locale-config xmlns:android="http://schemas.android.com/apk/res/android">
    <locale android:name="ko"/>
    <locale android:name="en"/>
    <locale android:name="ja"/>
    <locale android:name="zh-Hans-CN"/>
    <locale android:name="es"/>
</locale-config>
```

- [ ] **Step 2: 매니페스트와 Gradle 을 고친다**

레포 루트에서 실행한다(치환이 한 곳과 맞지 않으면 멈춘다).

```python
# 매니페스트의 앱 이름을 리소스로 바꾸고 언어 목록을 연결하며, AAB 언어 분할을 끈다.
# 레포 루트에서 실행: python3 이 파일. 치환이 정확히 한 곳과 맞지 않으면 멈춘다.
import pathlib


def edit(path, old, new):
    p = pathlib.Path(path)
    s = p.read_text(encoding='utf-8')
    assert s.count(old) == 1, f'{path}: 한 곳과 맞아야 한다({s.count(old)}곳)'
    p.write_text(s.replace(old, new), encoding='utf-8')


edit(
    'client/android/app/src/main/AndroidManifest.xml',
    '''    <application
        android:label="이룸"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">''',
    '''    <application
        android:label="@string/app_name"
        android:localeConfig="@xml/locales_config"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">''',
)

edit(
    'client/android/app/build.gradle.kts',
    '''    buildTypes {
        release {''',
    '''    // 앱별 언어(Android 13+)로 기기 언어와 다른 언어를 고르면 그 언어의 리소스가 설치돼 있어야 앱 이름이
    // 바뀐다. AAB 의 기본 동작(기기 언어만 내려받음)을 끈다. 앱 문구는 Flutter(Dart)가 그리므로
    // 늘어나는 용량은 앱 이름·플러그인 문자열 정도다 (이슈 #521).
    bundle {
        language {
            enableSplit = false
        }
    }

    buildTypes {
        release {''',
)
print('매니페스트·Gradle 수정 완료')
```

Run: 위 스크립트를 `/tmp/android_edit.py` 로 저장하고 레포 루트에서 `python3 /tmp/android_edit.py`
Expected: `매니페스트·Gradle 수정 완료`

`android:label` 이 `"이룸"` 리터럴에서 `@string/app_name` 으로 바뀌어도 ko 휴대폰의 이름은 `values-ko` 가 같은 `이룸` 을 주므로 달라지지 않는다. 기존 `resValue("string", "naver_client_*", …)` 는 `generated` 리소스라 `app_name` 과 이름이 겹치지 않는다.

- [ ] **Step 3: XML 문법을 확인한다**

Run:
```bash
cd client/android/app/src/main
xmllint --noout AndroidManifest.xml res/values/strings.xml res/values-ko/strings.xml res/values-ja/strings.xml 'res/values-b+zh+Hans/strings.xml' res/values-es/strings.xml res/xml/locales_config.xml && echo "XML OK"
```
Expected: `XML OK`

- [ ] **Step 4: 리소스가 실제로 컴파일·링크되는지 확인한다 (Android SDK 가 있을 때)**

Gradle 전체 빌드 없이 `aapt2` 로 리소스만 본다. `styles.xml` 은 다른 리소스를 참조하므로 임시 폴더에서 뺀다.

Run:
```bash
AAPT=$(ls -d ~/Library/Android/sdk/build-tools/*/aapt2 | tail -1)
ANDROID_JAR=$(ls -d ~/Library/Android/sdk/platforms/android-3*/android.jar | tail -1)
T=$(mktemp -d)
cp -R client/android/app/src/main/res/values client/android/app/src/main/res/values-* client/android/app/src/main/res/xml "$T/"
rm "$T/values/styles.xml"
printf '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="kr.twinfang.elum"><application android:label="@string/app_name" android:localeConfig="@xml/locales_config"/></manifest>' > "$T/AndroidManifest.xml"
"$AAPT" compile --dir "$T" -o "$T/res.zip" && "$AAPT" link -o "$T/out.apk" -I "$ANDROID_JAR" --manifest "$T/AndroidManifest.xml" "$T/res.zip" && "$AAPT" dump badging "$T/out.apk" | grep -E "application-label|locales"
```
Expected:
```
application-label:'ELUM'
application-label-es:'ELUM'
application-label-ja:'ELUM'
application-label-ko:'이룸'
application-label-zh-Hans:'ELUM'
locales: '--_--' 'es' 'ja' 'ko' 'zh-Hans'
```
기본(5개 밖 언어)이 `ELUM`, ko 가 `이룸` 이고 중국어가 `zh-Hans`(간체)로 인식된다. SDK 가 없으면 이 Step 을 건너뛰고 Task 8 의 실기기 확인으로 대신한다.

- [ ] **Step 5: 계약 테스트 전체를 돌린다**

Run: `cd client && flutter test test/native_locale_resources_test.dart && flutter analyze test/native_locale_resources_test.dart test/helpers`
Expected: PASS — 22건, analyze `No issues found!`

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add client/android/app/src/main/AndroidManifest.xml client/android/app/build.gradle.kts client/android/app/src/main/res/values client/android/app/src/main/res/values-ko client/android/app/src/main/res/values-ja client/android/app/src/main/res/values-b+zh+Hans client/android/app/src/main/res/values-es client/android/app/src/main/res/xml client/test/native_locale_resources_test.dart
```

(`res/values/styles.xml` 은 기존 파일이라 `res/values` 를 통째로 더해도 변경이 없다.)

---

## Task 5: fastlane(iOS) — 언어별 문구 규칙

**Files:**
- Create: `client/ios/fastlane/store_locales.rb`
- Create: `client/ios/fastlane/test/store_locales_test.rb`
- Modify: `client/ios/fastlane/Fastfile`
- Modify: `.github/workflows/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` (`DELIVER_LOCALES` 한 줄)

**Interfaces:**
- Consumes: 환경변수 `DELIVER_LOCALES`(쉼표로 이은 deliver 로케일, 비면 `ko`), 문구 원본 `client/ios/fastlane/store/<로케일>/*.txt`
- Produces: `StoreLocales.parse_locales(raw)`, `StoreLocales.write_release_notes(metadata_path:, locales:, default_notes:, store_dir:)`

**지금 코드의 두 가지 문제.**

1. `DELIVER_LOCALES` 를 늘리면 **모든 언어의 새로운 기능(What's New)에 한국어 문구가 그대로** 들어간다. 영어 스토어 페이지에 한국어 업데이트 노트가 뜬다.
2. 어느 워크플로도 `DELIVER_LOCALES` 를 설정하지 않아 기본값 `ko` 만 쓰인다. 레포 변수 `IOS_DELIVER_LOCALES` 를 연결하되, 변수가 **빈 값이면 ko** 로 떨어져야 한다(빈 문자열이 그대로 가면 노트가 0건이 돼 심사 제출이 깨진다).

규칙: ko 는 **지금과 똑같이** `release_notes.txt` 만 쓴다(ASC 의 기존 한국어 설명·키워드를 덮지 않는다). 다른 언어는 `store/<로케일>/` 의 파일을 통째로 복사하고, 필수 파일 일곱 개 중 하나라도 없거나 공백뿐이면 **ASC 로 넘어가기 전에** 멈춘다.

> ⚠️ 이 `Fastfile` 은 마법사(`testflight-wizard.py setup`)가 설치한다고 파일 머리에 적혀 있다. 마법사를 다시 돌리면 이 Task 의 Fastfile 수정이 덮인다. 그래서 Fastfile 변경은 **두 군데(require 한 줄 + 로케일 블록)** 로 작게 하고, 규칙 본체는 `store_locales.rb` 에 뒀다.

- [ ] **Step 1: 실패하는 Ruby 테스트를 먼저 쓴다**

`client/ios/fastlane/test/store_locales_test.rb`:

```ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../store_locales"

class StoreLocalesTest < Minitest::Test
  def test_기본값은_ko_하나다
    assert_equal %w[ko], StoreLocales.parse_locales(nil)
    assert_equal %w[ko], StoreLocales.parse_locales("")
    assert_equal %w[ko], StoreLocales.parse_locales("  ,  ")
  end

  def test_쉼표로_이은_코드를_읽는다
    assert_equal %w[ko en-US], StoreLocales.parse_locales("ko, en-US")
    assert_equal %w[ko en-US], StoreLocales.parse_locales("ko,en-US,en-US")
  end

  def test_deliver_가_모르는_코드는_거부한다
    err = assert_raises(ArgumentError) { StoreLocales.parse_locales("ko,ko-KR") }
    assert_includes err.message, "ko-KR"
    assert_raises(ArgumentError) { StoreLocales.parse_locales("ko,en") } # en 은 en-US 여야 한다
  end

  def test_ko_가_빠지면_거부한다
    assert_raises(ArgumentError) { StoreLocales.parse_locales("en-US") }
  end

  def test_ko_는_release_notes_만_쓴다
    Dir.mktmpdir do |tmp|
      meta = File.join(tmp, "metadata")
      StoreLocales.write_release_notes(metadata_path: meta, locales: %w[ko], default_notes: "고쳤어요", store_dir: File.join(tmp, "store"))
      assert_equal %w[release_notes.txt], Dir.children(File.join(meta, "ko"))
      assert_equal "고쳤어요", File.read(File.join(meta, "ko", "release_notes.txt"))
    end
  end

  def test_다른_언어는_문구_파일을_복사한다
    Dir.mktmpdir do |tmp|
      store = File.join(tmp, "store", "en-US")
      FileUtils.mkdir_p(store)
      StoreLocales::REQUIRED_FILES.each { |f| File.write(File.join(store, f), "x #{f}") }
      File.write(File.join(store, "promotional_text.txt"), "promo")
      meta = File.join(tmp, "metadata")

      StoreLocales.write_release_notes(metadata_path: meta, locales: %w[ko en-US], default_notes: "고쳤어요", store_dir: File.join(tmp, "store"))

      assert_equal "x name.txt", File.read(File.join(meta, "en-US", "name.txt"))
      assert_equal "promo", File.read(File.join(meta, "en-US", "promotional_text.txt"))
      assert_equal "고쳤어요", File.read(File.join(meta, "ko", "release_notes.txt"))
    end
  end

  def test_필수_파일이_빠지면_멈춘다
    Dir.mktmpdir do |tmp|
      store = File.join(tmp, "store", "ja")
      FileUtils.mkdir_p(store)
      File.write(File.join(store, "name.txt"), "イルム")
      File.write(File.join(store, "description.txt"), "  ") # 공백만 있는 파일도 빈 것이다
      err = assert_raises(ArgumentError) do
        StoreLocales.write_release_notes(metadata_path: File.join(tmp, "m"), locales: %w[ko ja], default_notes: "x", store_dir: File.join(tmp, "store"))
      end
      assert_includes err.message, "description.txt"
      assert_includes err.message, "keywords.txt"
    end
  end
end
```

Run: `ruby client/ios/fastlane/test/store_locales_test.rb`
Expected: FAIL — `cannot load such file -- .../store_locales` (LoadError)

- [ ] **Step 2: 규칙 파일을 만든다**

`client/ios/fastlane/store_locales.rb`:

```ruby
require "fileutils"

# App Store Connect(deliver)에 올릴 언어별 문구 규칙 (이슈 #521).
#
# Fastfile 에 인라인으로 두면 fastlane 없이는 시험할 수 없다. 로케일 코드를 잘못 적거나(`ko-KR`),
# 새 언어의 문구 파일이 빠진 채 심사로 넘어가는 실수를 배포 전에 잡으려고 분리했다.
# 이 파일은 순수 Ruby 다 — `ruby test/store_locales_test.rb` 로 돈다.
module StoreLocales
  # deliver 가 받는 로케일 폴더 이름. 앱 언어 코드와 다르다(en → en-US, zh → zh-Hans).
  # `ko-KR` 같은 값은 유효하지 않다. es 변종(스페인 · 중남미)은 결정 대기라 두 값을 다 허용한다.
  VALID = %w[ko en-US ja zh-Hans es-ES es-MX].freeze

  DEFAULT = %w[ko].freeze

  # ko 가 아닌 언어는 새 로컬라이제이션을 만들어야 하므로 ASC 가 요구하는 필드를 모두 담아야 한다.
  # (ko 는 ASC 에 이미 있는 값을 보존하려고 이 파일들을 두지 않는다.)
  REQUIRED_FILES = %w[
    name.txt subtitle.txt description.txt keywords.txt
    release_notes.txt support_url.txt privacy_url.txt
  ].freeze

  # DELIVER_LOCALES 환경변수를 읽는다. 비었거나 공백이면 기본값(ko)이다.
  # 레포 변수가 비어 있어도(`""`) 노트가 0건이 돼 심사 제출이 깨지지 않게 한다.
  def self.parse_locales(raw)
    list = raw.to_s.split(",").map(&:strip).reject(&:empty?)
    list = DEFAULT.dup if list.empty?
    bad = list - VALID
    raise ArgumentError, "DELIVER_LOCALES 에 deliver 가 모르는 코드가 있다: #{bad.join(', ')} (허용: #{VALID.join(', ')})" unless bad.empty?
    raise ArgumentError, "DELIVER_LOCALES 에 ko 가 없다. ko 는 늘 포함한다" unless list.include?("ko")

    list.uniq
  end

  # 언어마다 metadata/<로케일>/ 을 채운다.
  #  - ko: 지금처럼 release_notes.txt 만 쓴다(ASC 의 기존 설명·키워드를 덮지 않는다).
  #  - 그 밖: store_dir/<로케일>/ 의 파일을 통째로 복사한다. 필수 파일이 빠지면 예외다.
  def self.write_release_notes(metadata_path:, locales:, default_notes:, store_dir:)
    locales.each do |loc|
      dir = File.join(metadata_path, loc)
      FileUtils.mkdir_p(dir)
      if loc == "ko"
        File.write(File.join(dir, "release_notes.txt"), default_notes)
        next
      end

      src = File.join(store_dir, loc)
      missing = REQUIRED_FILES.reject do |name|
        path = File.join(src, name)
        File.file?(path) && !File.read(path).strip.empty?
      end
      unless missing.empty?
        raise ArgumentError, "#{loc} 문구가 모자란다: #{src} 에 #{missing.join(', ')} 가 없거나 비어 있다. " \
                             "한국어 문구가 다른 언어 심사 문구로 올라가는 것보다 배포를 멈추는 편이 낫다"
      end
      Dir.glob(File.join(src, "*.txt")).sort.each { |f| FileUtils.cp(f, dir) }
    end
  end
end
```

- [ ] **Step 3: 통과를 확인한다**

Run: `ruby -c client/ios/fastlane/store_locales.rb && ruby client/ios/fastlane/test/store_locales_test.rb`
Expected: `Syntax OK`, `7 runs, 20 assertions, 0 failures, 0 errors, 0 skips`

- [ ] **Step 4: Fastfile 과 워크플로를 고친다**

레포 루트에서 실행한다. Fastfile 두 곳, iOS 워크플로 한 곳, (Task 6 에서 쓰는) Android 워크플로 두 곳을 **한 번에** 검증하고, 하나라도 한 곳과 맞지 않으면 아무것도 쓰지 않는다.

```python
# iOS Fastfile 이 언어별 문구 규칙(store_locales.rb)을 쓰게 하고, 두 워크플로에 언어 변수를 연결한다.
# 레포 루트에서 실행: python3 이 파일. 치환이 정확히 한 곳과 맞지 않으면 멈춘다(어느 하나도 쓰지 않는다).
import pathlib

edits = []  # (경로, old, new)


def add(path, old, new):
    edits.append((path, old, new))


add(
    'client/ios/fastlane/Fastfile',
    '''default_platform(:ios)

platform :ios do''',
    '''default_platform(:ios)

# 언어별 스토어 문구 규칙 (이슈 #521). 순수 Ruby 라 fastlane 없이 시험한다: ruby test/store_locales_test.rb
require_relative "store_locales"

platform :ios do''',
)

add(
    'client/ios/fastlane/Fastfile',
    '''      # ⚠️ 로케일 디렉토리명은 deliver가 인정하는 코드만 (ko 유효, ko-KR 무효).
      locales = (ENV["DELIVER_LOCALES"] || "ko").split(",").map(&:strip).reject(&:empty?)
      locales.each do |loc|
        dir = File.join(metadata_path, loc)
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, "release_notes.txt"), release_notes)
      end
''',
    '''      # ⚠️ 로케일 디렉토리명은 deliver가 인정하는 코드만 (ko 유효, ko-KR 무효).
      # 언어별 규칙은 store_locales.rb 에 있다 (이슈 #521). 기본값은 여전히 ko 하나이고,
      # 다른 언어를 켜려면 레포 변수 IOS_DELIVER_LOCALES 에 로케일을 더한다(문구 파일이 먼저 있어야 한다).
      begin
        StoreLocales.write_release_notes(
          metadata_path: metadata_path,
          locales: StoreLocales.parse_locales(ENV["DELIVER_LOCALES"]),
          default_notes: release_notes,
          store_dir: File.join(workspace, ENV["APP_ROOT"] || ".", "ios", "fastlane", "store")
        )
      rescue ArgumentError => e
        UI.user_error!(e.message)
      end
''',
)

add(
    '.github/workflows/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml',
    '''          export DEPLOY_MODE="${{ env.DEPLOY_MODE }}"
''',
    '''          export DEPLOY_MODE="${{ env.DEPLOY_MODE }}"
          # App Store Connect 에 올릴 언어(deliver 로케일, 쉼표로 이음). 비우면 ko 하나다 (이슈 #521).
          # 새 언어는 문구 파일(client/ios/fastlane/store/<로케일>/)이 먼저 있어야 한다.
          export DELIVER_LOCALES="${{ vars.IOS_DELIVER_LOCALES }}"
''',
)

add(
    '.github/workflows/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml',
    '''  STORE_WHATS_NEW_OVERRIDE: "이번 버전에서 버그를 고치고 성능을 개선했어요."
''',
    '''  STORE_WHATS_NEW_OVERRIDE: "이번 버전에서 버그를 고치고 성능을 개선했어요."
  # ko-KR 말고 출시 노트를 더 올릴 Play 로케일(쉼표로 이음, 예: en-US,ja-JP). 비우면 ko-KR 하나다 (이슈 #521).
  # 노트 원본은 client/android/fastlane/store/<로케일>/changelog.txt 에 둔다. 파일이 없으면 배포를 멈춘다.
  PLAY_CHANGELOG_LOCALES: ${{ vars.PLAY_CHANGELOG_LOCALES }}
''',
)

add(
    '.github/workflows/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml',
    '''            echo "⚠️ 기본 Changelog 생성 (버전 코드: $VERSION_CODE)"
          fi
''',
    '''            echo "⚠️ 기본 Changelog 생성 (버전 코드: $VERSION_CODE)"
          fi

          # 다른 언어의 출시 노트 (이슈 #521). PLAY_CHANGELOG_LOCALES 가 비어 있으면(기본) 아무것도 하지 않는다.
          # 한국어 문구가 다른 언어 노트로 올라가는 것보다 배포를 멈추는 편이 낫다.
          for LOC in $(printf '%s' "${PLAY_CHANGELOG_LOCALES:-}" | tr ',' ' '); do
            SRC="android/fastlane/store/$LOC/changelog.txt"
            if [ ! -s "$SRC" ]; then
              echo "❌ $SRC 가 없거나 비어 있습니다 (PLAY_CHANGELOG_LOCALES=$PLAY_CHANGELOG_LOCALES)"
              exit 1
            fi
            mkdir -p "android/fastlane/metadata/android/$LOC/changelogs"
            cp "$SRC" "android/fastlane/metadata/android/$LOC/changelogs/${VERSION_CODE}.txt"
            echo "✅ 출시 노트($LOC) 준비 완료"
          done
''',
)

# 모두 한 곳과 맞는지 먼저 확인한 뒤에만 쓴다. 같은 파일을 여러 번 고치므로 메모리에서 이어서 치환한다.
contents = {}
for path, old, new in edits:
    p = pathlib.Path(path)
    s = contents.get(path, p.read_text(encoding='utf-8'))
    assert s.count(old) == 1, f'{path}: 한 곳과 맞아야 한다({s.count(old)}곳): {old[:50]!r}'
    contents[path] = s.replace(old, new)
for path, s in contents.items():
    pathlib.Path(path).write_text(s, encoding='utf-8')
print('수정한 파일:', *contents, sep='\n  ')
```

Run: 위 스크립트를 `/tmp/fastlane_edit.py` 로 저장하고 레포 루트에서 `python3 /tmp/fastlane_edit.py`
Expected: 수정한 파일 세 개(`Fastfile`, iOS 워크플로, Android 워크플로) 목록. Android 워크플로 부분은 Task 6 에서 검증·커밋한다.

- [ ] **Step 5: 문법을 확인한다**

Run:
```bash
ruby -c client/ios/fastlane/Fastfile
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml', encoding='utf-8')); print('YAML OK')"
```
Expected: `Syntax OK`, `YAML OK`

- [ ] **Step 6: ko 기본 동작이 이전과 같음을 확인한다**

Run:
```bash
ruby -r ./client/ios/fastlane/store_locales -e '
require "tmpdir"
Dir.mktmpdir do |t|
  p StoreLocales.parse_locales(nil), StoreLocales.parse_locales("")
  StoreLocales.write_release_notes(metadata_path: t, locales: StoreLocales.parse_locales(""), default_notes: "고쳤어요", store_dir: t + "/store")
  p Dir.children(t + "/ko"), File.read(t + "/ko/release_notes.txt")
end'
```
Expected: `["ko"]` 두 번, `["release_notes.txt"]`, `"고쳤어요"` — 이전 Fastfile 이 `ko` 폴더에 `release_notes.txt` 하나만 쓰던 것과 같다.

- [ ] **Step 7: 커밋 (`/pro-commit`) — 배포는 하지 않는다**

```bash
git add client/ios/fastlane/store_locales.rb client/ios/fastlane/test/store_locales_test.rb client/ios/fastlane/Fastfile .github/workflows/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml
```

(`PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` 은 Step 4 스크립트가 함께 고쳤지만 Task 6 에서 검증한 뒤 커밋한다.)

---

## Task 6: fastlane(Android) — 언어별 출시 노트

**Files:**
- Modify: `.github/workflows/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` (Task 5 Step 4 가 이미 고쳤다 — 여기서 검증하고 커밋한다)

**Interfaces:**
- Consumes: 레포 변수 `PLAY_CHANGELOG_LOCALES`(Play 로케일, 쉼표), 문구 원본 `client/android/fastlane/store/<로케일>/changelog.txt`
- Produces: `android/fastlane/metadata/android/<로케일>/changelogs/<버전코드>.txt`

`Fastfile.playstore` 는 `skip_upload_changelogs: false` 이고 `metadata/android/*/changelogs` 를 자동으로 읽으므로 **Fastfile 수정이 필요 없다.** 지금은 워크플로가 `ko-KR` 만 만든다. 변수가 비어 있으면(기본) 아무것도 하지 않아 동작이 같다. 비어 있지 않은데 노트 파일이 없으면 **배포를 멈춘다**(한국어 문구가 영어 노트로 올라가는 것보다 낫다).

`Fastfile.playstore` 의 `skip_upload_metadata: true` 때문에 Play 의 이름·설명·그래픽은 fastlane 이 올리지 않는다 — Play Console 에서 손으로 넣는다(Task 7 의 문서에 적는다).

- [ ] **Step 1: 변경이 들어갔는지 확인한다**

Run: `git diff .github/workflows/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`
Expected: 추가만 있다 — `PLAY_CHANGELOG_LOCALES: ${{ vars.PLAY_CHANGELOG_LOCALES }}` 한 줄(+주석)과 `for LOC in …; done` 블록. 삭제된 줄은 없다.

- [ ] **Step 2: YAML 문법을 확인한다**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml', encoding='utf-8')); print('YAML OK')"`
Expected: `YAML OK`

- [ ] **Step 3: 추가한 셸 블록을 시뮬레이션한다**

Run:
```bash
T=$(mktemp -d) && cd "$T" && mkdir -p android/fastlane/store/en-US
cat > snip.sh <<'EOF'
set -e
VERSION_CODE=236
for LOC in $(printf '%s' "${PLAY_CHANGELOG_LOCALES:-}" | tr ',' ' '); do
  SRC="android/fastlane/store/$LOC/changelog.txt"
  if [ ! -s "$SRC" ]; then
    echo "❌ $SRC 가 없거나 비어 있습니다 (PLAY_CHANGELOG_LOCALES=$PLAY_CHANGELOG_LOCALES)"
    exit 1
  fi
  mkdir -p "android/fastlane/metadata/android/$LOC/changelogs"
  cp "$SRC" "android/fastlane/metadata/android/$LOC/changelogs/${VERSION_CODE}.txt"
  echo "✅ 출시 노트($LOC) 준비 완료"
done
EOF
echo "--- 비어 있음(기본)"; PLAY_CHANGELOG_LOCALES="" bash snip.sh; echo "exit=$?"
echo "--- 파일 없음"; PLAY_CHANGELOG_LOCALES="en-US" bash snip.sh; echo "exit=$?"
echo "Bug fixes." > android/fastlane/store/en-US/changelog.txt
echo "--- 있음"; PLAY_CHANGELOG_LOCALES="en-US" bash snip.sh; ls android/fastlane/metadata/android/en-US/changelogs
```
Expected: 기본은 아무 출력 없이 `exit=0`, 파일이 없으면 `❌ …` 와 `exit=1`, 있으면 `✅ 출시 노트(en-US) 준비 완료` 와 `236.txt`. (워크플로 스크립트 조각과 같은 문장이다. 이 시뮬레이션은 임시 폴더에서만 돈다.)

- [ ] **Step 4: 커밋 (`/pro-commit`) — 배포는 하지 않는다**

```bash
git add .github/workflows/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml
```

---

## Task 7: 스토어 문구 원본의 언어별 구조와 심사 노트 전환 규칙

**Files:**
- Modify: `docs/projectops/store/20260921_스토어_문구_원본.md` (낡은 약속 정정 + 구조 안내)
- Modify: `docs/projectops/store/20260921_앱스토어_심사노트.md` (낡은 기록 표시)
- Create: `docs/projectops/store/i18n/README.md`
- Create: `docs/projectops/store/i18n/_template.md`

**Interfaces:**
- Consumes: Task 5·6 의 로케일 규칙, 계획 5 의 용어집·언어 오픈 체크리스트, 계획 7 의 언어별 개인정보 게시본
- Produces: 언어별 스토어 문구의 위치·코드·한도·순서, 심사 노트 `Korean-only` 를 바꾸는 시점과 방법, 앱별 언어의 알려진 한계(Android 12 이하는 OS 앱별 언어 없음)

**번역하기 전에 ko 원본의 낡은 약속을 먼저 고친다.** `스토어_문구_원본.md` 의 자세한 설명이 "이름이나 전화번호처럼 사람을 알아볼 수 있는 부분은 **먼저 가린 뒤에** 카드를 만들어요" 라고 적는다. DLP 는 #377 에서 폐기돼 보호자의 입력은 **가공 없이** AI 업체에 전달된다(루트 `CLAUDE.md` 서비스 원칙 2 — "가린다고 말하지 않는다"). 이 문장을 번역하면 다섯 언어로 사실과 다른 약속이 나간다. 같은 문서의 「콘솔에 실제로 넣은 값」은 설명을 "위 문구 그대로" 넣었다고 적어, **App Store Connect 와 Play Console 에 이미 올라간 설명에도 같은 문장이 남아 있을 가능성이 크다.** 콘솔 값은 이 계획이 고치지 않는다 — **사용자가 확인하고 갱신한다**(D3).

`20260921_앱스토어_심사노트.md` 도 낡았다("개인 식별 정보를 가린다", "No ads"). 현재 원본은 `client/ios/fastlane/review_notes.txt` 이고 배포 때 그것이 덮어쓴다. 본문을 고치지 않고 낡은 기록임을 머리에 표시한다.

- [ ] **Step 1: 낡은 문장이 지금 있는지 확인한다**

Run: `grep -n "먼저 가린 뒤" docs/projectops/store/20260921_스토어_문구_원본.md`
Expected: 한 줄이 나온다. 안 나오면 이미 누가 고친 것이다 — Step 2 는 하지 않고 Step 3 으로 간다(스크립트는 앵커가 없으면 멈추고 아무것도 쓰지 않는다).

- [ ] **Step 2: 한국어 원본을 정정하고 낡은 기록을 표시한다**

레포 루트에서 실행한다.

```python
# 번역하기 전에 한국어 스토어 문구의 낡은 약속을 고치고, 낡은 심사 노트 기록에 안내를 단다.
# 레포 루트에서 실행: python3 이 파일. 치환이 정확히 한 곳과 맞지 않으면 멈춘다.
import pathlib

BASE = pathlib.Path('docs/projectops/store')

copy_path = BASE / '20260921_스토어_문구_원본.md'
s = copy_path.read_text(encoding='utf-8')
old = '''■ 적은 내용을 그대로 내보내지 않아요
이름이나 전화번호처럼 사람을 알아볼 수 있는 부분은 먼저 가린 뒤에 카드를 만들어요.
무엇을 모으고 어떻게 다루는지는 앱 안 설정과 개인정보처리방침에 적어 두었어요.
'''
new = '''■ 개인정보는 적지 말아 주세요
보호자가 쓴 문장은 가공하지 않고 AI 업체에 그대로 전달돼요. 이름이나 전화번호처럼 사람을 알아볼 수 있는 정보는 적지 말아 주세요.
무엇을 모으고 어떻게 다루는지는 앱 안 설정과 개인정보처리방침에 적어 두었어요.
'''
assert s.count(old) == 1, '스토어 문구 원본의 "먼저 가린 뒤" 문단이 한 곳과 맞아야 한다'
head_old = '# 스토어 문구 초안 (용어 규칙 적용: 이룸이 / 휴대폰 / 보상 / 해요체)\n'
assert s.count(head_old) == 1
s = s.replace(old, new).replace(
    head_old,
    head_old
    + '\n> 언어별 문구는 [`i18n/`](./i18n/README.md) 에 둔다 (#521). 이 문서가 **한국어 원본**이다.\n'
    + '> 2026-10-02 에 "먼저 가린 뒤에 카드를 만들어요" 문단을 사실에 맞게 고쳤다 — DLP 는 #377 에서 폐기돼 보호자의 입력은\n'
    + '> 가공 없이 전달된다. **스토어 콘솔(App Store Connect · Play Console)에 이미 들어간 설명은 이 수정이 자동으로 반영되지 않는다.**\n',
)
copy_path.write_text(s, encoding='utf-8')

notes_path = BASE / '20260921_앱스토어_심사노트.md'
n = notes_path.read_text(encoding='utf-8')
title = '# App Store 심사 노트 (App Review Information > Notes)\n'
assert n.count(title) == 1
n = n.replace(
    title,
    title
    + '\n> ⚠️ **낡은 기록이다(2026-09-21).** 현재 심사 노트 원본은 `client/ios/fastlane/review_notes.txt` 이고 배포 때 그 내용이 덮어쓴다.\n'
    + '> 아래 본문의 "개인 식별 정보를 가린다 · No ads" 는 DLP 폐기(#377)와 광고 도입 뒤 사실과 다르다. 이 문서를 복사해 쓰지 않는다.\n'
    + '> 언어를 여는 시점에 심사 노트를 바꾸는 법은 [`i18n/README.md`](./i18n/README.md) 를 본다.\n',
)
notes_path.write_text(n, encoding='utf-8')
print('스토어 문서 수정 완료')
```

Run: 위 스크립트를 `/tmp/store_docs_edit.py` 로 저장하고 레포 루트에서 `python3 /tmp/store_docs_edit.py`
Expected: `스토어 문서 수정 완료`

- [ ] **Step 3: 언어별 구조 문서를 만든다**

`docs/projectops/store/i18n/README.md`:

````markdown
# 스토어 문구 — 언어별 구조

> 이슈 [#521](https://github.com/Twin-Fang/elum/issues/521) · 한국어 원본은 [`../20260921_스토어_문구_원본.md`](../20260921_스토어_문구_원본.md).
> 번역 용어는 [`docs/i18n/glossary.md`](../../../i18n/glossary.md)를 따른다. 언어를 여는 순서는
> [`docs/i18n/language-launch-checklist.md`](../../../i18n/language-launch-checklist.md).

## 어디에 무엇이 사나

| 문구 | 원본(사람이 읽는 것) | 올라가는 곳 | 어떻게 올라가나 |
| --- | --- | --- | --- |
| App Store 이름·부제·설명·키워드·프로모션·지원 URL·개인정보 URL | `i18n/<로케일>.md` | `client/ios/fastlane/store/<ASC 로케일>/*.txt` | 배포 때 fastlane `deliver` 가 올린다(`store_prepare`·`store_submit` 모드) |
| App Store 새로운 기능(What's New) | 같은 `.md` | `store/<ASC 로케일>/release_notes.txt` | 위와 같다. **ko 는 파일을 두지 않는다**(워크플로 `STORE_WHATS_NEW_OVERRIDE`) |
| Play 이름·간단한 설명·자세한 설명 | 같은 `.md` | Play Console | **손으로 넣는다.** `Fastfile.playstore` 는 `skip_upload_metadata: true` 다 |
| Play 출시 노트 | 같은 `.md` | `client/android/fastlane/store/<Play 로케일>/changelog.txt` | 배포 워크플로가 `metadata/android/<로케일>/changelogs/<버전코드>.txt` 로 복사한다 |
| 심사 노트(App Review Notes) | `client/ios/fastlane/review_notes.txt` | App Store Connect | 배포 때 덮어쓴다. ASC 에서 고치면 다음 제출에 덮인다 |

**한국어는 `store/` 폴더를 만들지 않는다.** ASC 에 이미 들어 있는 한국어 설명·키워드를 덮어쓰지 않으려는 것이다.
다른 언어는 새 로컬라이제이션을 만드는 것이라 이름·설명·키워드 같은 필드가 비면 심사 제출이 막힐 수 있다
(ASC 의 정확한 요구는 **첫 언어를 추가할 때 실제로 확인한다**). 그래서 파일 일곱 개가 모두 있어야 하고,
하나라도 빠지면 배포 단계(`StoreLocales`)가 ASC 로 넘어가기 전에 멈춘다.

## 로케일 코드

| 앱 언어 | ASC(deliver) | Play | 비고 |
| --- | --- | --- | --- |
| ko | `ko` | `ko-KR` | 지금 있는 값 |
| en | `en-US` | `en-US` | |
| ja | `ja` | `ja-JP` | |
| zh | `zh-Hans` | `zh-CN` | 간체만. 번체는 범위 밖 |
| es | `es-ES` 또는 `es-MX` | `es-ES` 또는 `es-419` | **변종은 결정 대기**(용어집 결정 항목). 정하기 전에는 열지 않는다 |

`ko-KR` 은 deliver 가 모르는 코드다(ASC 는 `ko`). 잘못 적으면 `StoreLocales.parse_locales` 가 배포 전에 멈춘다.

## 글자 수 한도

| 필드 | App Store | Play |
| --- | --- | --- |
| 이름 | 30 | 30 |
| 부제 | 30 | — |
| 간단한 설명 | — | 80 |
| 키워드 | 100(쉼표 포함) | — |
| 프로모션 텍스트 | 170 | — |
| 자세한 설명 | 4000 | 4000 |
| 출시 노트 | 4000 | 500 |

한도는 **번역된 글자 수** 기준이다. 일본어·중국어는 짧고 스페인어는 길어 한국어 기준으로 맞춘 문구가 넘칠 수 있다.
클라이언트 테스트(`native_locale_resources_test.dart`)가 켜진 언어의 이름·부제·키워드·프로모션·Play 출시 노트 한도를 본다.

## 새 언어 문구를 만드는 순서

1. `_template.md` 를 `<앱 언어 코드>.md`(예: `en.md`)로 복사해 항목을 번역한다. 용어집 용어를 쓴다.
2. 아래를 **쓰지 않는다**: 한국어 원본의 낡은 약속. 특히 "먼저 가린 뒤에 카드를 만든다"는 DLP 폐기(#377) 뒤로 사실이 아니다.
   보호자가 쓴 문장은 가공 없이 AI 업체에 전달된다. 개인정보를 적지 말라고 안내하는 쪽으로 쓴다.
3. 개인정보처리방침 URL 은 **그 언어의 게시본**을 가리킨다(계획 7 · 게시본이 없으면 열지 않는다).
4. `client/ios/fastlane/store/<ASC 로케일>/` 에 `name.txt` `subtitle.txt` `description.txt` `keywords.txt` `promotional_text.txt`(선택)
   `release_notes.txt` `support_url.txt` `privacy_url.txt` 를 만든다. 파일 하나에 값 하나, 끝 줄바꿈은 무시한다.
5. `client/android/fastlane/store/<Play 로케일>/changelog.txt` 를 만든다(500자 안).
6. 레포 변수 `IOS_DELIVER_LOCALES`(예: `ko,en-US`)와 `PLAY_CHANGELOG_LOCALES`(예: `en-US`)에 로케일을 더한다. 변수는 마지막에 바꾼다 —
   문구 파일이 머지되기 전에 변수를 먼저 바꾸면 배포가 멈춘다.
7. 심사 노트를 아래 표대로 바꾼다.
8. Play Console 의 언어별 스토어 등록정보는 손으로 넣는다(이름·설명·그래픽·스크린샷).

## 심사 노트(`review_notes.txt`)를 언어 오픈에 맞추는 법

지금 첫 문단이 "The app is Korean-only." 라고 말한다. 언어를 하나라도 열면 **이 문장이 사실이 아니다.**
테스트가 이를 지킨다(켜진 언어가 있는데 `Korean-only` 가 남아 있으면 실패).

| 단계 | 바꾸는 시점 | 문장 |
| --- | --- | --- |
| ko 만 | 지금 | `The app is Korean-only.` 그대로 |
| en 이 열림 | **en 을 켜는 PR 과 같은 PR** | `The app is available in Korean and English and follows the device language. To review in English, keep the device language set to English.` |
| en 이후 언어 | 그 언어를 켜는 PR | 목록에 언어를 더한다 |

문장만 바꾸면 안 된다. 심사자의 휴대폰은 보통 영어다. 한 번 영어가 열리면 앱은 영어로 뜨는데, 심사 노트가 한국어 버튼 이름
(`"Apple로 계속하기"`, `"새로운 일과 만들기"`)을 말하면 심사자가 버튼을 못 찾는다. 같은 PR 에서 **노트에 인용한 화면 문구를
영어 ARB(`app_en.arb`)의 값으로 다시 옮기고 한국어 문구를 괄호로 곁들인다.** 예: `tap "Continue with Apple" (Apple로 계속하기)`.
샘플 일과 입력 예시도 영어로 바꾼다(그 언어로 일과를 만들 수 있어야 한다 — `ENABLED_CONTENT_LOCALES` 에 en 이 켜진 뒤).

## 앱별 언어 — 알려진 한계

앱 안에는 언어 선택 화면이 없다(스펙 4.1). 언어를 바꾸려면 OS 설정을 쓴다.

- **Android 12 이하(API 32 이하)에는 OS 의 앱별 언어가 없다.** 이 휴대폰에서는 `locales_config.xml` 이 무시되고, **휴대폰 언어를 바꿔야** 앱 언어와 앱 이름이 바뀐다.
- iOS 는 설정 > 이룸 > 언어, Android 13+ 는 설정 > 앱 > 이룸 > 언어에서 바꾼다. 목록에 뜨는 언어는 `Info.plist` 의
  `CFBundleLocalizations` 와 `res/xml/locales_config.xml` 이 정한다(둘은 같은 다섯 개여야 한다).
- 휴대폰은 영어인데 앱만 한국어로 쓰고 싶은 사용자는 설정 앱까지 가야 한다. 요청이 쌓이면 앱 안 선택을 나중에 더한다.
- 리소스(`values-*`)에 값이 없는 언어는 기본(영어)으로 떨어진다. 5개 밖 언어 휴대폰의 앱 이름·권한 문구도 영어다.
- 리소스 용량을 줄이려고 Android 에 `localeFilters`/`resourceConfigurations` 를 넣게 되면 **다섯 언어를 모두** 포함해야 한다.
````

`docs/projectops/store/i18n/_template.md`:

````markdown
# 스토어 문구 — <언어 이름> (`<앱 언어 코드>`)

- 상태: 번역 전 / 초안 / 검수 완료
- 검수자: (미정)
- ASC 로케일: `<en-US 등>` · Play 로케일: `<en-US 등>`
- 번역 기준: [용어집](../../../i18n/glossary.md) · 한국어 원본 [`../20260921_스토어_문구_원본.md`](../20260921_스토어_문구_원본.md)

> 한국어 원본의 낡은 문장("먼저 가린 뒤에 카드를 만든다")을 옮기지 않는다. 보호자의 입력은 가공 없이 AI 업체에 전달된다.

## 이름
- App Store(30자):
- Play(30자):

## 부제 (App Store, 30자)

## 간단한 설명 (Play, 80자)

## 자세한 설명 (두 스토어 공용, 4000자)

## 키워드 (App Store, 100자, 쉼표로 구분)

## 프로모션 텍스트 (App Store, 170자)

## 새로운 기능 · 출시 노트
- App Store(고정 문구):
- Play(500자):

## 공개 주소 (이 언어의 게시본)
- 개인정보처리방침:
- 지원:
````

- [ ] **Step 4: 정정과 링크를 확인한다**

Run:
```bash
grep -rn "먼저 가린 뒤에 카드를" docs/projectops/store || echo "낡은 문장 없음"
ls docs/projectops/store/i18n
grep -n "Korean-only" docs/projectops/store/i18n/README.md client/ios/fastlane/review_notes.txt
```
Expected: 첫 grep 은 정정 안내 문단의 인용(따옴표 안)만 남는다 — 본문 문장이 아니다. `README.md`·`_template.md` 가 있다. `review_notes.txt` 는 지금 `Korean-only` 를 그대로 가진다(ko 만 켜져 있어 사실이다 — 계약 테스트가 이를 확인한다).

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add docs/projectops/store/20260921_스토어_문구_원본.md docs/projectops/store/20260921_앱스토어_심사노트.md docs/projectops/store/i18n/README.md docs/projectops/store/i18n/_template.md
```

---

## Task 8: 검증 — 빌드 없이 볼 것과 실기기에서 볼 것

**Files:** 없음 (결과는 이슈 #521 댓글로 남긴다 — `/pro-report`)

**Interfaces:**
- Consumes: Task 1~7
- Produces: 이 계획이 "끝났다"고 말할 수 있는 근거. **통과를 확인하기 전에 완료라고 말하지 않는다.**

이 계획은 **배포하지 않는다.** 아래 A 는 이 PC 에서 끝나고, B 는 시뮬레이터·실기기에서만 확인된다. B 를 아직 안 했으면 완료 보고에 "B 미확인"이라고 적는다.

### A. 빌드 없이 확인 (이 PC)

- [ ] **Step 1: 파일 문법**

Run:
```bash
plutil -lint client/ios/Runner/Info.plist client/ios/Runner/*.lproj/InfoPlist.strings
plutil -convert json -o /dev/null client/ios/Runner.xcodeproj/project.pbxproj && echo "pbxproj OK"
(cd client/ios && xcodebuild -project Runner.xcodeproj -list >/dev/null && echo "xcodebuild -list OK")
xmllint --noout client/android/app/src/main/AndroidManifest.xml client/android/app/src/main/res/values*/strings.xml client/android/app/src/main/res/xml/locales_config.xml && echo "XML OK"
ruby -c client/ios/fastlane/Fastfile client/ios/fastlane/store_locales.rb
for f in PROJECT-FLUTTER-IOS-TESTFLIGHT PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD; do python3 -c "import yaml; yaml.safe_load(open('.github/workflows/$f.yaml', encoding='utf-8')); print('$f OK')"; done
```
Expected: 전부 `OK` / `Syntax OK`

- [ ] **Step 2: 파일 존재와 계약**

Run: `cd client && flutter test test/native_locale_resources_test.dart && ruby ios/fastlane/test/store_locales_test.rb`
Expected: Dart 22건 PASS, Ruby `7 runs, 20 assertions, 0 failures`

- [ ] **Step 3: 앱 전체 회귀**

Run: `cd client && flutter analyze && flutter test --exclude-tags golden`
Expected: analyze `No issues found!`, 테스트 전부 PASS. 네이티브 파일만 바꿨으므로 앱 테스트 결과는 이전과 같아야 한다. (`figma_ko_only_guard_test.dart` 가 계획 1 전에 실패하는 것은 이 계획과 무관하다.)

- [ ] **Step 4: Android 리소스 링크 (SDK 가 있을 때)**

Task 4 Step 4 의 명령을 다시 돌려 `application-label-ko:'이룸'` 을 확인한다.

### B. 시뮬레이터·실기기에서 확인 (빌드 필요)

기기 조작은 `/pro-launch` 로 한다. 좌표 클릭·`cliclick` 은 쓰지 않는다. iOS 시뮬레이터는 Maestro(`client/e2e`)를 쓴다.

- [ ] **Step 5: iOS — 설정에 5개 언어가 뜬다**

시뮬레이터에 debug 앱을 설치한 뒤 설정 > 이룸 > 언어에 `한국어 · English · 日本語 · 简体中文 · Español` 이 뜨는지 본다. `日本語` 를 고르고 앱을 다시 열어 홈 화면 앱 이름이 `ELUM`(영어 대체 문구)인지, 카메라 권한 팝업 문구가 영어 대체 문구인지 본다. 다시 `한국어` 로 돌려 `이룸` 과 이전 문구가 나오는지 본다.
Expected: 5개 언어 노출 / 일본어에서 영어 대체 문구 / 한국어에서 이전 값 그대로. 5개가 안 뜨면 `CFBundleLocalizations` · `knownRegions` · 변형 그룹(Task 2·3) 중 빠진 것을 찾는다.

- [ ] **Step 6: iOS — 5개 밖 언어는 영어로 떨어진다**

시뮬레이터 언어를 `Français` 로 바꿔 앱 이름·권한 문구가 영어 대체 문구인지 본다.
Expected: `ELUM`. (한국어가 보이면 `developmentRegion`/`en.lproj` 등록이 빠진 것이다.)

- [ ] **Step 7: Android 13+ — 설정에 5개 언어가 뜬다**

API 33 이상 에뮬레이터에 debug 앱을 설치한다. 설정 > 앱 > 이룸 > 언어에 다섯 언어가 뜨는지 본다. 명령으로도 확인한다:
```bash
adb shell cmd locale set-app-locales kr.twinfang.elum --user 0 --locales ja
adb shell cmd locale get-app-locales kr.twinfang.elum --user 0
adb shell cmd locale set-app-locales kr.twinfang.elum --user 0 --locales ko
```
Expected: 다섯 언어 노출. `ja` 로 바꾸면 런처의 앱 이름이 `ELUM`, `ko` 로 돌리면 `이룸`. 목록에 중국어가 안 뜨면 `locales_config.xml` 의 `zh-Hans-CN` 을 `zh-Hans` 로 바꿔 다시 확인한다(OS 별 태그 해석 차이는 이 PC 에서 알 수 없다).

- [ ] **Step 8: Android 12 이하 — 한계 확인**

API 32 이하 에뮬레이터에서 앱별 언어 항목이 **없고** 휴대폰 언어를 바꾸면 앱 이름이 바뀌는지 본다.
Expected: 앱별 언어 항목 없음(문서화된 한계). 휴대폰 언어 `日本語` → `ELUM`, `한국어` → `이룸`.

- [ ] **Step 9: Android — 릴리스(R8) 빌드에서도 이름이 맞다**

R8 로 축소한 릴리스 APK 는 리소스 필터 영향을 받을 수 있다(과거 릴리스에서만 터진 전례가 있다). 릴리스 APK 를 빌드해 `aapt2 dump badging <apk> | grep application-label` 의 결과가 Task 4 Step 4 와 같은지 본다. (서명 키가 필요하므로 로컬 `key.properties` 가 있을 때만 한다. 없으면 "릴리스 미확인"으로 기록한다.)

- [ ] **Step 10: 결과를 이슈에 남긴다 (`/pro-report`)**

A 의 명령 출력, B 에서 확인한 것과 못 한 것(기기·OS 버전 포함), 사용자 결정 D1~D3 을 이슈 #521 댓글로 남긴다.

---

## 사용자 결정 (이 계획이 정하지 않는다)

| # | 결정 | 영향 |
| --- | --- | --- |
| D1 | 5개 언어를 **지금** OS 목록에 노출할지, 열 때마다 더할지 | 지금 올리면 스토어 앱의 설정 > 언어에 열지 않은 언어까지 뜬다. 열 때마다 더하려면 `CFBundleLocalizations`·`locales_config.xml` 을 `ko` 만 남기고 언어를 열 때 한 줄씩 더한다(계약 테스트의 목록 기대값도 같이 바꾼다) |
| D2 | 서비스 이름의 영문·현지 표기(임시 `ELUM`) | `InfoPlist.strings`·`strings.xml`·스토어 이름 |
| D3 | 이미 올라간 스토어 콘솔 설명의 "먼저 가린 뒤에" 문장을 갱신 | App Store Connect·Play Console 은 사용자만 고친다. 이 계획은 레포 문서만 정정한다 |
| D4 | 스페인어 변종(`es-ES` / `es-MX` · Play `es-ES` / `es-419`) | 스토어 로케일 코드, 약관·개인정보 법역(계획 7) |

배포는 하지 않는다. 이 계획의 산출물은 파일·테스트·CI 설정이며, 앱 배포는 사용자가 "배포해줘"라고 할 때만 한다.
