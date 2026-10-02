import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(setAppL10nForTest);

  test('처음에는 ko 다 — 앱을 띄우지 않는 단위 테스트가 그대로 돈다', () {
    expect(appL10n.localeName, 'ko');
    expect(appL10n.commonConfirm, '확인');
  });

  testWidgets('syncAppL10n 은 현재 트리의 번역으로 맞춘다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('ko'), Locale('es')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            syncAppL10n(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(appL10n.localeName, 'es');
  });

  testWidgets('번역 delegate 가 없으면 건드리지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            syncAppL10n(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(appL10n.localeName, 'ko');
  });

  test('테스트가 통로를 직접 정할 수 있다', () {
    setAppL10nForTest(lookupAppLocalizations(const Locale('es')));
    expect(appL10n.localeName, 'es');
    setAppL10nForTest();
    expect(appL10n.localeName, 'ko');
  });
}
