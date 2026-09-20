@Tags(['golden'])
library;

import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 보호자 홈 개편(이슈 #258)의 렌더 회귀 고정.
///
/// **AI를 부르지 않는다.** 이미 만들어진 일과를 넣어 그리기만 한다 —
/// 일과를 실제로 만들면 카드 생성 API가 돌아 비용이 나간다.
///
/// 기준 이미지는 Figma 931:3896과 눈으로 대조해 승인한 것이다.
/// 골든은 "Figma와 같은가"를 판단하지 못하므로 첫 승인은 사람이 한다.
void main() {
  useFigmaViewport();

  Routine routine(
    String id,
    String title, {
    String reward = '',
    int percent = 0,
    DateTime? at,
  }) =>
      Routine(
        id: id,
        title: title,
        status: 'CONFIRMED',
        rewardText: reward,
        progressPercent: percent,
        scheduledAt: at,
        // 링은 카드의 완료 여부로 셈한다. 퍼센트만 넣고 카드를 미완료로 두면
        // 서버가 절대 주지 않는 조합이 되어 골든이 거짓말을 한다.
        steps: [
          ActionCard(
            id: 'c1',
            stepOrder: 1,
            description: '첫 단계',
            completed: percent >= 50,
          ),
          ActionCard(
            id: 'c2',
            stepOrder: 2,
            description: '둘째 단계',
            completed: percent >= 100,
          ),
        ],
      );

  Widget wrap({
    required List<Routine> routines,
    required List<Routine> past,
  }) =>
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider
              .overrideWithValue(_GoldenRepo(routines: routines, past: past)),
          memberProvider.overrideWith(
            (ref) async => const Member(nickname: '하늘이'),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: const GuardianHomeScreen(),
          ),
        ),
      );

  testWidgets('일과가 있는 홈 — 오늘 · 지난 두 칸', (tester) async {
    await tester.pumpWidget(wrap(
      routines: [
        routine('r1', '스스로 옷을 입어요', reward: '유튜브 시청 20분', percent: 50),
        routine('r2', '밥 먹기 전에 손을 씻어요', reward: '마이구미 5개 먹기', percent: 100),
      ],
      past: [
        routine(
          'p1',
          '학교에 갈 준비를 해요',
          reward: '좋아하는 노래 들으며 학교 가기',
          percent: 100,
          at: DateTime(2026, 9, 20),
        ),
        routine('p2', '밥 먹기 전에 손을 씻어요',
            reward: '거실에서 저녁 먹기', percent: 50, at: DateTime(2026, 9, 19)),
      ],
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GuardianHomeScreen),
      matchesGoldenFile('goldens/guardian_home_filled.png'),
    );
  });

  testWidgets('빈 홈 — 두 칸 모두 비었을 때', (tester) async {
    await tester.pumpWidget(wrap(routines: const [], past: const []));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GuardianHomeScreen),
      matchesGoldenFile('goldens/guardian_home_empty.png'),
    );
  });
}

/// 목록만 돌려주는 저장소. 쓰기는 골든에서 일어나지 않는다.
class _GoldenRepo with FakeRewardApi implements RoutineRepository {
  _GoldenRepo({required this.routines, required this.past});

  final List<Routine> routines;
  final List<Routine> past;

  @override
  Future<List<Routine>> getMyRoutines() async => routines;

  @override
  Future<List<Routine>> getTodayRoutines() async => routines;

  @override
  Future<List<Routine>> getPastRoutines() async => past;

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async =>
      const RoutineQuestion();

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
    String rewardText = '',
    String rewardPresetKey = '',
  }) async =>
      const Routine(id: 'new');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<({Routine routine, bool synced})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async =>
      (routine: routine, synced: true);
}
