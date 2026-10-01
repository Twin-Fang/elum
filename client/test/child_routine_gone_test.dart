import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/data/step_progress_repository.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';

/// 이룸이가 하던 일과가 **사라졌다** — 그 일과를 만든 보호자가 이룸이에서 나갔다 (#362 · E11).
///
/// 서버는 나가는 보호자의 일과를 지운다. 이룸이 휴대폰의 다음 요청은 404 다. 이때 오류 화면을
/// 띄우면 이룸이는 무엇을 잘못했는지 모른다 — **조용히 홈으로 돌아가 목록을 다시 받는다.**
void main() {
  useFigmaViewport();

  const c1 = ActionCard(id: 'c1', title: '옷을 입어요', description: '옷을 입어요', stepOrder: 1);
  const routine = Routine(
    id: 'r1',
    title: '비 오는 날 학교에 가요',
    status: 'CONFIRMED',
    steps: [c1],
  );

  group('서버 응답을 갈래로 나눈다', () {
    Future<SyncOutcome> sync(Object body) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = FakeAdapter({'PUT /api/routines/r1/progress': body});
      return StepProgressRepository(dio: dio)
          .syncProgress(routineId: 'r1', completedStepIds: {'c1'});
    }

    test('404 는 일과가 사라진 것이다', () async {
      expect(
        await sync(const FakeHttpError(404, errorCode: 'ROUTINE_NOT_FOUND')),
        SyncOutcome.gone,
      );
    });

    test('400·403·409 는 이 상태를 거부한 것이다 — 기록을 버리고 서버 값으로 돌아간다', () async {
      for (final status in [400, 403, 409]) {
        expect(await sync(FakeHttpError(status)), SyncOutcome.rejected, reason: '$status');
      }
    });

    test('서버 오류·오프라인은 일시 장애다 — 기록을 지키고 다시 보낸다', () async {
      expect(await sync(const FakeHttpError(500)), SyncOutcome.unreachable);
      expect(await sync(const FakeOffline()), SyncOutcome.unreachable);
    });
  });

  group('일과가 사라지면', () {
    late ProviderContainer container;
    var todayFetches = 0;

    setUp(() {
      todayFetches = 0;
      container = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true)),
          stepProgressRepositoryProvider.overrideWithValue(_GoneRepo()),
          todayRoutinesProvider.overrideWith((ref) async {
            todayFetches++;
            return const <Routine>[];
          }),
          pastRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        ],
      );
      addTearDown(container.dispose);
      container.listen(todayRoutinesProvider, (_, _) {});
    });

    Future<void> drain() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('기록을 버리고 사라졌다고 표시하고 목록을 다시 받는다', () async {
      final notifier = container.read(childRoutineProvider.notifier);
      await drain();
      final before = todayFetches;

      notifier.toggle(routine: routine, card: c1);
      await drain();

      final state = container.read(childRoutineProvider);
      expect(state.gone, {'r1'});
      expect(state.progress.containsKey('r1'), isFalse);
      expect(state.pending, isEmpty);
      expect(todayFetches, greaterThan(before));
    });

    test('다른 일과를 시작하면 표시가 지워진다 — 같은 id 를 다시 받아도 홈으로 튕기지 않는다', () async {
      final notifier = container.read(childRoutineProvider.notifier);
      notifier.toggle(routine: routine, card: c1);
      await drain();

      notifier.reset();

      expect(container.read(childRoutineProvider).gone, isEmpty);
    });
  });

  group('일과 상세 화면', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: Routes.child,
        routes: [
          GoRoute(path: Routes.child, builder: (_, _) => const Scaffold(body: Text('이룸이 홈'))),
          GoRoute(
            path: Routes.childRoutineDetail,
            builder: (_, state) => ChildRoutineDetailScreen(routine: state.extra! as Routine),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true)),
            stepProgressRepositoryProvider.overrideWithValue(_GoneRepo()),
            todayRoutinesProvider.overrideWith((ref) async => const <Routine>[routine]),
            pastRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
            myRoutinesProvider.overrideWith((ref) async => const <Routine>[routine]),
            memberProvider.overrideWith((ref) async => null),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('이룸이 홈'))).push(Routes.childRoutineDetail, extra: routine);
      await tester.pumpAndSettle();
      expect(find.byType(ChildRoutineDetailScreen), findsOneWidget);
      return ProviderScope.containerOf(tester.element(find.byType(ChildRoutineDetailScreen)));
    }

    testWidgets('보고 있던 일과가 사라지면 오류 화면 없이 이룸이 홈으로 돌아간다', (tester) async {
      final container = await pump(tester);

      container.read(childRoutineProvider.notifier).toggle(routine: routine, card: c1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('이룸이 홈'), findsOneWidget);
      expect(find.byType(ChildRoutineDetailScreen), findsNothing);
      // 오류 팝업을 띄우지 않았다
      expect(find.text('확인'), findsNothing);
    });

    testWidgets('다른 일과가 사라진 것은 지금 보는 일과와 상관없다', (tester) async {
      final container = await pump(tester);
      const other = Routine(id: 'r2', status: 'CONFIRMED', steps: [c1]);

      container.read(childRoutineProvider.notifier).toggle(routine: other, card: c1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byType(ChildRoutineDetailScreen), findsOneWidget);
    });
  });
}

/// 서버가 "그 일과는 없다"고 답하는 가짜. 어느 일과든 404 다.
class _GoneRepo extends StepProgressRepository {
  _GoneRepo() : super(dio: Dio());

  @override
  Future<SyncOutcome> syncProgress({
    required String routineId,
    required Set<String> completedStepIds,
  }) async => SyncOutcome.gone;
}
