import 'dart:convert';
import 'dart:io';

import 'package:elum/core/l10n/app_locales.dart';
import 'package:flutter_test/flutter_test.dart';

/// ARB 언어 간 키·자리표시자 일치 검사 (골격).
///
/// **언어를 연다는 것 = 그 언어가 [openedLocales] 에 들어온다는 것**이다. 열린 언어는
/// ko 템플릿의 모든 키와 자리표시자를 빠짐없이 가져야 한다. 아직 안 연 언어는 비어 있어도
/// 된다 — 이때 gen-l10n 이 빠진 키를 ko 문구로 채우므로 화면은 깨지지 않는다.
/// 번역을 채우면 이 목록을 늘린다.
const openedLocales = <String>{'ko', 'en'};

/// ko 에만 있고 다른 언어는 쓰지 않아도 되는 자리표시자.
/// `batchim` 은 한국어 조사 선택용이다 (`core/l10n/batchim.dart`).
const optionalPlaceholders = <String>{'batchim'};

const arbDir = 'lib/l10n';
const allLocales = ['ko', 'en', 'ja', 'zh', 'es'];

Map<String, dynamic> _read(String locale) =>
    jsonDecode(File('$arbDir/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// 메시지 키만 (`@@locale`, `@key` 메타 제외).
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// ko 메타(`@key.placeholders`)가 선언한 자리표시자 이름.
Set<String> _declared(Map<String, dynamic> ko, String key) {
  final meta = ko['@$key'];
  final ph = meta is Map ? meta['placeholders'] : null;
  return ph is Map ? ph.keys.cast<String>().toSet() : <String>{};
}

/// 문구가 자리표시자 [name] 을 쓰는가 (`{name}` 또는 ICU `{name, plural…}`).
bool _uses(String message, String name) =>
    message.contains('{$name}') || message.contains('{$name,');

void main() {
  test('5개 ARB 파일이 모두 있고 @@locale 이 파일 이름과 같다', () {
    for (final l in allLocales) {
      final f = File('$arbDir/app_$l.arb');
      expect(f.existsSync(), isTrue, reason: 'app_$l.arb 가 없다');
      expect(_read(l)['@@locale'], l, reason: 'app_$l.arb 의 @@locale 이 다르다');
    }
  });

  test('ko 문구의 자리표시자는 모두 @키 메타에 선언돼 있다', () {
    final ko = _read('ko');
    final bad = <String>[];
    final re = RegExp(r'\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?=[,}])');
    for (final k in _messageKeys(ko)) {
      final used = re.allMatches(ko[k] as String).map((m) => m.group(1)!).toSet();
      final undeclared = used.difference(_declared(ko, k));
      if (undeclared.isNotEmpty) bad.add('$k: $undeclared');
    }
    expect(bad, isEmpty, reason: '메타에 없는 자리표시자 — gen-l10n 이 거부한다');
  });

  test('앱이 여는 언어 목록과 번역을 검사하는 언어가 같다', () {
    expect(
      openedAppLocales.map((l) => l.languageCode).toSet(),
      openedLocales,
      reason: '언어를 열 때 openedAppLocales 와 이 파일의 openedLocales 를 함께 늘린다',
    );
  });

  for (final locale in allLocales.where(openedLocales.contains)) {
    if (locale == 'ko') continue;

    test('$locale — 열린 언어는 ko 의 모든 키를 가진다', () {
      final koKeys = _messageKeys(_read('ko'));
      final keys = _messageKeys(_read(locale));
      expect(koKeys.difference(keys), isEmpty, reason: '$locale 에 빠진 키');
      expect(keys.difference(koKeys), isEmpty, reason: '$locale 에만 있는 키');
    });

    test('$locale — 자리표시자를 ko 와 같이 쓴다', () {
      final ko = _read('ko');
      final other = _read(locale);
      final bad = <String>[];
      for (final k in _messageKeys(ko)) {
        final msg = other[k];
        if (msg is! String) continue; // 빠진 키는 위 테스트가 잡는다
        for (final p in _declared(ko, k).difference(optionalPlaceholders)) {
          if (!_uses(msg, p)) bad.add('$k 에서 {$p} 가 빠졌다');
        }
      }
      expect(bad, isEmpty);
    });
  }

  test('열리지 않은 언어는 비어 있거나 ko 의 부분집합이다', () {
    final koKeys = _messageKeys(_read('ko'));
    for (final l in allLocales.where((l) => !openedLocales.contains(l))) {
      expect(_messageKeys(_read(l)).difference(koKeys), isEmpty,
          reason: '$l 에 ko 에 없는 키가 있다');
    }
  });
}
