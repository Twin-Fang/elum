import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/today_routine_section.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 만들다 나간 일과가 **임시저장에 바로 보이는가** (이슈 #387).
///
/// 카드를 만드는 순간 서버는 일과를 `PENDING_REVIEW`(= 임시저장)로 저장한다.
/// 그런데 앱은 그 뒤 목록을 다시 받지 않아, 방금 만든 일과가 앱을 다시 켜기
/// 전까지 임시저장에 없었다. 거꾸로 흐름에 남은 그 일과가 보호자 홈 **오늘 일과**
/// 맨 앞에 붙어 있었다(실기기 결함 C) — 아직 이룸이에게 보내지 않은 것이다.
Routine _draft(String id, {String status = 'PENDING_REVIEW'}) => Routine(
  id: id,
  title: '비 오는 날 등교',
  status: status,
  steps: const [
    ActionCard(id: 'c1', stepOrder: 1, description: '우산을 챙겨요'),
  ],
);

void main() {
  useFigmaViewport();

  group('만든 뒤 목록을 다시 받는다', () {
    test('카드를 만들면 전체 목록(임시저장이 여기서 거른다)을 다시 받는다', () async {
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // 앞서 한 번 받아 둔 목록 — 새 일과가 없다
      expect(await container.read(draftRoutinesProvider.future), isEmpty);
      final before = repo.listCalls;

      final notifier = container.read(routineFlowProvider.notifier)
        ..setRawInput('내일 비 오는 날 등교');
      repo.serverList = [_draft('r1')];
      await notifier.generateCards();

      // 방금 만든 것이 임시저장에 있다 — 앱을 다시 켜지 않아도. 목록은 한 번
      // 받으면 계속 살아 있으므로(keepAlive) 무효화하지 않으면 여기서 옛 것(빈 목록)이 온다.
      final drafts = await container.read(draftRoutinesProvider.future);
      expect(repo.listCalls, greaterThan(before));
      expect(drafts.map((r) => r.id), ['r1']);
    });

    test('만들다 실패하면 받을 것이 없다 — 다시 받지 않는다', () async {
      final repo = _Repo()..failCreate = true;
      final container = ProviderContainer(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(draftRoutinesProvider.future);
      final before = repo.listCalls;

      final notifier = container.read(routineFlowProvider.notifier)
        ..setRawInput('내일 비 오는 날 등교');
      await notifier.generateCards();

      expect(container.read(routineFlowProvider).step, RoutineFlowStep.error);
      await container.read(draftRoutinesProvider.future);
      expect(repo.listCalls, before);
    });
  });

  group('임시저장 일과는 오늘 일과가 아니다 (결함 C · #353)', () {
    ProviderContainer containerWith(Routine inFlow) {
      final container = ProviderContainer(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        ],
      );
      container.read(routineFlowProvider.notifier).loadExisting(inFlow);
      return container;
    }

    test('흐름을 나가기로 끝내 남은 임시저장 일과를 오늘 일과 앞에 붙이지 않는다', () async {
      final container = containerWith(_draft('r1'));
      addTearDown(container.dispose);
      await container.read(todayRoutinesProvider.future);

      expect(container.read(homeRoutinesProvider), isEmpty);
    });

    test('방금 저장한(CONFIRMED) 일과는 목록이 오기 전에도 바로 보인다', () async {
      final container = containerWith(_draft('r2', status: 'CONFIRMED'));
      addTearDown(container.dispose);
      await container.read(todayRoutinesProvider.future);

      expect(container.read(homeRoutinesProvider).map((r) => r.id), ['r2']);
    });
  });

  group('임시저장 화면', () {
    testWidgets('들어올 때마다 새로 받는다 — 다른 곳에서 만든 것도 보인다', (tester) async {
      final repo = _Repo();
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                // 앱의 다른 화면이 먼저 목록을 받아 둔 상태를 만든다
                ref.watch(myRoutinesProvider);
                return const Scaffold(body: Text('시작'));
              },
            ),
          ),
          GoRoute(
            path: Routes.guardianDrafts,
            builder: (context, state) => const DraftRoutinesScreen(),
          ),
        ],
      );
      await tester.pumpWidget(_app(repo, router));
      await tester.pumpAndSettle();
      expect(repo.listCalls, 1);

      repo.serverList = [_draft('r1')];
      router.push(Routes.guardianDrafts);
      await tester.pumpAndSettle();

      expect(repo.listCalls, 2);
      expect(find.text('비 오는 날 등교'), findsOneWidget);
    });

    testWidgets('카드를 만든 뒤 흐름 아래 가려진 홈으로 돌아와도 터지지 않는다', (tester) async {
      // 카드가 만들어질 때 홈은 흐름 아래에 **가려져 멈춰 있다**(Riverpod 3 이 가려진
      // 화면의 구독을 쉰다). 그때 홈이 보는 목록(오늘)을 무효화하면, 돌아오는 순간
      // 멈췄던 파생 목록이 빌드 도중에 다시 그리라고 요청해 디버그에서
      // `markNeedsBuild() called during build` 가 난다 — 실제로 한 번 그렇게 만들었다.
      // 그래서 만든 직후에는 임시저장이 보는 전체 목록만 다시 받는다.
      final repo = _Repo();
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final n = ref.watch(homeRoutinesProvider).length;
                return Scaffold(body: Text('홈 $n'));
              },
            ),
          ),
          GoRoute(
            path: '/flow',
            builder: (context, state) => const Scaffold(body: Text('흐름')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
            routineRepositoryProvider.overrideWithValue(repo),
            todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) =>
                MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/flow');
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('흐름')));
      container.read(routineFlowProvider.notifier).setRawInput('내일 등교');
      await container.read(routineFlowProvider.notifier).generateCards();
      await tester.pump();

      router.pop();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 방금 만든 것은 임시저장이라 홈 오늘 일과에 없다 (결함 C)
      expect(find.text('홈 0'), findsOneWidget);
    });

    testWidgets('이어서 만들다 다시 나가도 같은 일과가 한 번만 있다 (T7)', (tester) async {
      final repo = _Repo()..serverList = [_draft('r1')];
      final router = GoRouter(
        initialLocation: Routes.guardianDrafts,
        routes: [
          GoRoute(
            path: Routes.guardianDrafts,
            builder: (context, state) => const DraftRoutinesScreen(),
          ),
          GoRoute(
            path: Routes.routineReview,
            builder: (context, state) => const CardReviewScreen(),
          ),
        ],
      );
      await tester.pumpWidget(_app(repo, router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('비 오는 날 등교'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CardReviewScreen), findsOneWidget);

      // 카드 확인에서 뒤로 — 임시저장에 남는다고 말한다 (T1·T2)
      await tester.tap(find.bySemanticsLabel('뒤로 가기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('임시저장에 두고 나갈까요?'), findsOneWidget);
      expect(find.text('설정의 임시저장에서\n이어서 만들 수 있어요'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(DraftRoutinesScreen), findsOneWidget);
      // 나간 뒤 목록을 다시 받았다 — 카드 확인에서 고친 것이 목록에 반영된다
      expect(repo.listCalls, greaterThanOrEqualTo(3));
      expect(find.text('비 오는 날 등교'), findsOneWidget);
      // 새로 만들지 않았다 — AI 도 서버 생성도 부르지 않는다.
      expect(repo.createCalls, 0);
    });
  });
}

Widget _app(_Repo repo, GoRouter router) => ProviderScope(
  overrides: [
    testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
    routineRepositoryProvider.overrideWithValue(repo),
  ],
  child: ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (context, _) =>
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ),
);

/// 서버 목록을 바꿔 끼우며 몇 번 받았는지 센다.
class _Repo with FakeRewardApi implements RoutineRepository {
  List<Routine> serverList = const [];
  var listCalls = 0;
  var createCalls = 0;
  var failCreate = false;

  @override
  Future<List<Routine>> getMyRoutines() async {
    listCalls++;
    return serverList;
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
    if (failCreate) throw StateError('생성 실패');
    return _draft('r1');
  }

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async =>
      RoutineSuggestion.fallback;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
