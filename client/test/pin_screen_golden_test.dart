@Tags(['golden'])
library;

import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/onboarding/presentation/pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 보호자 비밀암호 두 상태 (Figma 238:1909 · 238:2924 · 이슈 #231).
///
/// **진짜 `PinScreen`을 렌더한다.** 시안에서 바뀐 것은 문구 셋과
/// "CTA가 완료 전에는 아예 없다"는 규칙이라, 골든이 그 둘을 함께 잡는다.
void main() {
  useFigmaViewport();

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.onboardingPin,
      routes: [
        GoRoute(
          path: Routes.onboardingPin,
          builder: (context, state) => const PinScreen(),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride()],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('1단계 빈 상태 — 버튼이 없다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PinScreen),
      matchesGoldenFile('goldens/pin_step1_empty.png'),
    );
  });

  testWidgets('2단계 완료 — 시작하기가 나타난다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 4자리를 채우면 자동으로 재입력 단계로 넘어간다
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PinScreen),
      matchesGoldenFile('goldens/pin_step2_done.png'),
    );
  });
}
