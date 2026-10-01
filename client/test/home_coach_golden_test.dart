@Tags(['golden'])
library;

import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';

/// 보호자 홈 코치마크 3단계의 렌더 회귀 고정 (Figma 코치마크_1·2·3 · 이슈 #505).
///
/// 시안 프레임(393×852)은 상태바(59)와 홈 인디케이터(34)를 포함해 그려져 있다.
/// 안전영역을 같이 넣어야 본문 y 가 시안과 맞는다. 기준 이미지는 시안 export 와
/// `figma_diff.py` 로 맞대 확인한 것이다 — 골든은 "시안과 같은가"를 판단하지 못한다.
void main() {
  useFigmaViewport();

  Routine routine(String id, String title, String reward, int percent) =>
      Routine(
        id: id,
        title: title,
        status: 'CONFIRMED',
        rewardText: reward,
        progressPercent: percent,
        steps: [
          ActionCard(
            id: '$id-1',
            stepOrder: 1,
            description: '첫 단계',
            completed: percent >= 50,
          ),
          ActionCard(
            id: '$id-2',
            stepOrder: 2,
            description: '둘째 단계',
            completed: percent >= 100,
          ),
        ],
      );

  Widget app() => ProviderScope(
    overrides: [
      localStorageProvider.overrideWithValue(
        InMemoryStorage(
          onboardingCompleted: true,
          nickname: '하늘이',
          homeCoachSeen: false,
        ),
      ),
      routineRepositoryProvider.overrideWithValue(
        _Repo(
          today: [
            routine('r1', '스스로 옷을 입어요', '유튜브 시청 20분', 50),
            routine('r2', '밥 먹기 전에 손을 씻어요', '마이구미 5개 먹기', 100),
          ],
          past: [
            routine('p1', '학교에 갈 준비를 해요', '좋아하는 노래 들으며 학교 가기', 100),
            routine('p2', '밥 먹기 전에 손을 씻어요', '거실에서 저녁 먹기', 50),
          ],
        ),
      ),
      memberProvider.overrideWith(
        (ref) async => const Member(nickname: '하늘이'),
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 59, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: child!,
        ),
        home: const GuardianHomeScreen(),
      ),
    ),
  );

  Future<void> advance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('코치마크 1·2·3단계', (tester) async {
    await tester.pumpWidget(app());
    await advance(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_coach_1.png'),
    );

    await tester.tapAt(const Offset(200, 760));
    await advance(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_coach_2.png'),
    );

    await tester.tapAt(const Offset(200, 760));
    await advance(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_coach_3.png'),
    );
  });
}

class _Repo with FakeRewardApi implements RoutineRepository {
  _Repo({required this.today, required this.past});

  final List<Routine> today;
  final List<Routine> past;

  @override
  Future<List<Routine>> getMyRoutines() async => today;

  @override
  Future<List<Routine>> getTodayRoutines() async => today;

  @override
  Future<List<Routine>> getPastRoutines() async => past;

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];

  @override
  Future<AppFailure?> delete(String routineId) async => null;

  @override
  Future<AppFailure?> reorder(List<String> routineIds) async => null;

  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);

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
    String idempotencyKey = '',
  }) async => const Routine(id: 'new');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async => null;

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async => (routine: routine, failure: null);
}
