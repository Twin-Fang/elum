import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('번역 delegate 가 없는 MaterialApp 에서도 ko 문구가 나온다 — 기존 테스트가 그대로 돈다', (tester) async {
    late String confirm;
    late Locale locale;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            confirm = context.l10n.commonConfirm;
            locale = context.appLocale;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(confirm, '확인');
    // MaterialApp 의 기본 언어는 en_US 지만 앱 언어는 ko 다 — keepWords 같은 언어 분기가 ko 로 돈다
    expect(locale, const Locale('ko'));
  });

  testWidgets('번역 delegate 가 있으면 그 언어를 쓴다', (tester) async {
    late String localeName;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: supportedAppLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            localeName = context.l10n.localeName;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(localeName, 'es');
  });

  testWidgets('번역이 빈 언어는 문구가 ko 로 채워져 화면이 깨지지 않는다', (tester) async {
    late String confirm;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: supportedAppLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            confirm = context.l10n.commonConfirm;
            return const SizedBox();
          },
        ),
      ),
    );

    // 골격 단계 — ja ARB 가 비어 있다. 번역이 들어오면 이 기대를 ja 문구로 고친다.
    expect(confirm, isNotEmpty);
  });
}
