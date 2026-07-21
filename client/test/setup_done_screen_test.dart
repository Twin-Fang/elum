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

/// Figma `온보딩_맞춤설정완료`(204:1042) 정합 테스트.
///
/// CTA가 없는 **전환 화면**이다. 온보딩 결과를 저장하는 동안 잠깐 보였다가
/// 보호자 홈으로 넘어간다.
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

  group('온보딩_맞춤설정완료 화면', () {
    testWidgets('Figma 문구를 2줄로 보여준다', (tester) async {
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

    testWidgets('CTA가 없다 — 누를 것이 없는 전환 화면이다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.byType(ElumButton), findsNothing);
    });

    testWidgets('뒤로가기가 없다 — 온보딩을 되돌릴 수 없다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(svgWithAsset(AppAssets.iconBack), findsNothing);
    });

    testWidgets('잠시 뒤 보호자 홈으로 넘어간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      // 아직은 완료 화면
      expect(find.text('보호자 홈'), findsNothing);

      await tester.pump(SetupDoneScreen.holdDuration);
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsOneWidget);
    });

    testWidgets('저장이 실패해도 홈으로 넘어간다', (tester) async {
      // 데모는 어떤 실패에도 끝까지 진행되어야 한다 (docs 원칙 6번).
      // 저장 실패는 notifier가 삼키므로 화면은 그대로 진행된다.
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.pump(SetupDoneScreen.holdDuration);
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsOneWidget);
    });
  });
}
