import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_flow_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 일과 만들기 흐름의 배경이 화면을 넘어갈 때 **부드럽게 번지는가** (이슈 #380).
///
/// 보상 설정(`1082:4709`)은 입력(`238:1643`)과 같은 두 원을 **분홍으로** 칠했다.
/// 화면마다 배경을 따로 그리면 새 화면이 밀려 들어오며 색 경계선이 화면을
/// 가로지른다. 흐름 전체가 배경 **하나**를 쓰고 그 색만 옮겨 가는지 본다.
///
/// 정지 골든으로는 안 보이는 것이라 **전환 중간 프레임의 색**을 숫자로 잰다.
void main() {
  useFigmaViewport();

  final light = AppColors.light;
  final prepare = AuroraPalette.of(light, AuroraTone.prepare);
  final reward = AuroraPalette.of(light, AuroraTone.reward);

  /// 앱과 **같은 라우터**로 띄운다. 흐름을 감싸는 자리가 빠지면 여기서 잡힌다.
  Future<GoRouter> pumpFlow(
    WidgetTester tester, {
    bool reduceMotion = false,
    String start = Routes.routineInput,
  }) async {
    final router = createRouter()..go(start);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(_Repo()),
          routineSuggestionsProvider.overrideWith(
            (ref) async => RoutineSuggestion.fallback,
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return router;
  }

  /// 지금 화면에 깔린 오로라 원들의 색. 흐름에 배경이 하나뿐이어야 한다.
  List<Color> auroraColors(WidgetTester tester) {
    final circles = find.byKey(AuroraBackground.circleKey, skipOffstage: false);
    return [
      for (final e in circles.evaluate())
        ((e.widget as Container).decoration! as BoxDecoration).color!,
    ];
  }

  /// 두 색 사이 값인가 — 채널마다 [a]와 [b] 사이에 있고 둘 다와 다르다.
  bool strictlyBetween(Color c, Color a, Color b) {
    bool within(double x, double p, double q) {
      final lo = p < q ? p : q;
      final hi = p < q ? q : p;
      return x >= lo - 1e-6 && x <= hi + 1e-6;
    }

    return within(c.r, a.r, b.r) &&
        within(c.g, a.g, b.g) &&
        within(c.b, a.b, b.b) &&
        c != a &&
        c != b;
  }

  double distance(Color a, Color b) =>
      (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();

  group('배경은 흐름 전체에 하나다', () {
    testWidgets('입력 → 보상으로 넘어가는 동안에도 오로라는 한 벌뿐이다', (tester) async {
      final router = await pumpFlow(tester);
      expect(find.byType(RoutineFlowBackdrop), findsOneWidget);
      expect(find.byType(AuroraBackground, skipOffstage: false), findsOneWidget);

      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // 두 화면이 겹쳐 있는 순간이다. 화면마다 배경을 그리면 여기서 둘이 된다.
      expect(find.byType(RewardSetupScreen), findsOneWidget);
      expect(find.byType(RoutineInputScreen), findsOneWidget);
      expect(find.byType(AuroraBackground, skipOffstage: false), findsOneWidget);
    });

    testWidgets('흐름 안의 화면은 바탕을 칠하지 않는다 — 배경이 비쳐야 한다', (tester) async {
      final router = await pumpFlow(tester);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      final scaffolds = tester.widgetList<Scaffold>(
        find.descendant(
          of: find.byType(RoutineFlowBackdrop),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffolds, isNotEmpty);
      for (final s in scaffolds) {
        expect(s.backgroundColor, Colors.transparent);
      }
    });
  });

  group('색이 번진다', () {
    testWidgets('보상으로 가면 전환 중간에는 두 색 사이 값이다', (tester) async {
      final router = await pumpFlow(tester);
      expect(auroraColors(tester), prepare.visibleColors);

      router.push(Routes.routineReward);
      await tester.pump();
      // 첫 프레임 — 아직 앞 화면 색이다. 한 프레임에 툭 바뀌지 않는다.
      await tester.pump(const Duration(milliseconds: 16));
      final first = auroraColors(tester);
      for (var i = 0; i < 3; i++) {
        expect(
          distance(first[i], prepare.visibleColors[i]),
          lessThan(0.02),
          reason: '원 $i 이 첫 프레임에 이미 크게 바뀌었다',
        );
      }

      // 한가운데 — 세 원 모두 두 색 사이다.
      await tester.pump(AppMotion.ambient ~/ 2 - const Duration(milliseconds: 16));
      final mid = auroraColors(tester);
      for (var i = 0; i < 3; i++) {
        expect(
          strictlyBetween(
            mid[i],
            prepare.visibleColors[i],
            reward.visibleColors[i],
          ),
          isTrue,
          reason: '원 $i 이 가운데에서 ${mid[i]} — 두 색 사이가 아니다',
        );
      }

      // 끝 — 정확히 분홍에 선다 (끝에서 남는 값이 없다).
      await tester.pump(AppMotion.ambient);
      expect(auroraColors(tester), reward.visibleColors);
    });

    testWidgets('보상에서 돌아가면 거꾸로 번진다', (tester) async {
      final router = await pumpFlow(tester);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
      expect(auroraColors(tester), reward.visibleColors);

      router.pop();
      await tester.pump();
      await tester.pump(AppMotion.ambient ~/ 2);
      final mid = auroraColors(tester);
      for (var i = 0; i < 3; i++) {
        expect(
          strictlyBetween(
            mid[i],
            reward.visibleColors[i],
            prepare.visibleColors[i],
          ),
          isTrue,
        );
      }

      await tester.pump(AppMotion.ambient);
      expect(auroraColors(tester), prepare.visibleColors);
    });

    testWidgets('번지는 도중에 되돌아가도 색이 튀지 않는다 (E9)', (tester) async {
      final router = await pumpFlow(tester);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final beforePop = auroraColors(tester);

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final afterPop = auroraColors(tester);

      // 지금 값에서 출발한다 — 분홍 끝이나 민트 끝으로 건너뛰지 않는다.
      for (var i = 0; i < 3; i++) {
        expect(distance(beforePop[i], afterPop[i]), lessThan(0.05));
      }

      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
      expect(auroraColors(tester), prepare.visibleColors);
    });

    testWidgets('동작 줄이기를 켜면 배경이 즉시 바뀐다 (E7)', (tester) async {
      final router = await pumpFlow(tester, reduceMotion: true);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(auroraColors(tester), reward.visibleColors);
    });

    testWidgets('카드 검토는 오로라가 없다 — 색이 아니라 세기가 가라앉는다', (tester) async {
      final router = await pumpFlow(tester);
      router.push(Routes.routineReview);
      await tester.pump();
      await tester.pump(AppMotion.ambient ~/ 2);

      // 가라앉는 동안 색은 민트 그대로, 투명도만 줄어든다 — 검게 탁해지지 않는다.
      final mid = auroraColors(tester);
      for (var i = 0; i < 3; i++) {
        expect(mid[i].a, lessThan(prepare.visibleColors[i].a));
        expect(mid[i].a, greaterThan(0));
        expect(
          distance(
            mid[i].withValues(alpha: 1),
            prepare.visibleColors[i].withValues(alpha: 1),
          ),
          lessThan(0.01),
        );
      }

      await tester.pump(AppMotion.ambient);
      for (final c in auroraColors(tester)) {
        expect(c.a, 0);
      }
    });
  });

  group('전환', () {
    testWidgets('흐름 안에서는 나가는 화면이 먼저 흐려진다 — 글자가 겹쳐 보이지 않는다', (tester) async {
      final router = await pumpFlow(tester);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 400ms 전환의 절반. 나가는 입력 화면은 이미 다 사라졌어야 한다.
      final inputOpacity = tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.byType(RoutineInputScreen),
              matching: find.byType(FadeTransition),
            ),
          )
          .map((f) => f.opacity.value)
          .reduce((a, b) => a * b);
      expect(inputOpacity, lessThan(0.05));

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RewardSetupScreen), findsOneWidget);
    });

    testWidgets('돌아갈 때 아래 화면이 끝에서 급히 튀어나오지 않는다', (tester) async {
      final router = await pumpFlow(tester);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      router.pop();
      await tester.pump();
      // 되돌아가는 400ms 의 절반. 위 화면은 이미 비켰고 아래 화면이 반 넘게 떠올랐어야 한다.
      await tester.pump(const Duration(milliseconds: 200));

      double opacityOf(Type screen) => tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.byType(screen),
              matching: find.byType(FadeTransition),
            ),
          )
          .map((f) => f.opacity.value)
          .reduce((a, b) => a * b);

      expect(opacityOf(RewardSetupScreen), lessThan(0.05));
      expect(opacityOf(RoutineInputScreen), greaterThan(0.5));
    });

    testWidgets('동작 줄이기면 화면이 미끄러지지 않는다 (E7)', (tester) async {
      final router = await pumpFlow(tester, reduceMotion: true);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final slides = tester.widgetList<SlideTransition>(
        find.ancestor(
          of: find.byType(RewardSetupScreen),
          matching: find.byType(SlideTransition),
        ),
      );
      for (final s in slides) {
        expect(s.position.value, Offset.zero);
      }
    });
  });

  group('흐름 안에서 빠져나가기', () {
    testWidgets('시스템 뒤로가기도 흐름 안에서 확인을 묻는다 (E3)', (tester) async {
      final router = await pumpFlow(tester);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 안드로이드 뒤로 단추. 흐름이 ShellRoute 로 한 겹 들어가도 안쪽 화면의
      // 확인이 먼저 받아야 한다 — 흐름째 닫히면 만들던 일과가 말없이 사라진다.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('만들던 일과가 사라져요'), findsOneWidget);

      await tester.tap(find.text('나가기'));
      await tester.pump();
      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));

      expect(find.byType(RoutineInputScreen), findsOneWidget);
      expect(find.byType(RewardSetupScreen), findsNothing);
      expect(auroraColors(tester), prepare.visibleColors);
    });

    testWidgets('카드 검토에서 고치러 오면 분홍이 떠오르고 돌아가면 가라앉는다 (E5)', (tester) async {
      final router = await pumpFlow(tester, start: Routes.routineReview);
      for (final c in auroraColors(tester)) {
        expect(c.a, 0);
      }

      router.push(Routes.routineReward, extra: true);
      await tester.pump();
      await tester.pump(AppMotion.ambient ~/ 2);
      // 떠오르는 도중에도 색은 처음부터 분홍이다 — 민트를 거쳐 오지 않는다.
      final mid = auroraColors(tester);
      for (var i = 0; i < 3; i++) {
        expect(mid[i].a, greaterThan(0));
        expect(mid[i].a, lessThan(reward.visibleColors[i].a));
        expect(
          distance(
            mid[i].withValues(alpha: 1),
            reward.visibleColors[i].withValues(alpha: 1),
          ),
          lessThan(0.01),
        );
      }

      await tester.pump(AppMotion.ambient);
      expect(auroraColors(tester), reward.visibleColors);
      // 고치러 온 길이라 나가도 잃을 것이 없다 — 확인 없이 돌아간다.
      await tester.tap(find.bySemanticsLabel('뒤로 가기'));
      await tester.pump();
      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
      expect(find.text('만들던 일과가 사라져요'), findsNothing);
      for (final c in auroraColors(tester)) {
        expect(c.a, 0);
      }
    });
  });

  test('라우트마다 배경색 — 화면이 선언한 색과 같다', () {
    expect(routineFlowToneOf(Routes.routineInput), AuroraTone.prepare);
    expect(routineFlowToneOf(Routes.routineMasking), AuroraTone.prepare);
    expect(routineFlowToneOf(Routes.routineQuestion), AuroraTone.prepare);
    expect(routineFlowToneOf(Routes.routineReward), RewardSetupScreen.aurora);
    expect(routineFlowToneOf(Routes.routineGenerating), AuroraTone.prepare);
    expect(routineFlowToneOf(Routes.routineReview), AuroraTone.none);
  });

  test('오로라 색 보간 — 없음과 섞일 때는 색이 아니라 세기만 바뀐다', () {
    final none = AuroraPalette.of(light, AuroraTone.none);
    final half = AuroraPalette.lerp(reward, none, 0.5);
    for (var i = 0; i < 3; i++) {
      expect(half.visibleColors[i].withValues(alpha: 1),
          reward.visibleColors[i].withValues(alpha: 1));
      expect(half.visibleColors[i].a,
          closeTo(reward.visibleColors[i].a / 2, 0.01));
    }
    expect(AuroraPalette.lerp(prepare, reward, 0), prepare);
    expect(AuroraPalette.lerp(prepare, reward, 1), reward);
  });
}

class _Repo with FakeRewardApi implements RoutineRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
