@Tags(['golden'])
library;

import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 로그인 화면 (Figma 238:1808 · 이슈 #230).
///
/// 제공자가 넷에서 셋으로 줄고 버튼마다 로고가 붙었다. **진짜 `LoginScreen`을
/// 렌더한다** — 레이아웃을 다시 짜서 찍으면 화면이 바뀌어도 골든이 그대로다.
///
/// 애플 버튼은 iOS에서만 뜨므로 이 골든에는 카카오·네이버만 담긴다.
/// 배경 장면이 무한 반복이라 `pumpAndSettle()`이 끝나지 않는다 — OS "동작 줄이기"를
/// 켜 idle을 만든다 (로그인 화면 테스트와 같은 이유).
void main() {
  useFigmaViewport();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.login,
      routes: [
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride()],
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

  testWidgets('제공자 셋 — 로고 붙은 버튼', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_providers.png'),
    );
  });
}
