import 'package:elum/core/l10n/app_l10n.dart';
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `app.dart` 가 쓰는 [AppL10n] 상수로 앱을 띄워 휴대폰 언어 → 앱 언어를 확인한다.
void main() {
  Future<String> pumpPhone(
    WidgetTester tester,
    List<Locale> phone, {
    Locale? forced,
  }) async {
    tester.platformDispatcher.localesTestValue = phone;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    late String name;
    await tester.pumpWidget(
      MaterialApp(
        locale: forced,
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.delegates,
        localeListResolutionCallback: AppL10n.resolveLocales,
        home: Builder(
          builder: (context) {
            name = context.l10n.localeName;
            return const SizedBox();
          },
        ),
      ),
    );
    return name;
  }

  testWidgets('휴대폰이 한국어면 ko', (t) async => expect(await pumpPhone(t, const [Locale('ko', 'KR')]), 'ko'));
  testWidgets('스페인어(멕시코)면 es', (t) async => expect(await pumpPhone(t, const [Locale('es', 'MX')]), 'es'));
  testWidgets('중국어 간체면 zh', (t) async {
    expect(
      await pumpPhone(t, const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN')]),
      'zh',
    );
  });
  testWidgets('프랑스어는 en', (t) async => expect(await pumpPhone(t, const [Locale('fr', 'FR')]), 'en'));
  testWidgets('번체 중국어는 en', (t) async => expect(await pumpPhone(t, const [Locale('zh', 'TW')]), 'en'));
  testWidgets('개발자 도구가 강제한 언어는 휴대폰 언어를 이긴다', (t) async {
    expect(await pumpPhone(t, const [Locale('ko', 'KR')], forced: const Locale('ja')), 'ja');
  });

  group('themed — 언어별 글꼴 테마', () {
    Future<List<String>?> fallbackIn(WidgetTester tester, Locale locale) async {
      List<String>? fallback;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          theme: AppTheme.light,
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.delegates,
          builder: (context, child) => AppL10n.themed(context, child!),
          home: Builder(
            builder: (context) {
              fallback = Theme.of(context).textTheme.bodyMedium!.fontFamilyFallback;
              return const SizedBox();
            },
          ),
        ),
      );
      return fallback;
    }

    testWidgets('ko 는 트리를 건드리지 않는다 — 대체 글꼴 없음', (t) async {
      expect(await fallbackIn(t, const Locale('ko')), isNull);
    });

    testWidgets('es 는 Pretendard 를 입힌다', (t) async {
      expect(await fallbackIn(t, const Locale('es')), ['Pretendard']);
    });

    testWidgets('ja 는 Pretendard 다음에 시스템 글꼴을 입힌다', (t) async {
      final fallback = await fallbackIn(t, const Locale('ja'));
      expect(fallback!.first, 'Pretendard');
      expect(fallback, contains('Hiragino Sans'));
    });
  });

  group('syncAppL10n — builder 배선', () {
    tearDown(setAppL10nForTest);

    testWidgets('builder 의 context 는 Localizations 아래라 언어를 바꾸면 appL10n 이 따라 바뀐다', (t) async {
      bool? underLocalizations;
      var builds = 0;
      Widget app(Locale locale) => MaterialApp(
        locale: locale,
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.delegates,
        builder: (context, child) {
          // app.dart 의 builder 와 같은 순서 — 번역 통로를 먼저 맞춘다
          underLocalizations =
              Localizations.of<AppLocalizations>(context, AppLocalizations) != null;
          syncAppL10n(context);
          return child!;
        },
        home: Builder(
          builder: (context) {
            builds++;
            context.l10n;
            return const SizedBox();
          },
        ),
      );

      await t.pumpWidget(app(const Locale('ko')));
      expect(underLocalizations, isTrue);
      expect(appL10n.localeName, 'ko');
      final before = builds;

      await t.pumpWidget(app(const Locale('es')));
      expect(appL10n.localeName, 'es');
      expect(builds, greaterThan(before), reason: '언어가 바뀌면 context.l10n 을 읽는 위젯이 다시 그려진다');

      await t.pumpWidget(app(const Locale('ja')));
      expect(appL10n.localeName, 'ja');
    });
  });
}
