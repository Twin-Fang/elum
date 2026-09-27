@Tags(['golden'])
library;

import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/pin_change_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 비밀암호 변경 네 상태 (#437). **시안이 없는 임시 화면이다** — 시안 요청은 #438.
///
/// 시안이 오면 이 골든은 시안 대조로 바꾼다. 지금은 회귀를 막고, 디자인 요청에
/// 붙일 캡처를 만드는 데 쓴다.
void main() {
  useFigmaViewport();

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.guardianPinChange,
      routes: [
        GoRoute(
          path: Routes.guardianPinChange,
          builder: (context, state) => const PinChangeScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [testStorageOverride(onboardingCompleted: true, pin: '1234')],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  Future<void> enter(WidgetTester tester, String pin) async {
    await tester.enterText(find.byType(TextField), pin);
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(PinChangeScreen),
    matchesGoldenFile('goldens/pin_change_$name.png'),
  );

  testWidgets('1 지금 암호', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await shot(tester, '1_verify');
  });

  testWidgets('2 지금 암호 틀림', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await enter(tester, '9999');
    await shot(tester, '2_verify_wrong');
  });

  testWidgets('3 새 암호', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await enter(tester, '1234');
    await shot(tester, '3_enter');
  });

  testWidgets('4 한번 더 맞음 — 저장하기가 나타난다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await enter(tester, '1234');
    await enter(tester, '5678');
    await enter(tester, '5678');
    await shot(tester, '4_confirm_done');
  });
}
