import 'package:elum/core/l10n/content_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_with_locale.dart';

void main() {
  group('normalizeContentLanguage', () {
    test('다섯 코드만 통과하고 나머지는 ko', () {
      for (final code in ['ko', 'en', 'ja', 'zh', 'es']) {
        expect(normalizeContentLanguage(code), code);
      }
      expect(normalizeContentLanguage('fr'), 'ko');
      expect(normalizeContentLanguage(''), 'ko');
      expect(normalizeContentLanguage(null), 'ko');
      expect(normalizeContentLanguage(3), 'ko');
    });
  });

  group('contentLocaleOf', () {
    test('코드를 Locale 로 — 중국어는 간체', () {
      expect(contentLocaleOf('ja'), const Locale('ja'));
      expect(
        contentLocaleOf('zh'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      );
      expect(contentLocaleOf(null), const Locale('ko'));
      expect(contentLocaleOf('fr'), const Locale('ko'));
    });
  });

  group('ContentLocale', () {
    testWidgets('아래 글자의 언어를 일과 언어로 싣는다 — 화면 언어와 달라도', (tester) async {
      // 화면 언어는 es, 일과 언어는 ja
      await pumpWithLocale(
        tester,
        const Scaffold(
          body: ContentLocale(language: 'ja', child: Text('こんにちは')),
        ),
        locale: const Locale('es'),
      );

      final style = DefaultTextStyle.of(tester.element(find.text('こんにちは'))).style;
      expect(style.locale, const Locale('ja'));
    });

    testWidgets('모르는 값이면 ko', (tester) async {
      await pumpWithLocale(
        tester,
        const Scaffold(body: ContentLocale(language: null, child: Text('가'))),
      );

      final style = DefaultTextStyle.of(tester.element(find.text('가'))).style;
      expect(style.locale, const Locale('ko'));
    });
  });
}
