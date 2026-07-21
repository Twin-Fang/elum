import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/onboarding/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 시작 화면은 Figma `시작`(238:1808)을 따른다.
///
/// 이 테스트가 존재하는 이유: 화면 요소를 직접 그리려다 형태가 틀리는 사고를
/// 막기 위함이다. 병아리 몸통은 둥근 SVG인데 사각형으로 그려진 적이 있다.
///
/// ## 반복 idle 모션과 pumpAndSettle ⚠️
///
/// 시작 화면은 병아리 숨쉬기·별 반짝임 idle 모션을 무한 반복한다.
/// 그대로 `pumpAndSettle()`을 부르면 애니메이션이 끝나지 않아 타임아웃이 난다.
/// 화면은 OS "동작 줄이기"를 존중해 idle을 정지하므로, 구성·이동 테스트는
/// 그 설정을 켠 상태로 돌린다. idle 자체는 별도 그룹에서 고정 pump로 검증한다.
void main() {
  Widget buildSubject({bool onboardingCompleted = false}) {
    final router = GoRouter(
      initialLocation: Routes.splash,
      routes: [
        GoRoute(
          path: Routes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: Routes.onboardingName,
          builder: (context, state) => const Scaffold(body: Text('이름 화면')),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: onboardingCompleted),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// OS "동작 줄이기"를 켠다 — idle 반복 모션이 정지해 pumpAndSettle이 끝난다.
  void useReduceMotion() {
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
  }

  group('시작 화면 구성', () {
    useReduceMotion();

    testWidgets('Figma 문구 2줄과 CTA가 보인다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('오늘의 하루,'), findsOneWidget);
      expect(find.text('차근차근 함께해요'), findsOneWidget);
      expect(find.text('시작하기'), findsOneWidget);
    });

    testWidgets('로고는 텍스트가 아니라 SVG 에셋이다', (tester) async {
      // Cloudsofa_namgim 폰트를 못 구해 텍스트로 대체했던 적이 있다.
      // 실제로는 로고 SVG가 따로 있다.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('이룸'), findsNothing);
      expect(svgWithAsset(AppAssets.logo), findsOneWidget);
    });

    testWidgets('병아리 몸통을 직접 그리지 않고 SVG로 렌더링한다', (tester) async {
      // 둥근 형태와 방사형 그라데이션이 SVG 안에 있다.
      // Container + RadialGradient로 흉내내면 사각형이 된다.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.splashChickBody), findsOneWidget);
    });

    testWidgets('장식 요소가 모두 배치된다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.splashHill), findsOneWidget);
      expect(svgWithAsset(AppAssets.splashStar), findsOneWidget);
    });

    testWidgets('장면 요소는 첫 프레임부터 완성돼 있다', (tester) async {
      // 병아리·언덕·별이 뒤늦게 fade-in하면 "덜 로드된 느낌"이 난다.
      // 등장 연출은 문구·로고·CTA에만 건다. (설계 문서 2026-07-22)
      await tester.pumpWidget(buildSubject());
      // pumpAndSettle 없이 첫 프레임만 그린다

      expect(svgWithAsset(AppAssets.splashChickBody), findsOneWidget);
      expect(svgWithAsset(AppAssets.splashHill), findsOneWidget);
      expect(svgWithAsset(AppAssets.splashStar), findsOneWidget);
    });
  });

  group('시작 화면 이동', () {
    useReduceMotion();

    testWidgets('온보딩 전이면 이름 화면으로 간다', (tester) async {
      await tester.pumpWidget(buildSubject(onboardingCompleted: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      expect(find.text('이름 화면'), findsOneWidget);
    });

    testWidgets('온보딩을 마쳤으면 보호자 홈으로 간다', (tester) async {
      await tester.pumpWidget(buildSubject(onboardingCompleted: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsOneWidget);
    });
  });

  group('idle 모션', () {
    testWidgets('병아리 숨쉬기·별 반짝임이 반복된다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(seconds: 1));

      final breath = tester.widget<ScaleTransition>(
        find.byKey(const ValueKey('splash-chick-breath')),
      );
      final twinkle = tester.widget<FadeTransition>(
        find.byKey(const ValueKey('splash-star-twinkle')),
      );

      // 시간이 흐르면 값이 움직여야 idle이 살아 있는 것이다
      final scaleBefore = breath.scale.value;
      final opacityBefore = twinkle.opacity.value;
      await tester.pump(const Duration(milliseconds: 700));

      expect(breath.scale.value, isNot(scaleBefore));
      expect(twinkle.opacity.value, isNot(opacityBefore));
    });

    testWidgets('동작 줄이기 설정에서는 idle이 정지한다', (tester) async {
      // 움직임에 민감한 사용자 보호 (motion.md §접근성)
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(buildSubject());

      // idle이 정지 상태여야 등장 연출만 끝나고 안정된다.
      // 반복 중이면 여기서 타임아웃으로 실패한다.
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.splashChickBody), findsOneWidget);
    });
  });
}
