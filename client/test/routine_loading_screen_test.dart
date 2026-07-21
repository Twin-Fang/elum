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
  Widget wrap(RoutineLoadingKind kind) {
    final router = GoRouter(
      initialLocation: '/loading',
      routes: [
        GoRoute(
          path: '/loading',
          builder: (context, state) => RoutineLoadingScreen(kind: kind),
        ),
        GoRoute(
          path: Routes.routineQuestion,
          builder: (context, state) => const Scaffold(body: Text('추가 질문')),
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
    await tester.pump(const Duration(milliseconds: 450));
  }

  /// 모든 스텝의 노출시간을 합친 값 — 이만큼 지나야 화면이 넘어갈 수 있다
  Duration totalHold(RoutineLoadingKind kind) => kind.stages
      .map((s) => s.hold)
      .fold(Duration.zero, (a, b) => a + b);

  group('prepare 로딩 (262:4569)', () {
    testWidgets('Figma 문구가 보인다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      expect(find.text('루미가 내용을\n정리하고 있어요'), findsOneWidget);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);
    });

    testWidgets('단계 문구가 Figma 262:4569 렌더 결과와 같다', (tester) async {
      // ⚠️ JSON 덤프에는 화면에 그려지지 않는 레이어까지 섞여 나온다
      // (262:4678 `아이가 이해하기 쉬운 말로 바꿔요`). 덤프만 보고 고치면
      // 멀쩡한 문구를 틀린 값으로 바꾸게 된다 — 실제로 그런 적이 있다.
      // 기준은 **렌더된 PNG**다.
      expect(
        RoutineLoadingKind.prepare.stages.map((s) => s.label).toList(),
        const [
          '아이를 알아볼 수 있는 정보는 가려요',
          '꼭 필요한 내용만 정리해요',
          '추가 질문을 생각하고 있어요',
        ],
      );
    });

    testWidgets('스텝이 하나씩 드러난다 — 처음엔 첫 줄만 보인다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      final stages = RoutineLoadingKind.prepare.stages;

      // 자리는 미리 잡아두므로 위젯 자체는 전부 존재한다.
      // 실제로 "보이는가"는 투명도로 판단한다.
      expect(opacityOf(tester, stages[0].label), 1.0);
      expect(opacityOf(tester, stages[1].label), 0.0);
      expect(opacityOf(tester, stages[2].label), 0.0);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);
    });

    testWidgets('두 번째 스텝은 첫 스텝의 노출시간이 지난 뒤에 뜬다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      final stages = RoutineLoadingKind.prepare.stages;
      await tester.pump(stages[0].hold);
      await settle(tester);

      expect(opacityOf(tester, stages[1].label), 1.0);
      expect(opacityOf(tester, stages[2].label), 0.0);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);
    });

    testWidgets('질문 준비가 끝나면 추가 질문 화면으로 넘어간다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);

      expect(find.text('추가 질문'), findsOneWidget);
    });
  });

  group('generate 로딩 (262:4703)', () {
    testWidgets('Figma 문구가 보인다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.generate));
      await settle(tester);

      expect(find.text('루미가 행동카드를\n만들고 있어요'), findsOneWidget);

      await tester.pump(totalHold(RoutineLoadingKind.generate));
      await settle(tester);
    });

    testWidgets('생성이 끝나면 카드 확인 화면으로 넘어간다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.generate));
      await settle(tester);

      await tester.pump(totalHold(RoutineLoadingKind.generate));
      await settle(tester);

      expect(find.text('카드 확인'), findsOneWidget);
    });
  });

  group('최소 노출시간 보장', () {
    // 백엔드가 즉시 응답해도 연출을 끝까지 보여준다.
    // mock 환경에서는 카드 생성이 사실상 즉시 끝나므로,
    // 이 테스트가 곧 "응답이 빨리 온 경우"다.
    testWidgets('응답이 즉시 와도 노출시간을 다 채우기 전엔 넘어가지 않는다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.generate));
      await settle(tester);

      final stages = RoutineLoadingKind.generate.stages;

      // 첫 두 스텝만 지난 시점 — 아직 마지막 스텝이 남았다
      await tester.pump(stages[0].hold + stages[1].hold);
      await settle(tester);
      expect(
        find.text('카드 확인'),
        findsNothing,
        reason: '노출시간이 남았는데 화면이 넘어갔다',
      );

      // 마지막 스텝까지 채우면 그제서야 넘어간다
      await tester.pump(stages[2].hold);
      await settle(tester);
      expect(find.text('카드 확인'), findsOneWidget);
    });

    testWidgets('각 스텝의 노출시간은 4초 / 3초 / 4초다', (tester) async {
      for (final kind in RoutineLoadingKind.values) {
        expect(
          kind.stages.map((s) => s.hold.inSeconds).toList(),
          [4, 3, 4],
          reason: '$kind의 스텝 노출시간이 합의값과 다르다',
        );
      }
    });
  });

  group('화면 구성', () {
    testWidgets('진행률을 보여준다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      expect(find.textContaining('% 진행 되었어요'), findsOneWidget);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);
    });

    testWidgets('sparkles를 SVG 에셋으로 그린다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      expect(svgWithAsset(AppAssets.iconSparklesLarge), findsOneWidget);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);
    });

    testWidgets('뒤로가기를 그린다 (Figma 262:4575 / 262:4709)', (tester) async {
      // 두 로딩 프레임 모두 x=24, y=87에 `fi-br-angle-left`를 둔다.
      // 되돌릴 수 없다는 이유로 숨겼다가 시안과 어긋났다 (이슈 #63).
      for (final kind in RoutineLoadingKind.values) {
        await tester.pumpWidget(wrap(kind));
        await settle(tester);

        expect(
          svgWithAsset(AppAssets.iconBack),
          findsOneWidget,
          reason: '$kind 로딩 화면에 뒤로가기가 없다',
        );

        await tester.pump(totalHold(kind));
        await settle(tester);
      }
    });

    testWidgets('홈도 함께 그린다 (Figma 262:5188 / 262:5190)', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      expect(svgWithAsset(AppAssets.iconHome), findsOneWidget);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);
    });
  });

  group('RoutineStage', () {
    test('진행률이 순서대로 늘어난다', () {
      for (final kind in RoutineLoadingKind.values) {
        final percents = kind.stages.map((s) => s.percent).toList();
        for (var i = 1; i < percents.length; i++) {
          expect(percents[i], greaterThan(percents[i - 1]));
        }
      }
    });

    test('100%를 만들지 않는다', () {
      // 서버가 진행률을 주지 않아 클라이언트가 흉내낸다(이슈 #33).
      // 가짜 100%를 보여주면 다 됐는데 안 넘어간다는 인상을 준다.
      for (final kind in RoutineLoadingKind.values) {
        for (final stage in kind.stages) {
          expect(stage.percent, lessThan(100));
        }
      }
    });

    test('generate가 prepare보다 뒤 진행률을 쓴다', () {
      // 두 화면이 이어지므로 진행률이 뒤로 가면 안 된다
      expect(
        RoutineLoadingKind.generate.stages.first.percent,
        greaterThan(RoutineLoadingKind.prepare.stages.last.percent),
      );
    });

    test('Figma가 보여주는 값이 들어있다 — prepare 40% / generate 90%', () {
      expect(
        RoutineLoadingKind.prepare.stages.map((s) => s.percent),
        contains(40),
      );
      expect(
        RoutineLoadingKind.generate.stages.map((s) => s.percent),
        contains(90),
      );
    });
  });
}

/// [label] 줄의 현재 투명도. 스텝이 실제로 보이는지 판단하는 기준이다.
double opacityOf(WidgetTester tester, String label) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedOpacity),
    ).first,
  );
  return opacity.opacity;
}
