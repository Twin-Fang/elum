@Tags(['golden'])
library;

import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/presentation/role_select_screen.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 역할 선택 두 상태 (Figma 732:5176 · 732:5258 · 이슈 #229).
///
/// **레이아웃을 다시 짜지 않고 진짜 `RoleSelectScreen`을 렌더한다.** 재구성해서
/// 찍으면 화면이 바뀌어도 골든은 그대로라 회귀를 못 잡는다.
///
/// 폰트는 `test/flutter_test_config.dart`가 전역으로 싣는다 (이슈 #226).
void main() {
  late GoRouter router;

  /// 앞 화면에서 왔을 때만 뒤로가기가 그려지므로, 스택을 한 겹 쌓아 둔다.
  Widget wrap() {
    router = GoRouter(
      initialLocation: '/before',
      routes: [
        GoRoute(
          path: '/before',
          builder: (context, state) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'role',
              builder: (context, state) => const RoleSelectScreen(),
            ),
          ],
        ),
        GoRoute(
          path: Routes.onboardingName,
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: Routes.linkEnter,
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(InMemoryStorage())],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    // 뒤로가기가 그려지도록 스택을 쌓아 올린다
    router.push('/before/role');
    await tester.pumpAndSettle();
  }

  testWidgets('역할 선택 — 미선택', (tester) async {
    await open(tester);
    await expectLater(
      find.byType(RoleSelectScreen),
      matchesGoldenFile('goldens/role_none.png'),
    );
  });

  testWidgets('역할 선택 — 보호자', (tester) async {
    await open(tester);
    await tester.tap(find.text('보호자가 사용해요'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RoleSelectScreen),
      matchesGoldenFile('goldens/role_guardian.png'),
    );
  });
}
