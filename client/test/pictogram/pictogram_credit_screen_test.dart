import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:elum/features/guardian/presentation/pictogram_credit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/semantics_audit.dart';
import '../helpers/test_storage.dart';

/// 그림 출처 화면 (#469) — CC BY-SA 4.0 은 앱 안에서 저작자와 라이선스를 밝혀야 한다.
void main() {
  useFigmaViewport();

  final opened = <Uri>[];
  var launchResult = true;

  Widget wrap(Widget home, {double textScale = 1.0}) => ProviderScope(
    overrides: [
      testStorageOverride(),
      consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
      appVersionProvider.overrideWith((ref) async => '1.0.0'),
      linkLauncherProvider.overrideWithValue((url) async {
        opened.add(url);
        return launchResult;
      }),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );

  setUp(() {
    opened.clear();
    launchResult = true;
  });

  testWidgets('설정에 그림 출처 줄이 있고 누르면 화면이 열린다', (tester) async {
    await tester.pumpWidget(wrap(const GuardianSettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('그림 출처'));
    await tester.pumpAndSettle();

    expect(find.byType(PictogramCreditScreen), findsOneWidget);
  });

  testWidgets('권장 표기문 원문과 저작권·주소·라이선스 링크가 그대로 있다', (tester) async {
    await tester.pumpWidget(wrap(const PictogramCreditScreen()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Mulberry Symbols by Steve Lee are licenced under the Creative Commons '
        'Attribution-ShareAlike 4.0 License. See https://mulberrysymbols.org for details',
      ),
      findsOneWidget,
    );
    expect(find.text('Copyright 2018-2026 Steve Lee'), findsOneWidget);
    expect(find.text('https://mulberrysymbols.org'), findsOneWidget);
    expect(find.text('https://creativecommons.org/licenses/by-sa/4.0/'), findsOneWidget);
  });

  testWidgets('화면 문구에 아이·아동이 없다 (용어 규칙)', (tester) async {
    await tester.pumpWidget(wrap(const PictogramCreditScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('아이'), findsNothing);
    expect(find.textContaining('아동'), findsNothing);
  });

  testWidgets('링크를 누르면 그 주소를 연다', (tester) async {
    await tester.pumpWidget(wrap(const PictogramCreditScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(PictogramCreditScreen.siteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictogramCreditScreen.licenseKey));
    await tester.pumpAndSettle();

    expect(opened.map((u) => u.toString()), [
      'https://mulberrysymbols.org',
      'https://creativecommons.org/licenses/by-sa/4.0/',
    ]);
  });

  testWidgets('E14 주소를 열지 못하면 에러 코드와 함께 알리고 화면은 그대로다', (tester) async {
    launchResult = false;
    await tester.pumpWidget(wrap(const PictogramCreditScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(PictogramCreditScreen.siteKey));
    await tester.pumpAndSettle();

    expect(find.text('E-LINK'), findsOneWidget);
    expect(find.textContaining('주소를 열지 못했어요'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    // 주소는 글자로 남아 있어 직접 찾아갈 수 있다
    expect(find.text('https://mulberrysymbols.org'), findsOneWidget);
  });

  testWidgets('E10 글자 200% · E9 작은 폰에서도 넘치지 않고 끝까지 스크롤된다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(wrap(const PictogramCreditScreen(), textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('https://creativecommons.org/licenses/by-sa/4.0/'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('뒤로가기·링크가 이름 있는 버튼으로 읽힌다', (tester) async {
    await tester.pumpWidget(wrap(const PictogramCreditScreen()));
    await tester.pumpAndSettle();

    expectLabeledButton(tester, '뒤로 가기');
    expect(unnamedTapTargets(tester), isEmpty);
  });
}
