import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/reward_chip.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 보상 정하기 화면 8-1 (`docs/03-screens.md` · 이슈 #239).
///
/// **보상은 선택 항목이다.** 건너뛰어도 흐름이 끝까지 가야 한다 — 필수로 만들면
/// 일과 만들기가 한 단계 더 무거워진다.
void main() {
  useFigmaViewport();

  late _FakeRepo repo;

  setUp(() => repo = _FakeRepo());

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.routineReward,
      routes: [
        GoRoute(
          path: Routes.routineReward,
          builder: (context, state) =>
              RewardSetupScreen(fromReview: state.extra == true),
        ),
        GoRoute(
          path: Routes.routineGenerating,
          builder: (context, state) => const Scaffold(body: Text('로딩 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        routineRepositoryProvider.overrideWithValue(repo),
        testStorageOverride(nickname: '하늘이'),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// 배경(aurora)이 무한 반복하므로 `pumpAndSettle`을 쓸 수 없다 —
  /// 정착할 프레임이 없어 타임아웃한다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  bool ctaEnabled(WidgetTester tester) =>
      tester.widget<ElumButton>(find.byType(ElumButton)).onPressed != null;

  group('고르기', () {
    testWidgets('아무것도 고르지 않으면 다음을 누를 수 없다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.textContaining('무엇을 할 수 있나요'), findsOneWidget);
      expect(ctaEnabled(tester), isFalse);
    });

    testWidgets('이룸이 이름이 부제에 들어간다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.text('하늘이가 좋아하는 걸 적어주세요'), findsOneWidget);
    });

    testWidgets('받침 있는 이름에 조사를 맞춘다 (이슈 #196)', (tester) async {
      final router = GoRouter(
        initialLocation: Routes.routineReward,
        routes: [
          GoRoute(
            path: Routes.routineReward,
            builder: (context, state) => const RewardSetupScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineRepositoryProvider.overrideWithValue(repo),
            testStorageOverride(nickname: '민준'),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
            ),
          ),
        ),
      );
      await settle(tester);

      // 손으로 `가`를 붙이면 `민준가`가 된다
      expect(find.text('민준이 좋아하는 걸 적어주세요'), findsOneWidget);
    });

    testWidgets('입력칸이 처음부터 열려 있다 (이슈 #241)', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      // 프리셋을 걷어냈다 — 보상은 고르는 게 아니라 적는 것이다.
      expect(find.byType(RewardInputField), findsOneWidget);
      expect(find.text('좋아하는 간식'), findsNothing);
      expect(find.text('직접 입력'), findsNothing);
    });

    testWidgets('적으면 다음이 열린다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      await tester.enterText(find.byType(TextField), '젤리 먹기');
      await settle(tester);

      expect(ctaEnabled(tester), isTrue);
    });
  });

  group('건너뛰기 — 보상은 선택이다', () {
    testWidgets('건너뛰면 보상 없이 카드 생성으로 간다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      await tester.tap(find.text('건너뛰기'));
      await settle(tester);

      expect(find.text('로딩 화면'), findsOneWidget);
    });

    testWidgets('고른 뒤 건너뛰면 고른 것이 지워진다', (tester) async {
      late WidgetRef capturedRef;
      final router = GoRouter(
        initialLocation: Routes.routineReward,
        routes: [
          GoRoute(
            path: Routes.routineReward,
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const RewardSetupScreen();
              },
            ),
          ),
          GoRoute(
            path: Routes.routineGenerating,
            builder: (context, state) => const Scaffold(body: Text('로딩 화면')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineRepositoryProvider.overrideWithValue(repo),
            testStorageOverride(nickname: '하늘이'),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
            ),
          ),
        ),
      );
      await settle(tester);

      await tester.enterText(find.byType(TextField), '산책');
      await settle(tester);
      await tester.tap(find.text('건너뛰기'));
      await settle(tester);

      // 키만 남으면 이룸이 화면이 문구 없는 이모지를 띄운다
      expect(capturedRef.read(routineFlowProvider).rewardText, isEmpty);
      expect(capturedRef.read(routineFlowProvider).rewardPresetKey, isEmpty);
    });
  });

  group('최근에 정한 보상', () {
    testWidgets('없으면 섹션째 숨긴다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      // 빈 영역을 남기면 로딩에 실패한 것처럼 보인다
      expect(find.text('최근 보상'), findsNothing);
    });

    testWidgets('있으면 최대 3개까지 보여주고 탭 한 번으로 고른다', (tester) async {
      repo.recents = const [
        RecentReward(rewardText: '젤리 먹기', rewardPresetKey: 'SNACK'),
        RecentReward(rewardText: '공원 가기', rewardPresetKey: 'WALK'),
        RecentReward(rewardText: '만화 보기', rewardPresetKey: 'VIDEO'),
        RecentReward(rewardText: '넷째는 안 보인다', rewardPresetKey: 'PLAY'),
      ];

      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.text('최근 보상'), findsOneWidget);
      expect(find.text('젤리 먹기'), findsOneWidget);
      expect(find.text('넷째는 안 보인다'), findsNothing);

      await tester.tap(find.text('젤리 먹기'));
      await settle(tester);
      expect(ctaEnabled(tester), isTrue);
      // 고른 문구가 입력칸에 들어간다 — 거기서 바로 고칠 수 있어야 한다
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '젤리 먹기',
      );
    });

    testWidgets('빈 문구가 섞여 와도 칩으로 만들지 않는다', (tester) async {
      repo.recents = const [
        RecentReward(rewardText: '', rewardPresetKey: 'SNACK'),
      ];

      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.text('최근 보상'), findsNothing);
    });

    testWidgets('조회가 실패해도 화면이 뜬다', (tester) async {
      repo.recentsThrows = true;

      await tester.pumpWidget(wrap());
      await settle(tester);

      // 보상은 없어도 되는 기능이다 — 조회 실패가 화면을 막지 않는다
      expect(find.textContaining('무엇을 할 수 있나요'), findsOneWidget);
      expect(find.text('최근 보상'), findsNothing);
    });
  });

  testWidgets('자문 문구를 보여준다', (tester) async {
    await tester.pumpWidget(wrap());
    await settle(tester);

    // 보호자가 "큰 것"을 떠올리기 쉬워 먼저 말해 준다
    expect(
      find.text('한 달 뒤 선물보다 오늘 받을 수 있는 것이 더 효과적이에요'),
      findsOneWidget,
    );
  });
}

class _FakeRepo with FakeRewardApi implements RoutineRepository {
  List<RecentReward> recents = const [];
  bool recentsThrows = false;

  @override
  Future<List<RecentReward>> getRecentRewards() async {
    if (recentsThrows) throw Exception('network');
    return recents;
  }

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async =>
      const RoutineQuestion(isRequired: false);

  @override
  Future<List<Routine>> getMyRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async =>
      RoutineSuggestion.fallback;

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
    String rewardText = '',
    String rewardPresetKey = '',
  }) async =>
      const Routine(id: 'test');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async =>
      (routine: routine, failure: null);

  @override
  Future<List<Routine>> getTodayRoutines() async => const [];
}
