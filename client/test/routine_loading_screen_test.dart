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

import 'helpers/fake_dio.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// Figma `보호자_새로운 일과 만들기_로딩`(262:4569 / 262:4703) 정합 테스트.

/// 연출(2+1.5+2=5.5초)보다 느린 응답. "결과를 기다리는 동안"을 만들되,
/// 테스트가 끝까지 흘려보낼 수 있을 만큼만 늦춘다.
const _slowResponse = Duration(seconds: 8);

void main() {
  /// 보호자에게 물을 것이 하나 있는 응답 (실측 형태).
  const oneQuestion = {
    'required': true,
    'questions': [
      {
        'question': '꼭 챙겨야 하는 준비물이 있나요?',
        'options': [
          {'emoji': '☂️', 'label': '우산'},
        ],
      },
    ],
  };

  Widget wrap(
    RoutineLoadingKind kind, {
    Duration responseDelay = Duration.zero,
    Map<String, Object?> questions = oneQuestion,
    Object? createResult,
  }) {
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
          path: Routes.routineGenerating,
          builder: (context, state) => const Scaffold(body: Text('카드 생성 로딩')),
        ),
        GoRoute(
          path: Routes.routineReview,
          builder: (context, state) => const Scaffold(body: Text('카드 확인')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        // mock을 걷어낸 뒤(#263) 이 화면은 실제로 서버를 부른다. 무엇이 온다고
        // 가정하는지 테스트 안에 드러내 둔다.
        fakeDioOverride(delay: responseDelay, {
          'POST /api/routines/questions': questions,
          'POST /api/routines': createResult ?? const {
            'id': 'r1',
            'title': '테스트 일과',
            'status': 'PENDING_REVIEW',
            'steps': [
              {'id': 'c1', 'stepOrder': 1, 'description': '첫 단계'},
            ],
          },
        }),
        testStorageOverride(onboardingCompleted: true),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  /// 배경이 무한 반복하므로 pumpAndSettle을 쓸 수 없다
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  /// 모든 스텝의 노출시간을 합친 값 — 이만큼 지나야 화면이 넘어갈 수 있다
  Duration totalHold(RoutineLoadingKind kind) =>
      kind.stages.map((s) => s.hold).fold(Duration.zero, (a, b) => a + b);

  /// 남은 연출과 응답을 끝까지 흘려보낸다.
  ///
  /// 대기를 잘게 쪼개 확인하도록 바뀌어(#276) 화면이 살아 있는 동안 타이머가
  /// 계속 생긴다. 검증만 하고 테스트를 끝내면 `A Timer is still pending`으로
  /// 터지므로, 화면이 넘어가 dispose될 때까지 돌려 준다.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(_slowResponse + const Duration(seconds: 1));
    await settle(tester);
  }

  group('prepare 로딩 (262:4569)', () {
    testWidgets('Figma 문구가 보인다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      expect(find.text('루미가 내용을\n정리하고 있어요'), findsOneWidget);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);
    });

    testWidgets('단계 문구가 Figma 262:4569 렌더 결과와 같다 — 첫 줄만 #383 에서 바꿈', (tester) async {
      // 첫 줄은 시안이 `이룸이를 알아볼 수 있는 정보는 가려요` 다. AI DLP 를 꺼서(#377) 사실이 아닌
      // 안내가 되어 사용자 승인으로 바꿨다(#383). 디자이너가 시안을 고치면 이 주석을 지운다.
      // ⚠️ JSON 덤프에는 화면에 그려지지 않는 레이어까지 섞여 나온다
      // (262:4678 `아이가 이해하기 쉬운 말로 바꿔요`). 덤프만 보고 고치면
      // 멀쩡한 문구를 틀린 값으로 바꾸게 된다 — 실제로 그런 적이 있다.
      // 기준은 **렌더된 PNG**다.
      expect(
        RoutineLoadingKind.prepare.stages.map((s) => s.label).toList(),
        const ['적어 주신 상황을 살펴보고 있어요', '꼭 필요한 내용만 정리해요', '추가 질문을 생각하고 있어요'],
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

    testWidgets('응답이 늦으면 두 번째 스텝은 첫 스텝의 노출시간이 지난 뒤에 뜬다', (tester) async {
      // 응답을 늦춰야 연출이 제 리듬으로 돈다. 즉시 응답하면 남은 줄을
      // 훑고 지나가므로(#276) 이 리듬 자체를 볼 수 없다.
      await tester.pumpWidget(
        wrap(RoutineLoadingKind.prepare, responseDelay: _slowResponse),
      );
      await settle(tester);

      final stages = RoutineLoadingKind.prepare.stages;
      await tester.pump(stages[0].hold);
      await settle(tester);

      expect(opacityOf(tester, stages[1].label), 1.0);
      expect(opacityOf(tester, stages[2].label), 0.0);

      await drain(tester);
    });

    testWidgets('질문 준비가 끝나면 추가 질문 화면으로 넘어간다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);

      expect(find.text('추가 질문'), findsOneWidget);
    });

    testWidgets('물을 것이 없으면 질문 화면을 건너 곧장 카드 생성 로딩으로 간다 (#380)', (
      tester,
    ) async {
      // 도움 목표에 준비물(PREPARE_*)이 없으면 서버가 빈 배열을 준다. 보상은 이미
      // 앞에서 정했으니 질문 화면을 한 프레임 띄웠다 넘길 이유가 없다 — 띄우면
      // 배경이 파랑 쪽으로 번지다 되돌아온다.
      await tester.pumpWidget(
        wrap(RoutineLoadingKind.prepare, questions: const {'questions': []}),
      );
      await settle(tester);

      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);

      expect(find.text('추가 질문'), findsNothing);
      expect(find.text('카드 생성 로딩'), findsOneWidget);
    });
  });

  group('로딩에서 나가기 (#387 T4·T5)', () {
    testWidgets('카드 만드는 중 홈 — 다 만들어지면 임시저장에 남는다고 말한다 (T4)', (tester) async {
      await tester.pumpWidget(
        wrap(RoutineLoadingKind.generate, responseDelay: _slowResponse),
      );
      await settle(tester);

      await tester.tap(find.bySemanticsLabel('홈으로 가기'));
      await settle(tester);

      // 나가도 생성 요청은 서버에서 끝까지 가서 임시저장으로 남는다 — 경고가 아니다.
      expect(find.text('임시저장에 두고 나갈까요?'), findsOneWidget);
      expect(
        find.text('카드가 다 만들어지면 임시저장에 남아요\n설정에서 이어서 만들 수 있어요'),
        findsOneWidget,
      );
      await tester.tap(find.text('계속 만들기'));
      await drain(tester);
    });

    // 뒤로는 흐름 안 한 칸이라 묻지 않는다 — `exit_confirm_test`의 askOnBack 이 본다.

    testWidgets('만들지 못했으면 남은 것이 없다 — 그만둘까요 (T5)', (tester) async {
      await tester.pumpWidget(
        wrap(
          RoutineLoadingKind.generate,
          createResult: const FakeHttpError(500),
        ),
      );
      await settle(tester);
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(find.text('카드를 만들지 못했어요'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('홈으로 가기'));
      await settle(tester);

      expect(find.text('일과 만들기를 그만둘까요?'), findsOneWidget);
      expect(find.text('지금 나가면 적은 내용은 남지 않아요'), findsOneWidget);
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

  group('노출시간', () {
    testWidgets('응답이 빨리 오면 연출을 끝까지 채우지 않고 넘어간다 (#276)', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.generate));
      await settle(tester);

      // 세 줄을 짧게 훑는 시간이면 충분하다. 예전에는 4+3+4=11초를 다 채워야
      // 넘어갔고, 화면이 둘이라 일과 하나에 22초가 들었다.
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('카드 확인'), findsOneWidget);
    });

    testWidgets('아무리 빨라도 한 줄은 보여준다 — 무엇을 했는지 읽을 틈은 준다 (#276)', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.generate));
      await settle(tester);

      // 개인정보를 가린다는 사실은 보호자가 봐야 의미가 있다.
      // 한 프레임에 세 줄이 스쳐 지나가면 보여준 것이 아니다.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('카드 확인'), findsNothing);

      await drain(tester);
    });

    testWidgets('응답이 늦으면 정해진 리듬을 지킨다 (#276)', (tester) async {
      await tester.pumpWidget(
        wrap(RoutineLoadingKind.generate, responseDelay: _slowResponse),
      );
      await settle(tester);

      final stages = RoutineLoadingKind.generate.stages;
      await tester.pump(stages[0].hold + stages[1].hold);
      await settle(tester);
      expect(find.text('카드 확인'), findsNothing, reason: '결과가 없는데 화면이 넘어갔다');

      // 단계를 다 소진해도 결과가 없으면 기다린다 — 가짜로 넘기지 않는다
      await tester.pump(stages[2].hold);
      await settle(tester);
      expect(find.text('카드 확인'), findsNothing);

      await drain(tester);
    });

    testWidgets('스텝 노출시간은 2초 / 1.5초 / 2초다 (#276)', (tester) async {
      // Gemini 시절의 4/3/4는 AI가 느려 어차피 기다리던 때의 값이다.
      // OpenAI로 옮겨 응답이 빨라지자 연출이 오히려 붙잡는 쪽이 됐다.
      for (final kind in RoutineLoadingKind.values) {
        expect(
          kind.stages.map((s) => s.hold.inMilliseconds).toList(),
          [2000, 1500, 2000],
          reason: '$kind의 스텝 노출시간이 다르다',
        );
      }
    });
  });

  group('화면 구성', () {
    testWidgets('진행률을 보여준다', (tester) async {
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);

      expect(find.textContaining('% 진행됐어요'), findsOneWidget);

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

  group('루미 등장 (이슈 #64)', () {
    /// 화면에 그려진 루미 SVG의 가로 중심. 좌우 어느 쪽에서 나오는지 판단한다.
    double lumiCenterX(WidgetTester tester) {
      final finder = imageWithAsset(AppAssets.lumiThinking);
      expect(finder, findsOneWidget, reason: '루미가 화면에 없다');
      return tester.getCenter(finder).dx;
    }

    testWidgets('두 로딩 화면 모두 루미가 나온다', (tester) async {
      // 생성 화면(262:4703)에도 `Group 26`(364:8291)이 있다.
      // 준비 화면에만 그리다 시안과 어긋나 있었다.
      for (final kind in RoutineLoadingKind.values) {
        await tester.pumpWidget(wrap(kind));
        await settle(tester);

        expect(
          imageWithAsset(AppAssets.lumiThinking),
          findsOneWidget,
          reason: '$kind 화면에 루미가 없다',
        );

        await tester.pump(totalHold(kind));
        await settle(tester);
      }
    });

    testWidgets('준비는 왼쪽, 생성은 오른쪽에서 나온다', (tester) async {
      // Figma `Group 26` x좌표 — 준비 -48(왼쪽 밖) / 생성 325(오른쪽 밖).
      // 방향이 반대이므로 화면 중앙을 기준으로 갈린다.
      await tester.pumpWidget(wrap(RoutineLoadingKind.prepare));
      await settle(tester);
      final prepareX = lumiCenterX(tester);
      await tester.pump(totalHold(RoutineLoadingKind.prepare));
      await settle(tester);

      await tester.pumpWidget(wrap(RoutineLoadingKind.generate));
      await settle(tester);
      final generateX = lumiCenterX(tester);
      await tester.pump(totalHold(RoutineLoadingKind.generate));
      await settle(tester);

      const screenCenter = 393 / 2;
      expect(prepareX, lessThan(screenCenter), reason: '준비 루미가 왼쪽이 아니다');
      expect(generateX, greaterThan(screenCenter), reason: '생성 루미가 오른쪽이 아니다');
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
    find
        .ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity))
        .first,
  );
  return opacity.opacity;
}
