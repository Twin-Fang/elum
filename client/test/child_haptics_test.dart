import 'package:elum/core/haptics/child_haptics.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/child/presentation/routine_done_screen.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/link/presentation/elumi_settings_screen.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

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

  group('진동 패턴 규격', () {
    test('패턴과 세기 길이가 같고, 쉬는 자리는 세기 0 이다', () {
      for (final kind in ChildHapticKind.values) {
        expect(kind.intensities.length, kind.pattern.length, reason: kind.name);
        for (var i = 0; i < kind.pattern.length; i++) {
          final resting = i.isEven; // 짝수 자리는 쉬는 시간
          expect(kind.intensities[i] == 0, resting, reason: '${kind.name}[$i]');
          expect(kind.intensities[i], inInclusiveRange(0, 255));
        }
      }
    });

    test('가장 긴 패턴도 0.3초 안에 끝난다', () {
      for (final kind in ChildHapticKind.values) {
        final total = kind.pattern.fold<int>(0, (a, b) => a + b);
        expect(total, lessThanOrEqualTo(300), reason: kind.name);
      }
    });

    test('완료는 점점 세지고 강하게 끝난다', () {
      final loud = ChildHapticKind.complete.intensities.where((v) => v > 0);
      expect(loud.toList(), [...loud]..sort());
      expect(loud.last, 255);
    });

    test('체크 해제가 가장 약하다', () {
      int peak(ChildHapticKind k) =>
          k.intensities.reduce((a, b) => a > b ? a : b);
      for (final other in [
        ChildHapticKind.check,
        ChildHapticKind.star,
        ChildHapticKind.complete,
      ]) {
        expect(peak(ChildHapticKind.uncheck), lessThan(peak(other)));
      }
    });
  });

  group('ChildHaptics', () {
    test('꺼져 있으면 울리지 않는다', () async {
      final driver = _RecordingDriver();
      final haptics = ChildHaptics(driver: driver, isOn: () => false);
      await haptics.play(ChildHapticKind.check);
      expect(driver.played, isEmpty);
    });

    test('진동기가 실패해도 밖으로 던지지 않는다', () async {
      final haptics = ChildHaptics(
        driver: _RecordingDriver(throwOnPlay: true),
        isOn: () => true,
      );
      await expectLater(haptics.play(ChildHapticKind.complete), completes);
    });
  });

  group('저장 값', () {
    test('저장된 적이 없으면 켜짐이다', () {
      expect(InMemoryStorage().isChildHapticOn, isTrue);
    });

    test('clearAll 이 지우지 않는다 — 계정이 아니라 휴대폰에 속한다', () async {
      final storage = InMemoryStorage();
      await storage.setChildHapticOn(false);
      await storage.clearAll();
      expect(storage.isChildHapticOn, isFalse);
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

    Future<void> closeReward(WidgetTester tester) async {
      await tester.tap(find.byType(ElumButton));
      await settle(tester);
    }

    setUp(() {
      driver = _RecordingDriver();
      storage = InMemoryStorage(onboardingCompleted: true, elumiDevice: true);
    });

    testWidgets('카드를 체크하면 체크, 별 순서로 울린다', (tester) async {
      await pumpDetail(tester);
      expect(driver.played, isEmpty, reason: '들어오기만 해서는 울리지 않는다');

      await tapCheck(tester);

      expect(driver.played, [ChildHapticKind.check, ChildHapticKind.star]);
    });

    testWidgets('체크를 해제하면 해제 진동만 울린다', (tester) async {
      await pumpDetail(tester);
      await tapCheck(tester);
      await closeReward(tester);
      driver.played.clear();

      final pager = tester.widget<PageView>(find.byType(PageView));
      pager.controller!.jumpToPage(0);
      await tester.pump();
      await tapCheck(tester);

      expect(driver.played, [ChildHapticKind.uncheck]);
    });

    testWidgets('마지막 카드를 끝내면 체크, 별, 완료 순서로 울린다', (tester) async {
      await pumpDetail(tester);
      await tapCheck(tester);
      await closeReward(tester);
      driver.played.clear();

      await tapCheck(tester);
      // 완료 진동은 별 화면을 닫고 일과완료 화면으로 넘어가는 순간에 울린다
      await closeReward(tester);

      expect(driver.played, [
        ChildHapticKind.check,
        ChildHapticKind.star,
        ChildHapticKind.complete,
      ]);
    });

    testWidgets('스위치를 끄면 체크해도 울리지 않고 화면은 그대로 진행된다', (tester) async {
      storage = InMemoryStorage(
        onboardingCompleted: true,
        elumiDevice: true,
        childHapticOn: false,
      );
      await pumpDetail(tester);

      await tapCheck(tester);

      expect(driver.played, isEmpty);
      expect(
        find.byType(RewardScreen),
        findsOneWidget,
        reason: '진동과 상관없이 별 화면이 뜬다',
      );
    });

    testWidgets('진동기가 실패해도 별 화면까지 진행된다', (tester) async {
      driver = _RecordingDriver(throwOnPlay: true);
      await pumpDetail(tester);

      await tapCheck(tester);

      expect(find.byType(RewardScreen), findsOneWidget);
    });
  });

  group('이룸이 설정의 스위치', () {
    testWidgets('누르면 꺼지고 저장되며, 다시 누르면 켜지며 한 번 울린다', (tester) async {
      final driver = _RecordingDriver();
      final storage = InMemoryStorage(elumiDevice: true);
      final router = GoRouter(
        initialLocation: Routes.childSettings,
        routes: [
          GoRoute(
            path: Routes.childSettings,
            builder: (context, state) => const ElumiSettingsScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
            hapticDriverProvider.overrideWithValue(driver),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) =>
                MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.text('카드 체크 진동'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(storage.isChildHapticOn, isFalse);
      expect(driver.played, isEmpty, reason: '끌 때는 울리지 않는다');

      await tester.tap(find.text('카드 체크 진동'));
      await tester.pumpAndSettle();
      expect(storage.isChildHapticOn, isTrue);
      expect(driver.played, [
        ChildHapticKind.check,
      ], reason: '켤 때 느낌을 한 번 알려준다');
    });
  });
}
