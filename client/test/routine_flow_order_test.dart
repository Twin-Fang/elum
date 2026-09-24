import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
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
import 'helpers/fake_dio.dart';
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

  /// [below] 를 주면 그 화면 위에 흐름을 **push** 한다 — 앱에서 홈·임시저장이
  /// 흐름을 여는 모양 그대로다. 흐름을 닫으면 어디로 돌아가는지 볼 때 쓴다.
  Future<GoRouter> pumpFlow(
    WidgetTester tester, {
    bool withQuestion = true,
    String? below,
    List<Routine> drafts = const [],
  }) async {
    repo = _Repo(withQuestion: withQuestion)..drafts = drafts;
    final router = createRouter()..go(below ?? Routes.routineInput);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(
            onboardingCompleted: true,
            nickname: '하늘이',
          ),
          routineRepositoryProvider.overrideWithValue(repo),
          // 흐름 아래에 진짜 홈을 깔 때 — 이룸이 정보·공지가 실서버를 타지 않게 한다.
          memberProvider.overrideWith((ref) async => null),
          fakeDioOverride(const {}),
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
    if (below != null) {
      router.push(Routes.routineInput);
      await settle(tester);
    }
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
    // **묻지 않는다** — 한 칸 돌아가는 것이라 적은 것이 그대로 남는다 (#387 D3).
    await tester.tap(find.bySemanticsLabel('뒤로 가기'));
    await tester.pump();
    await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
    expect(find.byType(ElumDialogCard<bool>), findsNothing);

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
    await tester.pump();
    await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
    expect(find.byType(ElumDialogCard<bool>), findsNothing);

    expect(find.byType(RoutineInputScreen), findsOneWidget);
    expect(find.text('내일 비 오는 날 등교'), findsOneWidget);
    expectBackdrop(tester, AuroraTone.input);
  });

  group('뒤로는 한 칸 · 떠날 때만 묻는다 (#387 D3)', () {
    testWidgets('보상 — 기기 뒤로는 묻지 않고 입력으로, 홈은 그만둘까요', (tester) async {
      await pumpFlow(tester);
      await typeInputAndSend(tester);
      expect(find.byType(RewardSetupScreen), findsOneWidget);

      // 홈은 흐름을 떠난다 — 카드 만들기 전이라 적은 것이 남지 않는다고 묻는다.
      await tester.tap(find.bySemanticsLabel('홈으로 가기'));
      await settle(tester);
      expect(find.text('일과 만들기를 그만둘까요?'), findsOneWidget);
      await tester.tap(find.text('계속 만들기'));
      await settle(tester);

      // 기기 뒤로(스와이프도 같은 길)는 한 칸 — 묻지 않는다.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
      expect(find.byType(ElumDialogCard<bool>), findsNothing);
      expect(find.byType(RoutineInputScreen), findsOneWidget);
      expect(find.text('내일 비 오는 날 등교'), findsOneWidget);
    });

    testWidgets('추가 질문 — 기기 뒤로는 묻지 않고 보상으로', (tester) async {
      await pumpFlow(tester);
      await typeInputAndSend(tester);
      await tester.tap(find.text('나중에 할게요'));
      await tester.pump();
      await runLoading(tester);
      expect(find.byType(QuestionScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
      expect(find.byType(ElumDialogCard<bool>), findsNothing);
      expect(find.byType(RewardSetupScreen), findsOneWidget);
    });

    testWidgets('입력 — 흐름 첫 화면이라 기기 뒤로가 곧 떠나는 것이다. 묻는다', (tester) async {
      await pumpFlow(tester, below: Routes.guardianDrafts);
      await tester.enterText(find.byType(TextField), '내일 비 오는 날 등교');
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('일과 만들기를 그만둘까요?'), findsOneWidget);
      expect(find.text('지금 나가면 적은 내용은 남지 않아요'), findsOneWidget);
    });
  });

  group('카드 확인의 뒤로는 흐름을 떠난다 (#387 D1)', () {
    /// 홈에서 새로 만들어 카드 확인까지 간다 — 앱과 같은 모양(홈 위에 흐름 push).
    Future<GoRouter> reachReview(WidgetTester tester) async {
      final router = await pumpFlow(tester, below: Routes.guardian);
      await typeInputAndSend(tester);
      await tester.tap(find.text('나중에 할게요'));
      await tester.pump();
      await runLoading(tester);
      await tester.tap(find.text('우산'));
      await settle(tester);
      await tester.tap(find.text('카드 만들기'));
      await tester.pump();
      await runLoading(tester);
      expect(find.byType(CardReviewScreen), findsOneWidget);
      return router;
    }

    /// 흐름 화면이 하나도 남지 않고 들어오기 전 화면([at])에 섰는가.
    void expectOutOfFlow(WidgetTester tester, GoRouter router, String at) {
      expect(router.state.uri.path, at);
      expect(
        find.byType(at == Routes.guardian ? GuardianHomeScreen : DraftRoutinesScreen),
        findsOneWidget,
      );
      // 흐름 아래 가려져 쉬던 화면이 다시 보이는 순간 목록을 다시 그리다 터지지 않는다(#387).
      expect(tester.takeException(), isNull);
      for (final t in [
        CardReviewScreen,
        QuestionScreen,
        RewardSetupScreen,
        RoutineInputScreen,
        RoutineLoadingScreen,
      ]) {
        expect(find.byType(t, skipOffstage: false), findsNothing, reason: '$t 가 남았다');
      }
    }

    Future<void> leave(WidgetTester tester) async {
      await settle(tester);
      // 임시저장에 남는다는 말 — 카드를 만든 뒤라 사실이다.
      expect(find.text('임시저장에 두고 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await tester.pump();
      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
    }

    testWidgets('화살표 → 나가기면 추가 질문이 아니라 흐름 밖으로', (tester) async {
      final router = await reachReview(tester);
      await tester.tap(find.bySemanticsLabel('뒤로 가기'));
      await leave(tester);
      expectOutOfFlow(tester, router, Routes.guardian);
      // 흐름 안으로 돌아가 `그만둘까요`(사라진다) 를 다시 볼 일이 없다.
      expect(find.text('일과 만들기를 그만둘까요?'), findsNothing);
      // AI 를 다시 부르지 않았다.
      expect(repo.createCalls, 1);
    });

    testWidgets('기기 뒤로 → 나가기도 흐름 밖으로', (tester) async {
      final router = await reachReview(tester);
      await tester.binding.handlePopRoute();
      await leave(tester);
      expectOutOfFlow(tester, router, Routes.guardian);
    });

    testWidgets('계속 만들기면 카드 확인에 남는다', (tester) async {
      await reachReview(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.text('계속 만들기'));
      await settle(tester);
      expect(find.byType(CardReviewScreen), findsOneWidget);
    });

    testWidgets('임시저장에서 이어서 만들다 뒤로 → 임시저장 목록으로 (T7)', (tester) async {
      final router = await pumpFlow(
        tester,
        drafts: const [
          Routine(
            id: 'd1',
            title: '비 오는 날 등교',
            status: 'PENDING_REVIEW',
            steps: [ActionCard(id: 'c1', stepOrder: 1, description: '우산을 챙겨요')],
          ),
        ],
      )..go(Routes.guardianDrafts);
      await settle(tester);
      await tester.tap(find.text('비 오는 날 등교'));
      await settle(tester);
      expect(find.byType(CardReviewScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await leave(tester);
      expectOutOfFlow(tester, router, Routes.guardianDrafts);
    });
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
    String idempotencyKey = '',
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

  /// 임시저장 화면이 보여줄 목록.
  List<Routine> drafts = const [];

  @override
  Future<List<Routine>> getMyRoutines() async => drafts;

  @override
  Future<List<Routine>> getTodayRoutines() async => const [];

  @override
  Future<List<Routine>> getPastRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async =>
      RoutineSuggestion.fallback;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
