@Tags(['golden'])
library;

import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
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

/// 보상 설정 화면 8-1 (이슈 #239 · 시안 1082:4709 #380).
///
/// 배경(aurora)이 무한 반복해 `pumpAndSettle`을 쓸 수 없다 — `pump()`로 돌린다.
void main() {
  useFigmaViewport();

  Widget wrap(_FakeRepo repo) {
    final router = GoRouter(
      initialLocation: Routes.routineReward,
      routes: [
        GoRoute(
          path: Routes.routineReward,
          builder: (context, state) => const RewardSetupScreen(),
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
        useInheritedMediaQuery: true,
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('첫 일과 — 최근 보상이 없다', (tester) async {
    await tester.pumpWidget(wrap(_FakeRepo()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await expectLater(
      find.byType(RewardSetupScreen),
      matchesGoldenFile('goldens/reward_setup_first.png'),
    );
  });

  testWidgets('두 번째부터 — 최근 보상이 입력칸 아래 칩으로 선다', (tester) async {
    final repo = _FakeRepo()
      ..recents = const [
        RecentReward(rewardText: '젤리 먹기', rewardPresetKey: 'SNACK'),
        RecentReward(rewardText: '공원 가기', rewardPresetKey: 'WALK'),
      ];

    await tester.pumpWidget(wrap(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await expectLater(
      find.byType(RewardSetupScreen),
      matchesGoldenFile('goldens/reward_setup_recents.png'),
    );
  });
}

class _FakeRepo with FakeRewardApi implements RoutineRepository {
  List<RecentReward> recents = const [];

  @override
  Future<List<RecentReward>> getRecentRewards() async => recents;

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
