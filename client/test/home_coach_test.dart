
import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/coach_mark_overlay.dart';
import 'package:elum/core/widgets/coach_mark_parts.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/svg_finder.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';


void main() {
  useFigmaViewport();

  late _FakeRepo repo;
  late InMemoryStorage storage;
  late GoRouter router;

  Routine routine(String id, String title, {bool? createdByMe}) => Routine(
    id: id,
    title: title,
    status: 'CONFIRMED',
    createdByMe: createdByMe,
    steps: [ActionCard(id: '$id-1', stepOrder: 1, description: '첫 단계')],
  );

  Widget wrap({
    List<Routine> today = const [],
    InMemoryStorage? store,
    bool todayFails = false,
  }) {
    repo = _FakeRepo(today: today, todayFails: todayFails);
    storage =
        store ??
        InMemoryStorage(
          onboardingCompleted: true,
          nickname: '하늘이',
          homeCoachSeen: false,
        );

    router = GoRouter(
      initialLocation: Routes.guardian,
      routes: [
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const GuardianHomeScreen(),
        ),
        GoRoute(
          path: Routes.guardianSettings,
          builder: (context, state) => const Scaffold(body: Text('설정 화면')),
        ),
        GoRoute(
          path: Routes.routineInput,
          builder: (context, state) => const Scaffold(body: Text('일과 입력')),
        ),
        GoRoute(
          path: Routes.child,
          builder: (context, state) => const Scaffold(body: Text('이룸이 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        routineRepositoryProvider.overrideWithValue(repo),
        memberProvider.overrideWith(
          (ref) async => const Member(nickname: '하늘이'),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  /// 목록을 받아 오고, 코치마크가 막을 올리는 연출까지 흘려보낸다.
  Future<void> open(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 홈이 맨 앞에서 잠시 가만히 있어야 시작한다(1.2초)
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 700));
    // 애니메이션은 시작한 프레임에서는 0이다. 한 프레임 더 흘려야 끝까지 간다.
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// 한 번 누르고 단계 이동 연출이 끝나길 기다린다.
  Future<void> tapAnywhere(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 760));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
  }

  Finder message(String part) => find.textContaining(part, findRichText: true);
  final overlay = find.byType(CoachMarkOverlay);

  CoachDots dots(WidgetTester tester) =>
      tester.widget<CoachDots>(find.byType(CoachDots));

  group('보여지는 조건', () {
    testWidgets('처음 들어오면 1단계가 뜬다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));

      expect(overlay, findsOneWidget);
      expect(message('수행할'), findsOneWidget);
      expect(dots(tester).count, 3);
      expect(dots(tester).index, 0);
    });



    testWidgets('다른 화면이 홈 위에 있으면 뜨지 않고, 걷히면 시작한다', (tester) async {
      await tester.pumpWidget(wrap(today: [routine('a', '손 씻기')]));
      // 홈이 맨 위가 아닌 채로 목록이 도착한다
      router.push(Routes.guardianSettings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('설정 화면'), findsOneWidget);
      expect(overlay, findsNothing);

      // 팝업이 걷혀도 홈은 다시 그려지지 않는다. 그래도 곧 알아채고 시작해야 한다.
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(overlay, findsOneWidget);
      expect(message('수행할'), findsOneWidget);
    });



  });

  group('단계 이동', () {
    testWidgets('누를 때마다 1 → 2 → 3 으로 가고 마지막에서 닫힌다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      expect(message('수행할'), findsOneWidget);

      await tapAnywhere(tester);
      expect(message('스와이프'), findsOneWidget);
      expect(dots(tester).index, 1);

      await tapAnywhere(tester);
      expect(message('이룸이모드'), findsOneWidget);
      expect(dots(tester).index, 2);

      await tapAnywhere(tester);
      expect(overlay, findsNothing);
    });


    testWidgets('X를 누르면 어느 단계에서나 닫힌다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));

      await tester.tap(svgWithAsset(AppAssets.coachClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(overlay, findsNothing);
    });



  });

  group('기억', () {
    testWidgets('끝까지 보면 본 것으로 남고 다시 뜨지 않는다', (tester) async {
      await open(tester, wrap());
      await tapAnywhere(tester);
      await tapAnywhere(tester);

      expect(overlay, findsNothing);
      expect(storage.isHomeCoachSeen, isTrue);
    });


    testWidgets('저장하지 못해도 앱은 계속 되고, 같은 실행에서 다시 뜨지 않는다', (tester) async {
      await open(tester, wrap(store: _WriteFailingStorage()));
      await tapAnywhere(tester);
      await tapAnywhere(tester);
      expect(overlay, findsNothing);

      // 홈을 떠났다 돌아와도 같은 실행에서는 다시 띄우지 않는다
      router.go(Routes.child);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      router.go(Routes.guardian);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 700));

      expect(overlay, findsNothing);
      expect(find.byType(GuardianHomeScreen), findsOneWidget);
    });

  });




  group('접근성 · 큰 글자 · 동작 줄이기', () {
    testWidgets('글자를 크게 키워도 말풍선이 화면 안에 있다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      const screen = Rect.fromLTWH(0, 0, 393, 852);
      for (var i = 0; i < 3; i++) {
        final text = tester.getRect(message(['수행할', '스와이프', '이룸이모드'][i]));
        expect(
          screen.contains(text.topLeft) && screen.contains(text.bottomRight),
          isTrue,
          reason: '${i + 1}단계 글이 화면 밖으로 나갔다: $text',
        );
        if (i < 2) await tapAnywhere(tester);
      }
    });


  });

}



/// 저장을 못 하는 저장소 — 디스크가 가득 찼을 때.
class _WriteFailingStorage extends InMemoryStorage {
  _WriteFailingStorage()
    : super(onboardingCompleted: true, nickname: '하늘이', homeCoachSeen: false);

  @override
  Future<void> setHomeCoachSeen(bool v) async => throw StateError('저장 실패');
}


class _FakeRepo with FakeRewardApi implements RoutineRepository {
  _FakeRepo({required this.today, this.todayFails = false});

  final List<Routine> today;
  final bool todayFails;

  @override
  Future<List<Routine>> getMyRoutines() async => today;

  @override
  Future<List<Routine>> getTodayRoutines() async {
    if (todayFails) throw Exception('서버에 닿지 못했어요');
    return today;
  }

  @override
  Future<List<Routine>> getPastRoutines() async => const [];

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
    String stepId, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
}
