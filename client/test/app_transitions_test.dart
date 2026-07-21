import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/router/app_transitions.dart';
import 'package:elum/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
        Routes.onboardingDone,
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
}
