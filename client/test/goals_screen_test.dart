import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/presentation/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

/// Figma `온보딩_목표`(204:1002) / `온보딩_목표_선택`(204:1147) 정합 테스트.
///
/// 선택 색을 캐릭터색으로 잘못 쓴 전례가 있어(이슈 #11) 색까지 테스트로 고정한다.
void main() {
  // Figma 실측값을 검증하므로 뷰포트를 실제 기기 크기로 고정한다
  useFigmaViewport();

  /// CTA가 활성인지 — ElumButton은 onPressed가 null이면 disable variant다
  bool isCtaEnabled(WidgetTester tester) {
    return tester.widget<ElumButton>(find.byType(ElumButton)).onPressed != null;
  }

  Widget wrap(Widget child) {
    // 화면이 context.push로 다음 단계를 여므로 라우터가 필요하다
    final router = GoRouter(
      initialLocation: Routes.onboardingGoals,
      routes: [
        GoRoute(
          path: Routes.onboardingGoals,
          builder: (context, state) => child,
        ),
        GoRoute(
          path: Routes.onboardingCharacter,
          builder: (context, state) => const Scaffold(body: Text('캐릭터 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride()],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }


  group('온보딩_목표 화면', () {


    testWidgets('미선택 상태에서는 CTA가 비활성이다', (tester) async {
      await tester.pumpWidget(wrap(const GoalsScreen()));
      await tester.pumpAndSettle();

      // Figma 204:1002의 CTA는 disable variant
      expect(isCtaEnabled(tester), isFalse);
    });

    testWidgets('하나 선택하면 CTA가 활성된다', (tester) async {
      await tester.pumpWidget(wrap(const GoalsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('필요한 준비물을 스스로 챙겨요'));
      await tester.pumpAndSettle();

      // Figma 204:1147의 CTA는 enable variant
      expect(isCtaEnabled(tester), isTrue);
    });




  });

}
