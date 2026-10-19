import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_dio.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

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
        find.text('카드가 다 만들어지면 임시저장에 남아요\n내정보에서 이어서 만들 수 있어요'),
        findsOneWidget,
      );
      await tester.tap(find.text('계속 만들기'));
      await drain(tester);
    });

    // 뒤로는 흐름 안 한 칸이라 묻지 않는다 — `exit_confirm_test`의 backLeavesFlow 가 본다.

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

  });

  group('화면 구성', () {
  });

  group('루미 등장 (이슈 #64)', () {
    /// 화면에 그려진 루미 SVG의 가로 중심. 좌우 어느 쪽에서 나오는지 판단한다.
  });

  group('RoutineStage', () {
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
