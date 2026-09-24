import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/question_screen.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/credit_low_notice.dart';
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

  const notice =
      '크레딧이 7개 남았어요. 그림이 여러 장 생성돼도 이번 일과는 끝까지 만들어지고 크레딧은 0이 될 수 있어요';

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

  group('추가 질문 — `카드 만들기` 위', () {
    testWidgets('11 보다 적으면 남은 양과 함께 안내한다', (tester) async {
      await pump(tester, const QuestionScreen(), credit: credit(7), flow: answered);

      expect(find.text(notice), findsOneWidget);
      final noticeBox = tester.getRect(find.byType(CreditLowNotice));
      final cta = tester.getRect(find.text('카드 만들기'));
      expect(noticeBox.top, lessThan(cta.top), reason: 'CTA 위에 선다');
    });

    testWidgets('넉넉하면 안내가 없다', (tester) async {
      await pump(tester, const QuestionScreen(), credit: credit(50), flow: answered);
      expect(find.textContaining('크레딧이'), findsNothing);
    });

    testWidgets('조회에 실패하면 안내가 없다 — 흐름을 막지 않는다', (tester) async {
      await pump(tester, const QuestionScreen(), flow: answered);
      expect(find.textContaining('크레딧이'), findsNothing);
      expect(find.text('카드 만들기'), findsOneWidget);
    });

    testWidgets('꺼져 있으면 안내가 없다', (tester) async {
      await pump(
        tester,
        const QuestionScreen(),
        credit: const CreditSummary.disabled(),
        flow: answered,
      );
      expect(find.textContaining('크레딧이'), findsNothing);
    });

    testWidgets('글꼴 2.0 에서도 넘치지 않는다', (tester) async {
      await pump(
        tester,
        const QuestionScreen(),
        credit: credit(7),
        flow: answered,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('보상 — 아래 버튼 위', () {
    testWidgets('11 보다 적으면 안내한다', (tester) async {
      await pump(tester, const RewardSetupScreen(), credit: credit(7));

      expect(find.text(notice), findsOneWidget);
      final noticeBox = tester.getRect(find.byType(CreditLowNotice));
      final cta = tester.getRect(find.text('다음'));
      expect(noticeBox.top, lessThan(cta.top));
    });

    testWidgets('넉넉하면 안내가 없다', (tester) async {
      await pump(tester, const RewardSetupScreen(), credit: credit(50));
      expect(find.textContaining('크레딧이'), findsNothing);
    });
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
