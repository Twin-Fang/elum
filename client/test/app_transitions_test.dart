import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/router/app_transitions.dart';
import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_storage.dart';

/// 페이지 전환 — motion.md "전환 없는 즉시 교체 금지" 규칙 구현 검증.
///
/// go_router 전환은 목적지 라우트의 pageBuilder가 결정하므로,
/// 온보딩 라우트가 전부 CustomTransitionPage를 쓰는지 라우터 구성으로 고정한다.
void main() {
  group('전환 헬퍼', () {
    testWidgets('slidePage는 슬라이드+fade로 400ms 동안 전환한다', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Text('첫')),
          GoRoute(
            path: '/next',
            pageBuilder: (context, state) =>
                slidePage(state, const Text('다음')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.push('/next');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 전환 중간 — 들어오는 화면이 슬라이드 중이다
      final slide = find.ancestor(
        of: find.text('다음'),
        matching: find.byType(SlideTransition),
      );
      expect(slide, findsWidgets);

      // 전환이 끝나면 안정된다 (반복 애니메이션이 아니다)
      await tester.pumpAndSettle();
      expect(find.text('다음'), findsOneWidget);
    });

    testWidgets('fadePage는 fade로 전환한다', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Text('첫')),
          GoRoute(
            path: '/next',
            pageBuilder: (context, state) => fadePage(state, const Text('다음')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.push('/next');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.ancestor(
          of: find.text('다음'),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );

      await tester.pumpAndSettle();
      expect(find.text('다음'), findsOneWidget);
    });

    test('전환 시간은 AppMotion.slow 토큰을 쓴다', () {
      // 헬퍼가 화면마다 다른 숫자를 쓰기 시작하면 여기서 잡힌다
      expect(kPageTransitionDuration, AppMotion.slow);
    });
  });

  group('라우터 구성', () {
    test('온보딩 라우트는 전부 전환 페이지를 쓴다', () {
      final router = createRouter();
      final onboardingPaths = {
        Routes.onboardingName,
        Routes.onboardingGoals,
        Routes.onboardingCharacter,
        Routes.onboardingPin,
        // SetupDoneScreen은 제거됐다 (fc9e5a5) — PIN 완료 후 바로 홈으로 간다.
        Routes.guardian, // 완료 → 보호자 홈 fade
      };

      final routes = router.configuration.routes.whereType<GoRoute>();
      for (final route in routes) {
        if (onboardingPaths.contains(route.path)) {
          expect(
            route.pageBuilder,
            isNotNull,
            reason: '${route.path}가 기본 전환(즉시 교체)으로 남아 있다',
          );
        }
      }
    });
  });

  group('시작 → 로그인 전환', () {
    // ⚠️ 여기서는 동작 줄이기를 **켜지 않는다.** 켜면 AnimationController가
    // duration을 5%로 줄여(400ms → 20ms) 전환이 순식간에 끝나 버려서,
    // 정작 보려는 "두 화면이 겹친 순간"을 잡을 수 없다.
    // 대신 pumpAndSettle을 쓰지 않고 고정 pump로만 진행한다 — SplashScene의
    // 부유 모션이 무한 반복이라 settle이 끝나지 않는다.
    testWidgets('전환 중에 문구가 가로로 어긋나지 않는다 (이슈 #207)', (tester) async {
      final router = createRouter(
        hasToken: () => false,
        isOnboardingCompleted: () => false,
        isElumiDevice: () => false,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [testStorageOverride(onboardingCompleted: false)],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
            ),
          ),
        ),
      );

      // 시작 화면이 스스로 로그인으로 넘어간다(1700ms). 전환 한복판을 집는다.
      await tester.pump(const Duration(milliseconds: 1750));
      await tester.pump(const Duration(milliseconds: 150));

      // 나가는 화면과 들어오는 화면이 둘 다 트리에 있다 — 여기서 x가 어긋나면
      // 같은 글자가 두 번 찍혀 보인다. 수평 슬라이드를 쓰면 화면 폭의 25%만큼
      // 벌어진다. fade는 제자리에서 겹치므로 x가 같아야 한다.
      final rects = tester
          .widgetList<Text>(find.text('차근차근 함께해요'))
          .map((w) => tester.getRect(find.byWidget(w)).left)
          .toList();
      expect(rects.length, greaterThanOrEqualTo(2),
          reason: '전환 중이 아니다 — 두 화면이 겹친 순간을 잡지 못했다');
      for (final left in rects) {
        expect(left, closeTo(rects.first, 0.5));
      }

      // 전환이 끝나면 로그인 화면 하나만 남는다
      await tester.pump(kPageTransitionDuration);
      expect(find.text('카카오로 계속하기'), findsOneWidget);
      expect(find.text('차근차근 함께해요'), findsOneWidget);
    });
  });
}
