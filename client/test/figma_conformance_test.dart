@Tags(['golden'])
library;

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
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

/// **시안 대조용** 렌더. 회귀 확인이 목적인 `*_golden_test.dart`와 다르다.
///
/// 여기서 만든 PNG는 `tool/figma_diff.py`가 `docs/figma/**`의 Figma export와
/// 픽셀로 맞대본다. 그래서 두 가지를 기기와 똑같이 맞춘다.
///
/// - **안전영역** — Figma 프레임은 상단 상태바 59, 하단 홈 인디케이터 21을
///   포함해 852로 그린다. 그 여백을 주지 않으면 본문이 59px 위로 떠서
///   모든 줄이 어긋난 것으로 나온다.
/// - **논리 크기 393×852** — `useFigmaViewport()`가 잡는다.
///
/// 상태바·홈 인디케이터 안의 내용(시계·배터리)은 앱이 그리지 않으므로
/// 비교 도구가 그 띠를 가린다.
void main() {
  useFigmaViewport();

  /// iPhone 16 실측 — 상단 59 · 하단 21
  const deviceInsets = EdgeInsets.only(top: 59, bottom: 21);

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


  /// 시트 대조용. 시안(956:4084)이 그린 네 단계를 그대로 담는다.
  /// 내용이 다르면 diff 가 통째로 붉어져 정작 봐야 할 어긋남이 묻힌다.
  Routine sheetRoutine() => Routine(
        id: 's1',
        title: '스스로 옷을 입어요',
        status: 'CONFIRMED',
        rewardText: '유튜브 시청 20분',
        progressPercent: 50,
        steps: const [
          ActionCard(
            id: 's-c1',
            stepOrder: 1,
            title: '옷을 골라요',
            description: '밖에 나갈 때 입을 옷을 꺼내요',
            completed: true,
          ),
          ActionCard(
            id: 's-c2',
            stepOrder: 2,
            title: '바지를 입어요',
            description: '양쪽 다리를 넣고 바지를 올려 입어요',
            completed: true,
          ),
          ActionCard(
            id: 's-c3',
            stepOrder: 3,
            title: '윗옷을 입어요',
            description: '머리와 팔을 넣어 윗옷을 입어요',
          ),
          ActionCard(
            id: 's-c4',
            stepOrder: 4,
            title: '양말을 신어요',
            description: '양쪽 발에 양말을 신어요',
          ),
        ],
      );


  /// 이룸이 홈 대조용. 보호자 홈과 쓰는 provider 가 다르다.
  Widget wrapChild({required List<Routine> routines, int stars = 0}) =>
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider
              .overrideWithValue(_StubRepo(routines: routines, past: const [])),
          todayRoutinesProvider.overrideWith((ref) async => routines),
          memberProvider.overrideWith(
            (ref) async => Member(nickname: '하늘이', totalStars: stars),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            home: const ChildHomeScreen(),
          ),
        ),
      );

  Widget wrap({
    required List<Routine> routines,
    required List<Routine> past,
  }) =>
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider
              .overrideWithValue(_StubRepo(routines: routines, past: past)),
          memberProvider.overrideWith(
            (ref) async => const Member(nickname: '하늘이'),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            home: const GuardianHomeScreen(),
          ),
        ),
      );

  testWidgets('보호자 홈 — 일과 있음 (Figma 931:3896)', (tester) async {
    await tester.pumpWidget(wrap(
      routines: [
        routine('r1', '스스로 옷을 입어요', reward: '유튜브 시청 20분', percent: 50),
        routine('r2', '밥 먹기 전에 손을 씻어요', reward: '마이구미 5개 먹기', percent: 100),
      ],
      // 시안(931:3896)에 그려진 내용 그대로. 내용이 다르면 diff가 통째로
      // 붉어져 **정작 봐야 할 어긋남이 묻힌다.**
      past: [
        routine('p1', '학교에 갈 준비를 해요',
            reward: '좋아하는 노래 들으며 학교 가기',
            percent: 100,
            at: DateTime(2026, 9, 20)),
        // 시안의 두 번째 카드는 날짜 없이 `일과 다시하기`만 있다.
        routine('p2', '학교에 갈 준비를 해요',
            reward: '좋아하는 노래 들으며 학교 가기', percent: 100),
        routine('p3', '밥 먹기 전에 손을 씻어요',
            reward: '거실에서 저녁 먹기', percent: 50),
      ],
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GuardianHomeScreen),
      matchesGoldenFile('figma/home_931-3896.png'),
    );
  });

  testWidgets('보호자 홈 — 일과 없음 (Figma 217:2655)', (tester) async {
    await tester.pumpWidget(wrap(routines: const [], past: const []));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GuardianHomeScreen),
      matchesGoldenFile('figma/home_217-2655.png'),
    );
  });

  // 오늘 일과를 눌렀을 때 뜨는 시트다. **여기가 가장 많이 어긋나 있던 화면이라**
  // 대조에 올린다 (#295 에서 글꼴·크기·체크·보상 줄까지 여섯 군데가 나왔다).
  // 시트는 홈 위에 덮이므로 화면 전체를 찍는다.
  testWidgets('일과 시트 (Figma 956:4084)', (tester) async {
    await tester.pumpWidget(wrap(routines: [sheetRoutine()], past: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('스스로 옷을 입어요'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('figma/sheet_956-4084.png'),
    );
  });

  // 이룸이가 직접 쓰는 화면이라 올려 둔다. 값으로 대조했을 때는 열두 값이
  // 모두 맞았지만(#297), 픽셀로 맞대본 적은 없었다.
  testWidgets('이룸이 홈 (Figma 356:5079)', (tester) async {
    await tester.pumpWidget(wrapChild(
      // 시안이 그린 내용 그대로. 다르면 차이 그림이 통째로 붉어진다.
      routines: [
        routine('c1', '비 오는 날 학교에 가요', percent: 50),
        routine('c2', '학원 준비물을 챙겨요', percent: 100),
      ],
      stars: 15,
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChildHomeScreen),
      matchesGoldenFile('figma/child_home_356-5079.png'),
    );
  });
}

/// 목록만 돌려준다. 대조용이라 쓰기는 일어나지 않는다.
class _StubRepo with FakeRewardApi implements RoutineRepository {
  _StubRepo({required this.routines, required this.past});

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
