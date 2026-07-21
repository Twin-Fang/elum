import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/features/onboarding/presentation/goals_screen.dart';
import 'package:elum/features/onboarding/presentation/widgets/goal_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

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

  /// 특정 목표 칩의 배경 컨테이너를 찾는다
  BoxDecoration decorationOf(WidgetTester tester, SupportGoal goal) {
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byWidgetPredicate((w) => w is GoalChip && w.goal == goal),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return container.decoration! as BoxDecoration;
  }

  group('온보딩_목표 화면', () {
    testWidgets('Figma 문구 그대로 목표 4개를 보여준다', (tester) async {
      await tester.pumpWidget(wrap(const GoalsScreen()));
      await tester.pumpAndSettle();

      // 문구는 서비스 정체성이다. 어미 하나까지 Figma를 따른다.
      expect(find.text('해야 할 일을 순서대로 이해해요'), findsOneWidget);
      expect(find.text('필요한 준비물을 스스로 챙겨요'), findsOneWidget);
      expect(find.text('새로운 상황을 미리 준비해요'), findsOneWidget);
      expect(find.text('혼자 끝까지 해내는 경험을 만들어요'), findsOneWidget);

      expect(find.text('여러 개를 선택할 수 있어요'), findsOneWidget);
    });

    testWidgets('아이콘을 SVG 에셋으로 렌더링한다', (tester) async {
      await tester.pumpWidget(wrap(const GoalsScreen()));
      await tester.pumpAndSettle();

      // 도형을 Container로 그리다 일러스트가 사각형이 된 사고가 있었다.
      // Figma상 4개 목표의 아이콘은 모두 동일하므로 같은 에셋이 4번 나온다.
      expect(svgWithAsset(AppAssets.goalIcon), findsNWidgets(4));
    });

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

    testWidgets('선택한 칩은 Figma 민트색을 쓴다 (캐릭터색 아님)', (tester) async {
      await tester.pumpWidget(wrap(const GoalsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('해야 할 일을 순서대로 이해해요'));
      await tester.pumpAndSettle();
      // AnimatedContainer 전환이 끝난 뒤 색을 읽는다
      await tester.pump(const Duration(milliseconds: 300));

      final selected = decorationOf(tester, SupportGoal.stepByStep);
      expect(selected.color, AppColors.light.goalSelectedFill);

      // 여우 선택색이 새어 들어오면 안 된다 — 이슈 #11의 원인
      expect(selected.color, isNot(AppColors.light.foxSelectedFill));

      final border = selected.border! as Border;
      expect(border.top.color, AppColors.light.goalSelectedBorder);
      expect(border.top.width, 2);
    });

    testWidgets('선택하지 않은 칩은 흰 배경에 1px 테두리다', (tester) async {
      await tester.pumpWidget(wrap(const GoalsScreen()));
      await tester.pumpAndSettle();

      final unselected = decorationOf(tester, SupportGoal.independent);
      expect(unselected.color, AppColors.light.surface);

      final border = unselected.border! as Border;
      expect(border.top.color, AppColors.light.border);
      expect(border.top.width, 1);
    });

    testWidgets('여러 개를 동시에 선택할 수 있다', (tester) async {
      await tester.pumpWidget(wrap(const GoalsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('필요한 준비물을 스스로 챙겨요'));
      await tester.pumpAndSettle();

      // 세 번째 칩은 기본 화면 높이에서 접혀 있어 스크롤해야 닿는다.
      // ensureVisible 없이 tap하면 "No element"로 실패한다.
      final third = find.text('새로운 상황을 미리 준비해요');
      await tester.ensureVisible(third);
      await tester.pumpAndSettle();
      await tester.tap(third);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      // 데모 시나리오 기본값 조합이다
      expect(
        decorationOf(tester, SupportGoal.prepareItems).color,
        AppColors.light.goalSelectedFill,
      );
      expect(
        decorationOf(tester, SupportGoal.prepareNew).color,
        AppColors.light.goalSelectedFill,
      );
    });

    testWidgets('다시 누르면 선택이 해제된다', (tester) async {
      await tester.pumpWidget(wrap(const GoalsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('필요한 준비물을 스스로 챙겨요'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('필요한 준비물을 스스로 챙겨요'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        decorationOf(tester, SupportGoal.prepareItems).color,
        AppColors.light.surface,
      );

      // 전부 해제되면 CTA도 다시 잠긴다
      expect(isCtaEnabled(tester), isFalse);
    });
  });

  group('목표 칩 레이아웃 (Figma 실측)', () {
    testWidgets('칩 높이는 68이다', (tester) async {
      await tester.pumpWidget(wrap(const GoalsScreen()));
      await tester.pumpAndSettle();

      final chip = tester.getSize(
        find.byWidgetPredicate(
          (w) => w is GoalChip && w.goal == SupportGoal.stepByStep,
        ),
      );
      // 344×68 r20 — 간격 18은 화면이 준다
      expect(chip.height, 68);
    });
  });
}
