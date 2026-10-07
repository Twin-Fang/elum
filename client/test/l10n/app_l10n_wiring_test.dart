import 'package:elum/core/l10n/app_l10n.dart';
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `app.dart` 가 쓰는 [AppL10n.routerArgs] 로 앱을 띄워 언어 배선을 확인한다.
///
/// `app.dart` 가 이 진입점을 실제로 쓰는지는 `app_dart_wiring_contract_test.dart` 가 지킨다.
void main() {
  /// 진입점이 만든 인자를 그대로 `MaterialApp` 에 꽂는다 — 인자를 테스트가 따로 고르지 않는다.
  Widget app({
    Locale? forced,
    bool devTools = true,
    Widget home = const SizedBox(),
    TransitionBuilder? inner,
    ThemeData? theme,
  }) {
    final a = AppL10n.routerArgs(
      forcedLocale: forced,
      devToolsEnabled: devTools,
      inner: inner ?? (context, child) => child ?? const SizedBox.shrink(),
    );
    return MaterialApp(
      theme: theme,
      locale: a.locale,
      supportedLocales: a.supportedLocales,
      localizationsDelegates: a.localizationsDelegates,
      localeListResolutionCallback: a.localeListResolutionCallback,
      onGenerateTitle: a.onGenerateTitle,
      builder: a.builder,
      home: home,
    );
  }

  Future<String> pumpPhone(
    WidgetTester tester,
    List<Locale> phone, {
    Locale? forced,
    bool devTools = true,
  }) async {
    tester.platformDispatcher.localesTestValue = phone;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    late String name;
    await tester.pumpWidget(
      app(
        forced: forced,
        devTools: devTools,
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
  testWidgets('영어면 en', (t) async => expect(await pumpPhone(t, const [Locale('en', 'US')]), 'en'));
  testWidgets('열지 않은 스페인어(멕시코)는 en', (t) async => expect(await pumpPhone(t, const [Locale('es', 'MX')]), 'en'));
  testWidgets('열지 않은 중국어 간체는 en', (t) async {
    expect(
      await pumpPhone(t, const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN')]),
      'en',
    );
  });
  testWidgets('프랑스어는 en', (t) async => expect(await pumpPhone(t, const [Locale('fr', 'FR')]), 'en'));
  testWidgets('번체 중국어는 en', (t) async => expect(await pumpPhone(t, const [Locale('zh', 'TW')]), 'en'));
  testWidgets('개발자 도구가 강제한 언어는 휴대폰 언어를 이긴다', (t) async {
    expect(await pumpPhone(t, const [Locale('ko', 'KR')], forced: const Locale('ja')), 'ja');
  });
  testWidgets('개발자 도구가 꺼진 빌드에서는 강제 언어를 무시한다', (t) async {
    expect(
      await pumpPhone(t, const [Locale('ko', 'KR')], forced: const Locale('ja'), devTools: false),
      'ko',
    );
  });

  testWidgets('앱 이름은 onGenerateTitle 로 ARB 에서 읽는다(en 에 키가 없으면 ko)', (t) async {
    await t.pumpWidget(app(forced: const Locale('en')));
    expect(t.widget<Title>(find.byType(Title)).title, '이룸');
  });

  group('themed — 언어별 글꼴 테마', () {
    Future<List<String>?> fallbackIn(WidgetTester tester, Locale locale) async {
      List<String>? fallback;
      await tester.pumpWidget(
        app(
          forced: locale,
          theme: AppTheme.light,
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

  group('routerArgs — builder 배선', () {
    tearDown(setAppL10nForTest);

    testWidgets('inner 는 Localizations 아래에서 불리고 ko 에서는 래퍼가 늘지 않는다', (t) async {
      bool? underLocalizations;
      await t.pumpWidget(
        app(
          forced: const Locale('ko'),
          inner: (context, child) {
            underLocalizations =
                Localizations.of<AppLocalizations>(context, AppLocalizations) != null;
            return child!;
          },
        ),
      );
      expect(underLocalizations, isTrue);
    });

    testWidgets('언어를 바꾸면 appL10n(전역 통로)이 따라 바뀌고 context.l10n 위젯이 다시 그려진다', (t) async {
      var builds = 0;
      final home = Builder(
        builder: (context) {
          builds++;
          context.l10n;
          return const SizedBox();
        },
      );

      await t.pumpWidget(app(forced: const Locale('ko'), home: home));
      expect(appL10n.localeName, 'ko');
      final before = builds;

      await t.pumpWidget(app(forced: const Locale('es'), home: home));
      expect(appL10n.localeName, 'es');
      expect(builds, greaterThan(before));

      await t.pumpWidget(app(forced: const Locale('ja'), home: home));
      expect(appL10n.localeName, 'ja');
    });
  });
}
