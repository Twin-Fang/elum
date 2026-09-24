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
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/line_breaks.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

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

      // 디자인이 없어 개발에서 정한 문구다 (#380 결정 3). 이유 · 어떤 것 · 안 해도
      // 된다는 것 세 줄 — 전문 용어 없이, 당사자는 `이룸이`로 부른다.
      expect(whyMessageText(), findsOneWidget);
      expect(RewardSetupScreen.whyMessage.split('\n'), hasLength(3));
      for (final banned in ['강화', '아이', '아동', '행동중재']) {
        expect(RewardSetupScreen.whyMessage, isNot(contains(banned)));
      }
      expect(RewardSetupScreen.whyMessage, contains('이룸이'));
    });
  });

  // #393 S4 — 360 폭 기본 글꼴에서 `이룸이 / 가`처럼 낱말 가운데서 줄이 바뀌었다.
  // 공지 팝업(#390)의 낱말 단위 줄바꿈을 이 팝업에만 건다(앱 전체 규칙은 그대로).
  for (final width in const [360.0, 393.0]) {
    testWidgets('도움말 팝업이 폭 $width 에서 띄어쓰기에서만 줄을 바꾼다 (#393 S4)', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(wrap());
      await settle(tester);

      await tester.tap(find.text('보상이 왜 필요한가요?'));
      await settle(tester);

      expectBreaksOnlyAtSpaces(tester, whyMessageText());
      // 화면 낭독기는 끊지 말라는 표시 없이 원문을 읽는다
      expect(
        tester.widget<Text>(whyMessageText()).semanticsLabel,
        RewardSetupScreen.whyMessage,
      );
    });
  }

  group('나중에 할게요 — 보상은 선택이다', () {
    testWidgets('누르면 보상 없이 질문 준비 로딩으로 간다 (E2 · #380 결정 1)', (tester) async {
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
    Future<ProviderContainer> pumpFromReview(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: Routes.routineReview,
        routes: [
          GoRoute(
            path: Routes.routineReview,
            builder: (context, state) => const Scaffold(body: Text('카드 검토')),
          ),
          GoRoute(
            path: Routes.routineReward,
            builder: (context, state) =>
                RewardSetupScreen(fromReview: state.extra == true),
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
            builder: (context, child) =>
                MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.text('카드 검토')),
      );
      container.read(routineFlowProvider.notifier).loadExisting(
        const Routine(
          id: 'r1',
          status: 'PENDING_REVIEW',
          rewardText: '젤리 2개',
          rewardPresetKey: 'SNACK',
        ),
      );
      router.push(Routes.routineReward, extra: true);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));
      return container;
    }

    testWidgets('나중에 할게요는 정해 둔 보상을 지우지 않고 돌아간다', (tester) async {
      final container = await pumpFromReview(tester);
      // 고치러 왔으니 지금 값이 채워져 있다
      expect(find.text('젤리 2개'), findsOneWidget);

      await tester.tap(find.text('나중에 할게요'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('카드 검토'), findsOneWidget);
      expect(repo.rewardUpdates, 0, reason: '서버의 보상을 건드렸다');
      final flow = container.read(routineFlowProvider);
      expect(flow.routine?.rewardText, '젤리 2개');
      expect(flow.routine?.rewardPresetKey, 'SNACK');
    });

    testWidgets('다음은 고친 보상을 저장하고 돌아간다', (tester) async {
      final container = await pumpFromReview(tester);
      await tester.enterText(find.byType(TextField), '공원 가기');
      await settle(tester);

      await tester.tap(find.text('다음'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('카드 검토'), findsOneWidget);
      expect(repo.rewardUpdates, 1);
      expect(container.read(routineFlowProvider).routine?.rewardText, '공원 가기');
    });
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

  group('큰 글꼴에서 글자가 잘리지 않는다 (#380 실기기 A)', () {
    // 실기기 1.3 에서 `나중에 할게요` 아래가 잘렸다(2.0 에서 절반). 자리를 16 으로
    // 못 박은 상자 안에서 글자만 커져, 넘친 것이 아니라 **잘려** 경고도 안 났다.
    // 그래서 넘침 검사로는 못 잡는다 — 그려진 높이가 글자 높이만큼 되는지 잰다.
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('글꼴 $scale — 나중에 할게요 · 도움말이 온전히 그려진다', (tester) async {
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
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
            ),
          ),
        );
        await settle(tester);

        for (final label in const ['나중에 할게요', '보상이 왜 필요한가요?']) {
          final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
          final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(needed - 0.5),
            reason: '$label — 글자 높이 $needed 인데 ${paragraph.size.height} 만 그려진다',
          );
          // 잘라 주는 조상이 글자보다 작으면 글자 크기는 맞아도 가려진다.
          final rect = tester.getRect(find.text(label));
          for (final clip in tester.renderObjectList<RenderBox>(
            find.ancestor(of: find.text(label), matching: find.byType(ClipRect)),
          )) {
            final box = clip.localToGlobal(Offset.zero) & clip.size;
            expect(box.top, lessThanOrEqualTo(rect.top + 0.5), reason: label);
            expect(box.bottom, greaterThanOrEqualTo(rect.bottom - 0.5), reason: label);
          }
          // 화면 밖으로 밀려나지도 않는다.
          expect(rect.bottom, lessThanOrEqualTo(852));
        }
      });
    }
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
    String stepId,
    String description,
  ) async =>
      (routine: routine, failure: null);

  @override
  Future<List<Routine>> getTodayRoutines() async => const [];
}
