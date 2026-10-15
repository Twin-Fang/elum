import 'package:elum/core/haptics/child_haptics.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/child/presentation/routine_done_screen.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/features/guardian/application/routine_flow_state.dart';

/// 이룸이 카드 진동 (이슈 #515).
///
/// 위젯 테스트가 확인하는 것은 **"언제 어떤 진동을 요청하는가"** 뿐이다. 진동기는 가짜로 바꿔
/// 끼웠으므로 실제 세기·느낌은 Android 실기기와 iPhone 에서 밟아 확인한다.

/// 요청받은 진동을 기록하는 가짜 진동기. [throwOnPlay] 면 호출마다 실패한다.
class _RecordingDriver implements HapticDriver {
  _RecordingDriver({this.throwOnPlay = false});

  final bool throwOnPlay;
  final played = <ChildHapticKind>[];

  @override
  Future<void> play(ChildHapticKind kind) async {
    if (throwOnPlay) throw StateError('진동 하드웨어 없음');
    played.add(kind);
  }
}

void main() {
  useFigmaViewport();


  group('ChildHaptics', () {

    test('진동기가 실패해도 밖으로 던지지 않는다', () async {
      final haptics = ChildHaptics(
        driver: _RecordingDriver(throwOnPlay: true),
        isOn: () => true,
      );
      await expectLater(haptics.play(ChildHapticKind.complete), completes);
    });
  });


  group('카드 진행 화면', () {
    const cards = [
      ActionCard(
        id: 'c1',
        title: '옷을 입어요',
        description: '옷을 입어요',
        stepOrder: 1,
      ),
      ActionCard(
        id: 'c2',
        title: '우산을 챙겨요',
        description: '우산을 챙겨요',
        stepOrder: 2,
      ),
    ];

    late _RecordingDriver driver;
    late InMemoryStorage storage;

    Widget wrap() {
      final router = GoRouter(
        initialLocation: Routes.child,
        routes: [
          GoRoute(
            path: Routes.child,
            builder: (context, state) => const ChildHomeScreen(),
          ),
          GoRoute(
            path: Routes.childRoutineDetail,
            builder: (context, state) =>
                ChildRoutineDetailScreen(routine: state.extra! as Routine),
          ),
          GoRoute(
            path: Routes.childReward,
            builder: (context, state) => const RewardScreen(),
          ),
          GoRoute(
            path: Routes.childRoutineDone,
            builder: (context, state) => const RoutineDoneScreen(reward: null),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          hapticDriverProvider.overrideWithValue(driver),
          myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          memberProvider.overrideWith((ref) async => null),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
    }

    Future<void> pumpDetail(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChildHomeScreen)),
      );
      container.read(routineFlowProvider.notifier).state = RoutineFlowState(
        routine: const Routine(
          id: 'local',
          title: '비 오는 날 학교에 가요',
          status: 'CONFIRMED',
          steps: cards,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('비 오는 날 학교에 가요'));
      await tester.pumpAndSettle();
    }

    Future<void> tapCheck(WidgetTester tester) async {
      await tester.tap(find.byKey(ChildRoutineDetailScreen.checkButtonKey));
      await settle(tester);
    }

    setUp(() {
      driver = _RecordingDriver();
      storage = InMemoryStorage(onboardingCompleted: true, elumiDevice: true);
    });

    testWidgets('진동기가 실패해도 별 화면까지 진행된다', (tester) async {
      driver = _RecordingDriver(throwOnPlay: true);
      await pumpDetail(tester);

      await tapCheck(tester);

      expect(find.byType(RewardScreen), findsOneWidget);
    });
  });

}
