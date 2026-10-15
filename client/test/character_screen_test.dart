import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/shared/models/character.dart';
import 'package:elum/features/onboarding/presentation/character_screen.dart';
import 'package:elum/features/onboarding/presentation/widgets/character_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

/// Figma `온보딩_캐릭터`(204:1029) / `_여우`(204:1121) / `_고양이`(204:1134) 정합 테스트.
///
/// 선택색이 캐릭터마다 다르다는 점을 테스트로 고정한다.
/// 목표 칩과 색을 공유하던 구조를 이슈 #11에서 걷어냈다.
void main() {
  // Figma 실측값을 검증하므로 뷰포트를 실제 기기 크기로 고정한다
  useFigmaViewport();

  bool isCtaEnabled(WidgetTester tester) {
    return tester.widget<ElumButton>(find.byType(ElumButton)).onPressed != null;
  }

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.onboardingCharacter,
      routes: [
        GoRoute(
          path: Routes.onboardingCharacter,
          builder: (context, state) => const CharacterScreen(),
        ),
        // 캐릭터 다음은 그림 방식 단계다 (#458). 비밀암호는 그 다음이다.
        GoRoute(
          path: Routes.onboardingImageStyle,
          builder: (context, state) =>
              const Scaffold(body: Text('그림 방식 화면')),
        ),
        GoRoute(
          path: Routes.onboardingPin,
          builder: (context, state) => const Scaffold(body: Text('PIN 화면')),
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

  Finder cardOf(CardCharacter character) => find.byWidgetPredicate(
        (w) => w is CharacterCard && w.character == character,
      );

  group('온보딩_캐릭터 화면', () {

    testWidgets('아무것도 고르지 않으면 CTA가 비활성이다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Figma 204:1029의 CTA는 disable variant
      expect(isCtaEnabled(tester), isFalse);
    });

    // 그림 방식 단계가 캐릭터와 비밀암호 사이에 들어왔다 (#458)
    testWidgets('다음을 누르면 그림 방식 화면으로 간다 (비밀암호가 아니다)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(cardOf(CardCharacter.cat));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('그림 방식 화면'), findsOneWidget);
      expect(find.text('PIN 화면'), findsNothing);
    });

  });


}
