import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/presentation/setup_done_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// Figma `온보딩_맞춤설정완료`(204:1042~1113) 정합 테스트.
///
/// 변형 5개가 순차 노출되는 안내 화면이다. 1~4단계는 자동으로 넘어가고,
/// 마지막 단계에서만 CTA `첫 일과 만들기`로 보호자 홈에 진입한다 (이슈 #83).
void main() {
  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.onboardingDone,
      routes: [
        GoRoute(
          path: Routes.onboardingDone,
          builder: (context, state) => const SetupDoneScreen(),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride(), testMemberRepoOverride()],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// 자동 전환 [steps]회 만큼 시간을 흘리고 페이드가 끝날 때까지 기다린다.
  Future<void> advance(WidgetTester tester, int steps) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(SetupDoneScreen.holdDuration);
      await tester.pumpAndSettle();
    }
  }

  group('온보딩_맞춤설정완료 화면', () {
    testWidgets('첫 문구를 Figma 줄바꿈 그대로 보여준다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('준비물은 눈에 보이는\n체크리스트로 보여드려요'), findsOneWidget);
    });

    testWidgets('아이콘을 SVG 에셋으로 그린다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      // 노란 원 + 아이 얼굴. 코드로 그리지 않는다.
      expect(svgWithAsset(AppAssets.setupDoneIcon), findsOneWidget);
    });

    testWidgets('마지막 단계 전에는 CTA가 없다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.byType(ElumButton), findsNothing);

      // 4단계(마지막 직전)까지 진행해도 CTA는 아직 없다
      await advance(tester, 3);
      expect(find.text(SetupDoneScreen.messages[3]), findsOneWidget);
      expect(find.byType(ElumButton), findsNothing);
    });

    testWidgets('뒤로가기가 없다 — 온보딩을 되돌릴 수 없다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(svgWithAsset(AppAssets.iconBack), findsNothing);
    });

    testWidgets('문구 5개가 순서대로 자동 전환된다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      for (var i = 0; i < SetupDoneScreen.messages.length; i++) {
        expect(find.text(SetupDoneScreen.messages[i]), findsOneWidget);
        await advance(tester, 1);
      }

      // 마지막 문구는 자동으로 넘어가지 않고 그대로 머문다
      expect(
        find.text(SetupDoneScreen.messages.last),
        findsOneWidget,
      );
      expect(find.text('보호자 홈'), findsNothing);
    });

    testWidgets('마지막 단계에서 CTA를 누르면 보호자 홈으로 간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await advance(tester, SetupDoneScreen.messages.length - 1);

      final cta = find.widgetWithText(ElumButton, '첫 일과 만들기');
      expect(cta, findsOneWidget);

      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsOneWidget);
    });

    testWidgets('저장이 실패해도 끝까지 진행된다', (tester) async {
      // 데모는 어떤 실패에도 끝까지 진행되어야 한다 (docs 원칙 6번).
      // 저장 실패는 notifier가 삼키므로 안내·CTA 흐름은 그대로 동작한다.
      await tester.pumpWidget(wrap());
      await tester.pump();

      await advance(tester, SetupDoneScreen.messages.length - 1);
      await tester.tap(find.widgetWithText(ElumButton, '첫 일과 만들기'));
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsOneWidget);
    });
  });
}
