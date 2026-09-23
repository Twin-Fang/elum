import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/question_screen.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/aurora_probe.dart';
import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 일과 만들기 **흐름 순서** (#380 결정 1 — Figma 섹션 `1049:4654` 대로).
///
/// ```
/// 입력 → 보상 → 준비 로딩 → 추가 질문 → 생성 로딩 → 카드 확인
/// ```
///
/// 처음(#239)에는 보상이 추가 질문 다음이었다. 앱과 **같은 라우터**로 처음부터
/// 끝까지 밟으며, 순서·되돌아가기·AI 호출 횟수·화면마다 배경 색을 함께 본다.
void main() {
  useFigmaViewport();

  final light = AppColors.light;

  late _Repo repo;

  /// 배경이 끝없이 떠다녀 `pumpAndSettle`은 끝나지 않는다. 전환(400)이 끝날 만큼만.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<GoRouter> pumpFlow(WidgetTester tester, {bool withQuestion = true}) async {
    repo = _Repo(withQuestion: withQuestion);
    final router = createRouter()..go(Routes.routineInput);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(
            onboardingCompleted: true,
            nickname: '하늘이',
          ),
          routineRepositoryProvider.overrideWithValue(repo),
          routineSuggestionsProvider.overrideWith(
            (ref) async => RoutineSuggestion.fallback,
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      ),
    );
    await settle(tester);
    return router;
  }

  /// 로딩 연출(2+1.5+2초)과 배경 번짐까지 흘려보낸다. **잘게 쪼갠다** — 단계는
  /// 100ms 틱을 세며 드러나서 한 번에 큰 값을 주면 첫 줄에서 멈춘다.
  Future<void> runLoading(WidgetTester tester) async {
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle(tester);
  }

  /// 맨 위 화면의 배경 색이 그 화면이 선언한 색인가.
  void expectBackdrop(WidgetTester tester, AuroraTone tone) => expect(
    readAuroraColors(tester),
    AuroraPalette.of(light, tone).visibleColors,
    reason: '배경이 $tone 이 아니다',
  );

  Future<void> typeInputAndSend(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '내일 비 오는 날 등교');
    await settle(tester);
    await tester.tap(find.byKey(RoutineInputScreen.sendButtonKey));
    await settle(tester);
  }

  testWidgets('입력 → 보상 → 준비 로딩 → 추가 질문 → 생성 로딩 → 카드 확인', (tester) async {
    await pumpFlow(tester);
    expectBackdrop(tester, AuroraTone.input);

    // 입력 바로 다음이 보상이다. 아직 AI 를 부르지 않는다.
    await typeInputAndSend(tester);
    expect(find.byType(RewardSetupScreen), findsOneWidget);
    expect(repo.questionCalls, 0);
    // 글자는 400 에 자리 잡고 배경은 700 에 다 번진다.
    await tester.pump(AppMotion.ambient);
    expectBackdrop(tester, AuroraTone.reward);

    await tester.enterText(find.byType(TextField), '젤리 먹기');
    await settle(tester);
    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 보상 다음이 질문 준비 로딩이다 — 여기서 질문을 받아 온다.
    expect(find.byType(RoutineLoadingScreen), findsOneWidget);
    expect(find.text('루미가 내용을\n정리하고 있어요'), findsOneWidget);
    await tester.pump(AppMotion.ambient);
    expectBackdrop(tester, AuroraTone.preparing);

    await runLoading(tester);
    expect(find.byType(QuestionScreen), findsOneWidget);
    expect(repo.questionCalls, 1);
    expect(repo.createCalls, 0);
    expectBackdrop(tester, AuroraTone.question);

    await tester.tap(find.text('우산'));
    await settle(tester);
    await tester.tap(find.text('카드 만들기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('루미가 행동카드를\n만들고 있어요'), findsOneWidget);
    await tester.pump(AppMotion.ambient);
    expectBackdrop(tester, AuroraTone.generating);

    await runLoading(tester);
    expect(find.byType(CardReviewScreen), findsOneWidget);
    // AI 는 질문 한 번 · 생성 한 번. 앞에서 정한 보상이 생성 요청에 실린다.
    expect(repo.questionCalls, 1);
    expect(repo.createCalls, 1);
    expect(repo.lastReward, '젤리 먹기');
    expect(repo.lastAnswers, ['우산']);
  });

  testWidgets('물을 것이 없으면 질문 화면 없이 곧장 카드를 만든다', (tester) async {
    await pumpFlow(tester, withQuestion: false);
    await typeInputAndSend(tester);

    // 나중에 할게요 — 보상 없이 간다 (E2).
    await tester.tap(find.text('나중에 할게요'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    var sawQuestion = false;
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      sawQuestion |= find.byType(QuestionScreen).evaluate().isNotEmpty;
    }
    await settle(tester);

    expect(sawQuestion, isFalse, reason: '질문 화면이 잠깐이라도 떴다 — 배경이 한 번 출렁인다');
    expect(find.byType(CardReviewScreen), findsOneWidget);
    expect(repo.questionCalls, 1);
    expect(repo.createCalls, 1);
    expect(repo.lastReward, isEmpty);
  });

  testWidgets('되돌아가기 — 추가 질문 → 보상 → 입력, 적은 보상은 남아 있다 (E3)', (tester) async {
    final router = await pumpFlow(tester);
    await typeInputAndSend(tester);
    await tester.enterText(find.byType(TextField), '젤리 먹기');
    await settle(tester);
    await tester.tap(find.text('다음'));
    await tester.pump();
    await runLoading(tester);
    expect(find.byType(QuestionScreen), findsOneWidget);

    // 추가 질문에서 뒤로 — 준비 로딩은 질문 화면으로 교체됐으니 보상으로 돌아간다.
    await tester.tap(find.bySemanticsLabel('뒤로 가기'));
    await settle(tester);
    expect(find.text('만들던 일과가 사라져요'), findsOneWidget);
    await tester.tap(find.text('나가기'));
    await tester.pump();
    await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));

    expect(find.byType(RewardSetupScreen), findsOneWidget);
    expect(find.byType(QuestionScreen), findsNothing);
    expect(find.text('젤리 먹기'), findsOneWidget);
    expectBackdrop(tester, AuroraTone.reward);

    // 돌아온 보상에서 다음이 다시 눌린다 — 두 번 누르기 막음이 풀렸다.
    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RoutineLoadingScreen), findsOneWidget);
    await runLoading(tester);

    // 다시 질문 → 보상으로 나와서, 보상에서 한 번 더 뒤로 가면 입력이다.
    router.pop();
    await tester.pump();
    await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
    expect(find.byType(RewardSetupScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('뒤로 가기'));
    await settle(tester);
    await tester.tap(find.text('나가기'));
    await tester.pump();
    await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));

    expect(find.byType(RoutineInputScreen), findsOneWidget);
    expect(find.text('내일 비 오는 날 등교'), findsOneWidget);
    expectBackdrop(tester, AuroraTone.input);
  });

  testWidgets('입력의 보내기를 빠르게 두 번 눌러도 보상 화면은 한 장이다', (tester) async {
    await pumpFlow(tester);
    await tester.enterText(find.byType(TextField), '내일 비 오는 날 등교');
    await settle(tester);

    await tester.tap(find.byKey(RoutineInputScreen.sendButtonKey));
    await tester.tap(
      find.byKey(RoutineInputScreen.sendButtonKey),
      warnIfMissed: false,
    );
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RewardSetupScreen, skipOffstage: false), findsOneWidget);
  });
}

/// 질문 하나(또는 없음)를 주고 AI 호출 횟수를 센다. 실서버를 타지 않는다.
class _Repo with FakeRewardApi implements RoutineRepository {
  _Repo({required this.withQuestion});

  final bool withQuestion;
  var questionCalls = 0;
  var createCalls = 0;
  String? lastReward;
  List<String>? lastAnswers;

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async {
    questionCalls++;
    return withQuestion
        ? const RoutineQuestion(
            isRequired: true,
            questions: [
              QuestionItem(
                question: '꼭 챙겨야 하는 준비물이 있나요?',
                options: [QuestionOption(label: '우산')],
              ),
            ],
          )
        : const RoutineQuestion(isRequired: false);
  }

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
    String rewardText = '',
    String rewardPresetKey = '',
  }) async {
    createCalls++;
    lastReward = rewardText;
    lastAnswers = answers;
    return Routine(
      id: 'r1',
      title: '비 오는 날 등교',
      status: 'PENDING_REVIEW',
      rewardText: rewardText,
      steps: const [
        ActionCard(id: 'c1', stepOrder: 1, description: '우산을 챙겨요'),
      ],
    );
  }

  @override
  Future<List<Routine>> getMyRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async =>
      RoutineSuggestion.fallback;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
