import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// Figma `보호자_새로운 일과 만들기_로딩`(262:4569 / 262:4703) 정합 테스트.
void main() {
  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.routineMasking,
      routes: [
        GoRoute(
          path: Routes.routineMasking,
          builder: (context, state) => const RoutineLoadingScreen(),
        ),
        GoRoute(
          path: Routes.routineReview,
          builder: (context, state) => const Scaffold(body: Text('카드 확인')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride(onboardingCompleted: true)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// 배경이 무한 반복하므로 pumpAndSettle을 쓸 수 없다
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  group('로딩 화면 구성', () {
    testWidgets('Figma 문구가 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.text('루미가 내용을\n정리하고 있어요'), findsOneWidget);
    });

    testWidgets('3단계 체크리스트를 Figma 문구대로 보여준다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      for (final stage in RoutineStage.values) {
        expect(find.text(stage.label), findsOneWidget);
      }
      expect(RoutineStage.values.length, 3);
    });

    testWidgets('진행률을 보여준다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      // 첫 단계 진행률
      expect(find.textContaining('% 진행 되었어요'), findsOneWidget);
    });

    testWidgets('sparkles를 SVG 에셋으로 그린다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(svgWithAsset(AppAssets.iconSparklesLarge), findsOneWidget);
    });

    testWidgets('뒤로가기가 없다 — 생성 중에는 되돌릴 수 없다', (tester) async {
      // 중간에 끊으면 어중간한 상태가 남는다
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(svgWithAsset(AppAssets.iconBack), findsNothing);
    });

    testWidgets('첫 단계 진행률부터 시작한다', (tester) async {
      // 단계 전진은 타이머가 하지만, mock 환경에서는 카드 생성이 즉시 끝나
      // 다음 화면으로 넘어가 버린다. 여기서는 시작 상태만 고정한다.
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.text('${RoutineStage.masking.percent}% 진행 되었어요'),
          findsOneWidget);
    });

    testWidgets('생성이 끝나면 카드 확인 화면으로 넘어간다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);

      expect(find.text('카드 확인'), findsOneWidget);
    });
  });

  group('RoutineStage', () {
    test('진행률이 순서대로 늘어난다', () {
      expect(
        RoutineStage.summarizing.percent,
        greaterThan(RoutineStage.masking.percent),
      );
      expect(
        RoutineStage.rewriting.percent,
        greaterThan(RoutineStage.summarizing.percent),
      );
    });

    test('100%를 만들지 않는다', () {
      // 서버가 진행률을 주지 않아 클라이언트가 흉내낸다(이슈 #33).
      // 가짜 100%를 보여주면 다 됐는데 안 넘어간다는 인상을 준다.
      for (final stage in RoutineStage.values) {
        expect(stage.percent, lessThan(100));
      }
    });

    test('Figma가 보여주는 40%가 두 번째 단계다', () {
      expect(RoutineStage.summarizing.percent, 40);
    });

    test('앞 단계는 완료로 판정된다', () {
      expect(
        RoutineStage.masking.isCompletedAt(RoutineStage.summarizing),
        isTrue,
      );
      // 현재 단계는 아직 진행 중이다
      expect(
        RoutineStage.summarizing.isCompletedAt(RoutineStage.summarizing),
        isFalse,
      );
    });
  });
}
