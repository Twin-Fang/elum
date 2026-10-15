import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/reward_chip.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';

/// 보상 정하기 화면 8-1 (`docs/03-screens.md` · 이슈 #239).
///
/// **보상은 선택 항목이다.** 건너뛰어도 흐름이 끝까지 가야 한다 — 필수로 만들면
/// 일과 만들기가 한 단계 더 무거워진다.
/// 도움말 본문. 낱말 단위 줄바꿈 표시가 섞여 [find.text] 로는 못 찾는다 (#393 S4).
Finder whyMessageText() => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data == RewardSetupScreen.whyMessage ||
          w.semanticsLabel == RewardSetupScreen.whyMessage),
);

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
          path: Routes.routineMasking,
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

  group('시안 문구 (1082:4709 · #380)', () {
    testWidgets('입력칸이 처음부터 열려 있다 (이슈 #241)', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      // 프리셋을 걷어냈다 — 보상은 고르는 게 아니라 적는 것이다.
      expect(find.byType(RewardInputField), findsOneWidget);
      expect(find.text('좋아하는 간식'), findsNothing);
      expect(find.text('직접 입력'), findsNothing);
    });

  });

  // #393 S4 — 360 폭 기본 글꼴에서 `이룸이 / 가`처럼 낱말 가운데서 줄이 바뀌었다.
  // 공지 팝업(#390)의 낱말 단위 줄바꿈을 이 팝업에만 건다(앱 전체 규칙은 그대로).
  group('나중에 할게요 — 보상은 선택이다', () {
    testWidgets('적은 뒤 나중에 할게요를 누르면 적은 것이 지워진다', (tester) async {
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
            path: Routes.routineMasking,
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
      await tester.tap(find.text('나중에 할게요'));
      await settle(tester);

      // 키만 남으면 이룸이 화면이 문구 없는 이모지를 띄운다
      expect(capturedRef.read(routineFlowProvider).rewardText, isEmpty);
      expect(capturedRef.read(routineFlowProvider).rewardPresetKey, isEmpty);
    });
  });

  group('카드 검토에서 고치러 왔을 때 (#380 실기기 B)', () {
    // 실기기에서 검토 → 보상 고치기 → `나중에 할게요`가 확인 없이 기존 보상을 지웠다
    // (DB '젤리 2개' → 빈 값). 나중에 하겠다는 말은 "지금 안 고친다"지 "없앤다"가 아니다.
  });

  group('빠르게 두 번 누르기 (E8)', () {
    // 질문 준비 로딩이 두 번 쌓이면 AI 호출이 두 번 나간다 — 한 번이 곧 비용이다.
    late GoRouter router;

    Future<_PushCounter> pumpCounting(WidgetTester tester) async {
      final counter = _PushCounter();
      router = GoRouter(
        initialLocation: Routes.routineReward,
        observers: [counter],
        routes: [
          GoRoute(
            path: Routes.routineReward,
            builder: (context, state) => const RewardSetupScreen(),
          ),
          GoRoute(
            path: Routes.routineMasking,
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
      counter.pushes.clear();
      return counter;
    }

    testWidgets('다음을 두 번 눌러도 로딩은 한 번만 열린다', (tester) async {
      final counter = await pumpCounting(tester);
      await tester.enterText(find.byType(TextField), '젤리 먹기');
      await settle(tester);

      await tester.tap(find.text('다음'));
      await tester.tap(find.text('다음'), warnIfMissed: false);
      await settle(tester);

      expect(counter.pushes, hasLength(1));
    });

  });

  group('최근에 정한 보상', () {
    testWidgets('빈 문구가 섞여 와도 칩으로 만들지 않는다 (E11)', (tester) async {
      repo.recents = const [
        RecentReward(rewardText: '', rewardPresetKey: 'SNACK'),
      ];

      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.byType(RewardChip), findsNothing);
    });

    testWidgets('조회가 실패해도 화면이 뜬다 (E10)', (tester) async {
      repo.recentsThrows = true;

      await tester.pumpWidget(wrap());
      await settle(tester);

      // 보상은 없어도 되는 기능이다 — 조회 실패가 화면을 막지 않는다
      expect(find.text('일과가 끝나면\n어떤 보상을 줄까요?'), findsOneWidget);
      expect(find.byType(RewardChip), findsNothing);
    });
  });

  group('큰 글꼴에서 글자가 잘리지 않는다 (#380 실기기 A)', () {
    // 실기기 1.3 에서 `나중에 할게요` 아래가 잘렸다(2.0 에서 절반). 자리를 16 으로
    // 못 박은 상자 안에서 글자만 커져, 넘친 것이 아니라 **잘려** 경고도 안 났다.
    // 그래서 넘침 검사로는 못 잡는다 — 그려진 높이가 글자 높이만큼 되는지 잰다.
  });

  group('글꼴 2.0 (E6)', () {
    // 넘침은 flutter_test_config 가 실패로 만든다 — 뜨기만 하면 통과다.
  });
}

class _PushCounter extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route);
}

class _FakeRepo with FakeRewardApi implements RoutineRepository {
  // 카드확인 카드 추가 (#444) — 이 테스트는 쓰지 않는다
  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
  List<RecentReward> recents = const [];
  bool recentsThrows = false;

  /// 서버에 보상 고치기를 보낸 횟수 — 고치러 와서 그냥 돌아가면 0 이어야 한다.
  var rewardUpdates = 0;

  @override
  Future<({Routine routine, AppFailure? failure})> updateReward(
    Routine routine, {
    required String rewardText,
    String rewardPresetKey = '',
  }) {
    rewardUpdates++;
    return super.updateReward(
      routine,
      rewardText: rewardText,
      rewardPresetKey: rewardPresetKey,
    );
  }

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
    String idempotencyKey = '',
  }) async =>
      const Routine(id: 'test');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async =>
      null;

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId, {
    required String title,
    required String description,
  }) async =>
      (routine: routine, failure: null);

  @override
  Future<List<Routine>> getTodayRoutines() async => const [];
}
