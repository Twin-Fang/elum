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

  group('시안 문구 (1082:4709 · #380)', () {
    testWidgets('제목·부제·안내가 시안 그대로다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.text('일과가 끝나면\n어떤 보상을 줄까요?'), findsOneWidget);
      expect(find.text('일과를 완료하는 데 큰 동기가 될 거예요'), findsOneWidget);
      expect(find.text('예) 유튜브 10분 보기'), findsOneWidget);
      expect(find.text('보상이 왜 필요한가요?'), findsOneWidget);
      expect(find.text('나중에 할게요'), findsOneWidget);
      // 옛 화면(#241) 문구가 남아 있지 않다
      expect(find.text('건너뛰기'), findsNothing);
      expect(find.text('최근 보상'), findsNothing);
    });

    testWidgets('아무것도 적지 않으면 다음을 누를 수 없다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(ctaEnabled(tester), isFalse);
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

    testWidgets('공백만 적으면 다음이 열리지 않는다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await settle(tester);

      expect(ctaEnabled(tester), isFalse);
    });

    testWidgets('30자에서 멈춘다 (E12)', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      await tester.enterText(find.byType(TextField), '가' * 40);
      await settle(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '가' * 30,
      );
    });

    testWidgets('보상이 왜 필요한가요? 를 누르면 설명이 뜬다 (E14)', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      await tester.tap(find.text('보상이 왜 필요한가요?'));
      await settle(tester);

      expect(
        find.textContaining('한 달 뒤 선물보다 오늘 받을 수 있는 것이 더 효과적이에요'),
        findsOneWidget,
      );
    });
  });

  group('나중에 할게요 — 보상은 선택이다', () {
    testWidgets('누르면 보상 없이 카드 생성으로 간다 (E2)', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      await tester.tap(find.text('나중에 할게요'));
      await settle(tester);

      expect(find.text('로딩 화면'), findsOneWidget);
    });

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
      await tester.tap(find.text('나중에 할게요'));
      await settle(tester);

      // 키만 남으면 이룸이 화면이 문구 없는 이모지를 띄운다
      expect(capturedRef.read(routineFlowProvider).rewardText, isEmpty);
      expect(capturedRef.read(routineFlowProvider).rewardPresetKey, isEmpty);
    });
  });

  group('빠르게 두 번 누르기 (E8)', () {
    // 카드 생성 로딩이 두 번 쌓이면 AI 호출이 두 번 나간다 — 한 번이 곧 비용이다.
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
      counter.pushes.clear();
      return counter;
    }

    testWidgets('다음을 두 번 눌러도 카드 생성은 한 번만 열린다', (tester) async {
      final counter = await pumpCounting(tester);
      await tester.enterText(find.byType(TextField), '젤리 먹기');
      await settle(tester);

      await tester.tap(find.text('다음'));
      await tester.tap(find.text('다음'), warnIfMissed: false);
      await settle(tester);

      expect(counter.pushes, hasLength(1));
    });

    testWidgets('나중에 할게요를 두 번 눌러도 한 번만 열린다', (tester) async {
      final counter = await pumpCounting(tester);

      await tester.tap(find.text('나중에 할게요'));
      await tester.tap(find.text('나중에 할게요'), warnIfMissed: false);
      await settle(tester);

      expect(counter.pushes, hasLength(1));
    });

    testWidgets('로딩에서 돌아오면 다시 누를 수 있다', (tester) async {
      final counter = await pumpCounting(tester);
      await tester.enterText(find.byType(TextField), '젤리 먹기');
      await settle(tester);

      await tester.tap(find.text('다음'));
      await settle(tester);
      expect(find.text('로딩 화면'), findsOneWidget);
      router.pop();
      // 플랫폼 기본 전환은 350ms 보다 길다 — 끝까지 흘려보낸다.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('로딩 화면'), findsNothing);

      await tester.tap(find.text('다음'));
      await settle(tester);
      expect(counter.pushes, hasLength(2));
    });
  });

  group('최근에 정한 보상', () {
    testWidgets('없으면 칩 자리가 빈다 (E10)', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.byType(RewardChip), findsNothing);
    });

    testWidgets('시안처럼 넷까지 보여주고 탭 한 번으로 입력칸에 넣는다', (tester) async {
      repo.recents = const [
        RecentReward(rewardText: '인형놀이 20분', rewardPresetKey: 'CUSTOM'),
        RecentReward(rewardText: '젤리 4개 먹기', rewardPresetKey: 'SNACK'),
        RecentReward(rewardText: '20분 산책하기', rewardPresetKey: 'WALK'),
        RecentReward(rewardText: '거실에서 저녁먹기', rewardPresetKey: 'CUSTOM'),
        RecentReward(rewardText: '다섯째는 안 보인다', rewardPresetKey: 'PLAY'),
      ];

      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.byType(RewardChip), findsNWidgets(4));
      expect(find.text('다섯째는 안 보인다'), findsNothing);

      await tester.tap(find.text('젤리 4개 먹기'));
      await settle(tester);
      expect(ctaEnabled(tester), isTrue);
      // 고른 문구가 입력칸에 들어간다 — 거기서 바로 고칠 수 있어야 한다
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '젤리 4개 먹기',
      );
    });

    testWidgets('칩에는 이모지를 붙이지 않는다 — 시안 칩은 글자뿐이다', (tester) async {
      repo.recents = const [
        RecentReward(rewardText: '젤리 먹기', rewardPresetKey: 'SNACK'),
      ];
      await tester.pumpWidget(wrap());
      await settle(tester);

      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(RewardChip),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(texts, ['젤리 먹기']);
    });

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

  group('글꼴 2.0 (E6)', () {
    // 넘침은 flutter_test_config 가 실패로 만든다 — 뜨기만 하면 통과다.
    testWidgets('최근 보상 넷에 적은 뒤에도 넘치지 않는다', (tester) async {
      repo.recents = const [
        RecentReward(rewardText: '인형놀이 20분', rewardPresetKey: 'CUSTOM'),
        RecentReward(rewardText: '젤리 4개 먹기', rewardPresetKey: 'CUSTOM'),
        RecentReward(rewardText: '20분 산책하기', rewardPresetKey: 'CUSTOM'),
        RecentReward(rewardText: '거실에서 저녁먹기', rewardPresetKey: 'CUSTOM'),
      ];
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
            testStorageOverride(nickname: '하늘이'),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      // 글자가 커지면 칩이 스크롤 아래로 내려간다 — 끌어올려 누른다.
      await tester.ensureVisible(find.text('젤리 4개 먹기'));
      await settle(tester);
      await tester.tap(find.text('젤리 4개 먹기'));
      await settle(tester);

      expect(find.text('나중에 할게요'), findsOneWidget);
      expect(ctaEnabled(tester), isTrue);
    });
  });
}

class _PushCounter extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route);
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
