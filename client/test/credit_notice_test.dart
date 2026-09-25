import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/question_screen.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/credit_usage.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/credit_fixtures.dart';
import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/test_storage.dart';

/// 생성 직전 안내와 완료 사용량 줄 (#407 스펙 §5). ⚠️ 둘 다 시안 밖 요소다.
void main() {
  useFigmaViewport();


  /// [credit] 이 null 이면 조회에 실패한다.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget screen, {
    CreditSummary? credit,
    RoutineFlowState flow = const RoutineFlowState(),
    double textScale = 1,
  }) async {
    final container = ProviderContainer(
      overrides: [
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        offlineDioOverride(),
        speechServiceProvider.overrideWithValue(_SilentSpeech()),
        creditSummaryProvider.overrideWith((ref) async {
          if (credit == null) throw const AppFailure(fault: NetworkFault.offline);
          return credit;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(routineFlowProvider.notifier).state = flow;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            routerConfig: GoRouter(
              initialLocation: '/x',
              routes: [GoRoute(path: '/x', builder: (context, state) => screen)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  CreditSummary credit(int available) =>
      CreditSummary.fromJson(creditJson(available: available));

  const question = RoutineQuestion(
    isRequired: true,
    questions: [
      QuestionItem(
        question: '꼭 챙겨야 하는 준비물이 있나요?',
        options: [QuestionOption(label: '우산')],
      ),
    ],
  );
  const answered = RoutineFlowState(
    step: RoutineFlowStep.question,
    question: question,
    answers: ['우산'],
  );

  // 만드는 흐름(추가 질문 · 보상)에는 크레딧 경고 띠를 두지 않는다 (#421 ·
  // 2026-09-25 사용자 결정 — "내 크레딧이 몇인지 warning 문구 굳이 추가하지 말지?
  // 괜히 이상하고 별론데"). 잔액은 설정 카드가, 모자라면 생성 실패 화면이 말한다.
  group('만드는 흐름에는 크레딧 경고가 없다', () {
    for (final available in [0, 7]) {
      testWidgets('추가 질문 — 잔액 $available 이어도 버튼만 있다', (tester) async {
        await pump(tester, const QuestionScreen(), credit: credit(available), flow: answered);

        expect(find.textContaining('크레딧이'), findsNothing);
        expect(find.textContaining('끝까지 만들어지고'), findsNothing);
        expect(find.text('카드 만들기'), findsOneWidget);
      });

      testWidgets('보상 — 잔액 $available 이어도 버튼만 있다', (tester) async {
        await pump(tester, const RewardSetupScreen(), credit: credit(available));

        expect(find.textContaining('크레딧이'), findsNothing);
        expect(find.text('다음'), findsOneWidget);
      });
    }
  });

  group('카드 확인 — 머리 아래 사용량 줄', () {
    const routine = Routine(
      id: 'r1',
      title: '학교에 가요',
      status: 'PENDING_REVIEW',
      steps: [ActionCard(id: 'c1', stepOrder: 1, title: '옷', description: '옷을 입어요')],
    );

    testWidgets('생성 응답의 credit 을 한 줄로 보인다', (tester) async {
      await pump(
        tester,
        const CardReviewScreen(),
        flow: const RoutineFlowState(
          step: RoutineFlowStep.review,
          routine: routine,
          creditUsage: CreditUsage(
            cardCount: 5,
            imageCount: 4,
            charged: 5,
            balanceAfter: 67,
          ),
        ),
      );

      expect(find.text('AI 그림 4장 · 5크레딧 사용 · 67 남음'), findsOneWidget);
      final title = tester.getRect(find.text('카드 1개를 만들었어요'));
      final line = tester.getRect(find.text('AI 그림 4장 · 5크레딧 사용 · 67 남음'));
      expect(line.top, greaterThanOrEqualTo(title.bottom));
    });

    testWidgets('credit 이 없으면 줄이 없다', (tester) async {
      await pump(
        tester,
        const CardReviewScreen(),
        flow: const RoutineFlowState(step: RoutineFlowStep.review, routine: routine),
      );

      expect(find.textContaining('크레딧 사용'), findsNothing);
    });
  });
}

class _SilentSpeech implements SpeechService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
