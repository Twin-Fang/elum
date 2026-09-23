import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/presentation/question_screen.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_flow_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/aurora_probe.dart';
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
  final inputTone = AuroraPalette.of(light, AuroraTone.input);
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

  /// 지금 화면에 깔린 오로라의 세 색 — Eclipse 시작 · Eclipse 끝 · Planet 시작.
  /// 흐름에 배경이 하나뿐이어야 하므로 원도 한 벌만 있어야 한다.
  List<Color> auroraColors(WidgetTester tester) => readAuroraColors(tester);

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

  group('흐름 순서대로 — 화면마다 색이 툭 바뀌지 않는다 (#380 결정 4)', () {
    /// 흐름 순서 (Figma 섹션 1049:4654). 로딩·추가질문도 이제 자기 색이 있다.
    const order = [
      AuroraTone.input,
      AuroraTone.reward,
      AuroraTone.preparing,
      AuroraTone.question,
      AuroraTone.generating,
      AuroraTone.none,
    ];

    /// 배경 한 장만 띄우고 색만 바꾼다 — 화면·라우터 없이 전환 자체를 잰다.
    Future<void Function(AuroraTone)> pumpBackground(
      WidgetTester tester,
      AuroraTone start, {
      bool reduceMotion = false,
    }) async {
      late StateSetter setTone;
      var tone = start;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: StatefulBuilder(
                builder: (context, setState) {
                  setTone = setState;
                  return AuroraBackground(tone: tone);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(AppMotion.ambient);
      return (next) => setTone(() => tone = next);
    }

    for (var i = 0; i + 1 < order.length; i++) {
      final from = order[i];
      final to = order[i + 1];

      testWidgets('${from.name} → ${to.name} 가운데는 두 색 사이, 끝은 정확히 다음 색', (
        tester,
      ) async {
        final a = AuroraPalette.of(light, from);
        final b = AuroraPalette.of(light, to);
        final go = await pumpBackground(tester, from);
        expect(readAuroraColors(tester), a.visibleColors);

        go(to);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        // 첫 프레임 — 아직 앞 색에 가깝다. easeInOut 이라 시작이 느리다.
        final first = readAuroraColors(tester);
        for (var c = 0; c < 3; c++) {
          expect(distance(first[c], a.visibleColors[c]), lessThan(0.02));
        }

        await tester.pump(AppMotion.ambient ~/ 2 - const Duration(milliseconds: 16));
        final mid = readAuroraColors(tester);
        for (var c = 0; c < 3; c++) {
          if (a.visibleColors[c] == b.visibleColors[c]) continue;
          if (to == AuroraTone.none) {
            // 가라앉을 때는 세기만 — 반쯤 투명해졌을 뿐 색은 그대로다.
            expect(mid[c].a, inExclusiveRange(0, a.visibleColors[c].a));
          } else {
            expect(
              strictlyBetween(mid[c], a.visibleColors[c], b.visibleColors[c]),
              isTrue,
              reason: '원 $c 이 가운데에서 ${mid[c]} — 두 색 사이가 아니다',
            );
          }
        }

        await tester.pump(AppMotion.ambient);
        expect(readAuroraColors(tester), b.visibleColors);
      });
    }

    testWidgets('보상 → 준비 로딩은 두 원이 40 내려간다 — 그것도 번지는 동안 조금씩', (
      tester,
    ) async {
      final go = await pumpBackground(tester, AuroraTone.reward);
      expect(readAuroraShift(tester), 0);

      go(AuroraTone.preparing);
      await tester.pump();
      await tester.pump(AppMotion.ambient ~/ 2);
      // 한가운데 — 204 와 244 사이 어딘가. 한 프레임에 40 을 뛰지 않는다.
      expect(readAuroraShift(tester), inExclusiveRange(5, 35));

      await tester.pump(AppMotion.ambient);
      expect(readAuroraShift(tester), closeTo(40, 1e-6));

      // 흐름을 거슬러 돌아가면 다시 올라간다.
      go(AuroraTone.reward);
      await tester.pump();
      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 16));
      expect(readAuroraShift(tester), closeTo(0, 1e-6));
    });

    testWidgets('동작 줄이기면 색도 자리도 즉시 다음 화면 것이다', (tester) async {
      final go = await pumpBackground(
        tester,
        AuroraTone.reward,
        reduceMotion: true,
      );
      go(AuroraTone.question);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        readAuroraColors(tester),
        AuroraPalette.of(light, AuroraTone.question).visibleColors,
      );
      expect(readAuroraShift(tester), closeTo(40, 1e-6));
    });
  });

  group('색이 번진다', () {
    testWidgets('보상으로 가면 전환 중간에는 두 색 사이 값이다', (tester) async {
      final router = await pumpFlow(tester);
      expect(auroraColors(tester), inputTone.visibleColors);

      router.push(Routes.routineReward);
      await tester.pump();
      // 첫 프레임 — 아직 앞 화면 색이다. 한 프레임에 툭 바뀌지 않는다.
      await tester.pump(const Duration(milliseconds: 16));
      final first = auroraColors(tester);
      for (var i = 0; i < 3; i++) {
        expect(
          distance(first[i], inputTone.visibleColors[i]),
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
            inputTone.visibleColors[i],
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
            inputTone.visibleColors[i],
          ),
          isTrue,
        );
      }

      await tester.pump(AppMotion.ambient);
      expect(auroraColors(tester), inputTone.visibleColors);
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
      expect(auroraColors(tester), inputTone.visibleColors);
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
        expect(mid[i].a, lessThan(inputTone.visibleColors[i].a));
        expect(mid[i].a, greaterThan(0));
        expect(
          distance(
            mid[i].withValues(alpha: 1),
            inputTone.visibleColors[i].withValues(alpha: 1),
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
    testWidgets('시스템 뒤로가기는 흐름째 닫지 않고 안에서 한 칸 돌아간다 (E3)', (tester) async {
      final router = await pumpFlow(tester);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 안드로이드 뒤로 단추. 흐름이 ShellRoute 로 한 겹 들어가도 안쪽 화면이
      // 먼저 받아야 한다 — 흐름째 닫히면 만들던 일과가 말없이 사라진다.
      // 보상의 뒤로는 입력으로 한 칸이라 묻지 않는다 — 적은 것이 남는다 (#387 D3).
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
      expect(find.text('일과 만들기를 그만둘까요?'), findsNothing);

      expect(find.byType(RoutineInputScreen), findsOneWidget);
      expect(find.byType(RewardSetupScreen), findsNothing);
      expect(auroraColors(tester), inputTone.visibleColors);
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
      expect(find.text('일과 만들기를 그만둘까요?'), findsNothing);
      for (final c in auroraColors(tester)) {
        expect(c.a, 0);
      }
    });
  });

  test('라우트마다 배경색 — 화면이 선언한 색과 같다', () {
    expect(routineFlowToneOf(Routes.routineInput), RoutineInputScreen.aurora);
    expect(routineFlowToneOf(Routes.routineReward), RewardSetupScreen.aurora);
    expect(
      routineFlowToneOf(Routes.routineMasking),
      RoutineLoadingScreen.auroraOf(RoutineLoadingKind.prepare),
    );
    expect(routineFlowToneOf(Routes.routineQuestion), QuestionScreen.aurora);
    expect(
      routineFlowToneOf(Routes.routineGenerating),
      RoutineLoadingScreen.auroraOf(RoutineLoadingKind.generate),
    );
    expect(routineFlowToneOf(Routes.routineReview), AuroraTone.none);

    // 화면마다 시안이 다른 색을 칠했다 (#380 결정 4) — 둘이 같으면 어딘가 빠졌다.
    expect(RoutineInputScreen.aurora, AuroraTone.input);
    expect(RoutineLoadingScreen.auroraOf(RoutineLoadingKind.prepare),
        AuroraTone.preparing);
    expect(QuestionScreen.aurora, AuroraTone.question);
    expect(RoutineLoadingScreen.auroraOf(RoutineLoadingKind.generate),
        AuroraTone.generating);
  });

  test('색·자리는 시안 값 그대로다 (2026-09-23 덤프)', () {
    // Eclipse 시작 · Eclipse 끝 · Planet 시작 — 시안 `Gradient` 그룹의 두 원.
    const figma = {
      AuroraTone.input: [0xFF7BFFE5, 0xFFD16FFF, 0xFFFCE551], // 238:1728
      AuroraTone.reward: [0xFFA97BFF, 0xFFFF6FB9, 0xFFFB8BD4], // 1082:4710
      AuroraTone.preparing: [0xFFCED8FF, 0xFFCED8FF, 0xFFCB51FC], // 262:4570
      AuroraTone.question: [0xFFA7AAFF, 0xFF6FC5FF, 0xFF5651FC], // 262:4767
      AuroraTone.generating: [0xFF7BFFB0, 0xFFFF6F93, 0xFFFCF351], // 262:4704
    };
    for (final MapEntry(key: tone, value: hex) in figma.entries) {
      expect(
        AuroraPalette.of(light, tone).colors,
        [for (final h in hex) Color(h)],
        reason: '$tone',
      );
    }

    // 작은 원 아래 끝의 투명색 — 그라데이션이 이 색을 지나므로 투명이어도 보인다.
    // 보상만 진분홍(#FF3CA1)이다. 하늘로 두면 분홍 원 가운데가 연보라로 샌다.
    for (final tone in figma.keys) {
      expect(
        AuroraPalette.of(light, tone).planetEnd,
        tone == AuroraTone.reward
            ? const Color(0x00FF3CA1)
            : const Color(0x003CFFFF),
        reason: '$tone',
      );
    }

    // 그룹 윗변 — 입력·보상은 204, 로딩·추가질문은 40 아래 244 다.
    // 입력 화면이 40 올라가면서(#380 결정 5) 두 원도 함께 올라갔다.
    expect(AuroraPalette.of(light, AuroraTone.input).top, 204);
    expect(AuroraPalette.of(light, AuroraTone.reward).top, 204);
    expect(AuroraPalette.of(light, AuroraTone.preparing).top, 244);
    expect(AuroraPalette.of(light, AuroraTone.question).top, 244);
    expect(AuroraPalette.of(light, AuroraTone.generating).top, 244);
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
    expect(AuroraPalette.lerp(inputTone, reward, 0), inputTone);
    expect(AuroraPalette.lerp(inputTone, reward, 1), reward);
  });
}

class _Repo with FakeRewardApi implements RoutineRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
