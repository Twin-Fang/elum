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

/// 로그인 화면 (Figma `238:1808` iOS · `1022:4333` AOS · 이슈 #230 #338).
///
/// 제공자가 넷에서 셋으로 줄고 버튼마다 로고가 붙었다. **진짜 `LoginScreen`을
/// 렌더한다** — 레이아웃을 다시 짜서 찍으면 화면이 바뀌어도 골든이 그대로다.
///
/// **두 장을 찍는다.** 시안이 플랫폼별로 나와 병아리가 서로 반대쪽을 보고
/// 버튼 개수도 다르다 (#338). 한 장만 찍으면 나머지 한쪽은 아무도 안 본다 —
/// 실제로 안드로이드가 iOS 배치를 그대로 쓰고 있던 것이 그래서 안 드러났다.
///
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

  tearDown(() => LoginScreen.debugPretendIos = null);

  testWidgets('안드로이드 — 앞을 보는 병아리 · 버튼 둘', (tester) async {
    LoginScreen.debugPretendIos = false;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_providers.png'),
    );
  });

  testWidgets('iOS — 뒤돌아본 병아리 · 버튼 셋', (tester) async {
    LoginScreen.debugPretendIos = true;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_providers_ios.png'),
    );
  });
}
