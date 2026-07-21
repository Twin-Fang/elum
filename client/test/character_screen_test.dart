import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/features/onboarding/presentation/character_screen.dart';
import 'package:elum/features/onboarding/presentation/widgets/character_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

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

  BoxDecoration decorationOf(WidgetTester tester, CardCharacter character) {
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: cardOf(character),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return container.decoration! as BoxDecoration;
  }

  group('온보딩_캐릭터 화면', () {
    testWidgets('Figma 문구가 보이고 캐릭터 2종을 SVG로 그린다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('선택한 친구가 카드 속 주인공이 되어 도와줘요'), findsOneWidget);

      // 캐릭터는 형태가 있는 일러스트다. 코드로 그리지 않는다.
      expect(svgWithAsset(AppAssets.character(CardCharacter.cat)), findsOneWidget);
      expect(svgWithAsset(AppAssets.character(CardCharacter.fox)), findsOneWidget);
    });

    testWidgets('아무것도 고르지 않으면 CTA가 비활성이다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Figma 204:1029의 CTA는 disable variant
      expect(isCtaEnabled(tester), isFalse);
    });

    testWidgets('여우를 고르면 복숭아색이 된다 (204:1121)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(cardOf(CardCharacter.fox));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      final fox = decorationOf(tester, CardCharacter.fox);
      expect(fox.color, AppColors.light.foxSelectedFill);
      expect((fox.border! as Border).top.color, AppColors.light.foxSelectedBorder);
      expect((fox.border! as Border).top.width, 2);

      // 고른 쪽만 색이 바뀐다
      expect(
        decorationOf(tester, CardCharacter.cat).color,
        AppColors.light.surface,
      );

      expect(isCtaEnabled(tester), isTrue);
    });

    testWidgets('고양이를 고르면 파란색이 된다 (204:1134)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(cardOf(CardCharacter.cat));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      final cat = decorationOf(tester, CardCharacter.cat);
      expect(cat.color, AppColors.light.catSelectedFill);
      expect((cat.border! as Border).top.color, AppColors.light.catSelectedBorder);

      // 여우색·목표색이 새어 들어오면 안 된다 — 색을 한 쌍으로 묶었던 구조의 재발 방지
      expect(cat.color, isNot(AppColors.light.foxSelectedFill));
      expect(cat.color, isNot(AppColors.light.goalSelectedFill));
    });

    testWidgets('단일 선택이다 — 다른 쪽을 고르면 이전 선택이 풀린다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(cardOf(CardCharacter.fox));
      await tester.pumpAndSettle();
      await tester.tap(cardOf(CardCharacter.cat));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        decorationOf(tester, CardCharacter.cat).color,
        AppColors.light.catSelectedFill,
      );
      expect(
        decorationOf(tester, CardCharacter.fox).color,
        AppColors.light.surface,
      );
    });

    testWidgets('이미 고른 것을 다시 눌러도 해제되지 않는다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(cardOf(CardCharacter.fox));
      await tester.pumpAndSettle();
      await tester.tap(cardOf(CardCharacter.fox));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      // 반드시 하나는 골라야 하므로 CTA가 다시 잠기면 안 된다
      expect(
        decorationOf(tester, CardCharacter.fox).color,
        AppColors.light.foxSelectedFill,
      );
      expect(isCtaEnabled(tester), isTrue);
    });
  });

  group('캐릭터 카드 레이아웃 (Figma 실측)', () {
    testWidgets('카드 높이는 202다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // 176×202 r20
      expect(tester.getSize(cardOf(CardCharacter.cat)).height, 202);
    });

    testWidgets('고양이가 왼쪽, 여우가 오른쪽이다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Figma: Component 3(고양이) x=28, Group 19(여우) x=213
      final catX = tester.getTopLeft(cardOf(CardCharacter.cat)).dx;
      final foxX = tester.getTopLeft(cardOf(CardCharacter.fox)).dx;
      expect(catX, lessThan(foxX));
    });

    testWidgets('카드에 이름 텍스트를 넣지 않는다', (tester) async {
      // Figma가 이 자리(Ellipse 2/3)를 회색 알약으로 비워뒀다.
      // 원본에 없는 것을 임의로 채우지 않는다.
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text(CardCharacter.cat.displayName), findsNothing);
      expect(find.text(CardCharacter.fox.displayName), findsNothing);
    });

    testWidgets('두 캐릭터의 식별 이름이 서로 다르다', (tester) async {
      // 화면에 쓰이진 않지만 코드에서 캐릭터를 구분하는 값이다
      expect(
        CardCharacter.cat.displayName,
        isNot(CardCharacter.fox.displayName),
      );
    });

    testWidgets('확정된 식별 이름은 고양이 루루 · 여우 포포다', (tester) async {
      // 화면 문구가 아니라 코드에서 캐릭터를 가리키는 이름이다
      expect(CardCharacter.cat.displayName, '루루');
      expect(CardCharacter.fox.displayName, '포포');
    });
  });
}
