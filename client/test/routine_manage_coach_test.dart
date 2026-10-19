import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/application/routine_manage_coach_notifier.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/coach_mark_overlay.dart';
import 'package:elum/core/widgets/coach_mark_step.dart';
import 'package:elum/features/guardian/presentation/widgets/coach_demo_layers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 일과관리 코치마크: 언제 뜨고, 무엇을 보여주고, 닫으면 다시 안 뜨는가 (이슈 #832)
void main() {
  useFigmaViewport();

  ProviderContainer containerWith(InMemoryStorage storage) {
    final container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  InMemoryStorage unseenStorage() =>
      InMemoryStorage(isManageCoachSeen: false, isGroupCoachSeen: false);

  group('시작 조건', () {
    test('일과가 0개면 뜨지 않는다 — 가리킬 칸이 없다', () {
      final container = containerWith(unseenStorage());
      final isStarted = container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 0,
            groupCount: 0,
            hasFirstRoutineTile: false,
          );
      expect(isStarted, isFalse);
      expect(container.read(routineManageCoachProvider).isActive, isFalse);
    });

    test('일과 1개면 기본 3단계만 뜬다', () {
      final container = containerWith(unseenStorage());
      container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 1,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(container.read(routineManageCoachProvider).steps, [
        RoutineManageCoachStep.tapRoutine,
        RoutineManageCoachStep.longPressRoutine,
        RoutineManageCoachStep.sentBadge,
      ]);
    });

    test('일과 2개 + 묶음 0개면 묶음 2단계가 이어 붙는다', () {
      final container = containerWith(unseenStorage());
      container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 2,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(container.read(routineManageCoachProvider).steps, [
        RoutineManageCoachStep.tapRoutine,
        RoutineManageCoachStep.longPressRoutine,
        RoutineManageCoachStep.sentBadge,
        RoutineManageCoachStep.dragToGroup,
        RoutineManageCoachStep.createGroup,
      ]);
    });

    test('이미 묶음이 있으면 묶음 단계는 없다', () {
      final container = containerWith(unseenStorage());
      container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 2,
            groupCount: 1,
            hasFirstRoutineTile: true,
          );
      expect(
        container.read(routineManageCoachProvider).steps,
        isNot(contains(RoutineManageCoachStep.dragToGroup)),
      );
    });

    test('첫 칸이 묶음뿐이면(일과 칸 없음) 뜨지 않는다', () {
      final container = containerWith(unseenStorage());
      final isStarted = container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 2,
            groupCount: 1,
            hasFirstRoutineTile: false,
          );
      expect(isStarted, isFalse);
    });

    test('기본 3단계를 이미 봤으면 묶음 단계만 뜬다', () {
      final container = containerWith(
        InMemoryStorage(isManageCoachSeen: true, isGroupCoachSeen: false),
      );
      container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 2,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(container.read(routineManageCoachProvider).steps, [
        RoutineManageCoachStep.dragToGroup,
        RoutineManageCoachStep.createGroup,
      ]);
    });

    test('둘 다 봤으면 뜨지 않는다', () {
      final container = containerWith(InMemoryStorage());
      final isStarted = container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 3,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(isStarted, isFalse);
    });

    test('저장소를 못 읽으면 봤다고 치고 뜨지 않는다', () {
      final container = containerWith(_UnreadableStorage());
      final isStarted = container
          .read(routineManageCoachProvider.notifier)
          .maybeStart(
            routineCount: 1,
            groupCount: 0,
            hasFirstRoutineTile: true,
          );
      expect(isStarted, isFalse);
    });
  });

  group('진행과 닫기', () {
    test('같은 실행에서 한 번 켠 뒤에는 다시 켜지지 않는다', () async {
      final container = containerWith(unseenStorage());
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.maybeStart(
        routineCount: 1,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      await notifier.finish();
      final isStartedAgain = notifier.maybeStart(
        routineCount: 1,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      expect(isStartedAgain, isFalse);
    });

    test('next 는 순서대로 가고 마지막에서 끝나며 봤음이 저장된다', () async {
      final storage = unseenStorage();
      final container = containerWith(storage);
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.maybeStart(
        routineCount: 1,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      expect(
        container.read(routineManageCoachProvider).current,
        RoutineManageCoachStep.tapRoutine,
      );
      notifier.next();
      notifier.next();
      expect(
        container.read(routineManageCoachProvider).current,
        RoutineManageCoachStep.sentBadge,
      );
      notifier.next();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(routineManageCoachProvider).isActive, isFalse);
      expect(storage.isManageCoachSeen, isTrue);
      expect(storage.isGroupCoachSeen, isFalse, reason: '묶음 단계는 안 보여 줬다');
    });

    test('중간에 닫아도(finish) 본 것으로 남고, 묶음 단계가 있었다면 그것도 남는다', () async {
      final storage = unseenStorage();
      final container = containerWith(storage);
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.maybeStart(
        routineCount: 2,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      await notifier.finish();
      expect(storage.isManageCoachSeen, isTrue);
      expect(storage.isGroupCoachSeen, isTrue);
    });

    test('저장에 실패해도 예외 없이 끝난다', () async {
      final container = containerWith(_UnwritableStorage());
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.maybeStart(
        routineCount: 1,
        groupCount: 0,
        hasFirstRoutineTile: true,
      );
      await notifier.finish();
      expect(container.read(routineManageCoachProvider).isActive, isFalse);
    });

    test('다시 보기 요청은 표시만 해 두고, replay 로 켜면 요청이 지워진다', () {
      final container = containerWith(InMemoryStorage());
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.requestReplay();
      expect(
        container.read(routineManageCoachProvider).isReplayRequested,
        isTrue,
      );
      notifier.replay(routineCount: 1, groupCount: 0);
      expect(
        container.read(routineManageCoachProvider).isReplayRequested,
        isFalse,
      );
      expect(container.read(routineManageCoachProvider).isActive, isTrue);
    });

    test('다시 보기는 일과가 없거나 낱개 칸이 없으면 켜지 않고 요청을 지운다', () {
      final container = containerWith(InMemoryStorage());
      final notifier = container.read(routineManageCoachProvider.notifier);
      notifier.requestReplay();
      notifier.replay(routineCount: 0, groupCount: 0);
      expect(container.read(routineManageCoachProvider).isActive, isFalse);
      expect(
        container.read(routineManageCoachProvider).isReplayRequested,
        isFalse,
      );

      notifier.requestReplay();
      notifier.replay(
        routineCount: 2,
        groupCount: 1,
        hasFirstRoutineTile: false,
      );
      expect(container.read(routineManageCoachProvider).isActive, isFalse);
      expect(
        container.read(routineManageCoachProvider).isReplayRequested,
        isFalse,
      );
    });

    test('다시 보기(replay)는 봤어도 켜진다', () {
      final container = containerWith(InMemoryStorage());
      container
          .read(routineManageCoachProvider.notifier)
          .replay(routineCount: 1, groupCount: 0);
      expect(container.read(routineManageCoachProvider).isActive, isTrue);
    });
  });

  group('시범 층 (demoBuilder)', () {
    testWidgets('단계에 시범 층이 있으면 구멍 자리(대상 상자)에 맞춰 그려진다', (tester) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 100,
                    top: 200,
                    child: SizedBox(key: targetKey, width: 80, height: 80),
                  ),
                  CoachMarkOverlay(
                    steps: [
                      CoachMarkStep(
                        target: targetKey,
                        message: '안내',
                        demoBuilder: (context, targetRect) =>
                            Positioned.fromRect(
                              rect: targetRect,
                              child: const SizedBox(key: Key('demo')),
                            ),
                      ),
                    ],
                    index: 0,
                    visible: true,
                    onNext: () {},
                    onClose: () {},
                    onDismissed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // 막이 내려앉고 구멍이 대상으로 좁혀 들어오는 연출이 끝날 때까지 흘린다
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byKey(const Key('demo')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('demo'))),
        const Offset(100, 200),
      );
      expect(tester.getSize(find.byKey(const Key('demo'))), const Size(80, 80));
    });
  });

  group('시범 연출', () {
    const firstTile = Rect.fromLTWH(20, 150, 84, 90);
    const secondTile = Rect.fromLTWH(108, 150, 84, 90);
    const createButton = Rect.fromLTWH(120, 700, 150, 54);

    Future<void> pumpDemo(
      WidgetTester tester,
      Widget demo, {
      bool isMotionReduced = false,
    }) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: isMotionReduced),
              child: child!,
            ),
            home: Scaffold(body: Stack(children: [demo])),
          ),
        ),
      );
    }

    // 시범이 가리키는 문구는 실제 시트·메뉴의 문구와 같아야 한다 — 따로 적으면 어긋난다
    final demosWithKeyText = <String, (Widget Function(BuildContext), String)>{
      '누르기 시범은 상세 시트의 두 버튼을 보여 준다': (
        (context) => tapDemo(context, firstTile),
        '오늘 보내기',
      ),
      '길게 누르기 시범은 빠른 메뉴의 항목을 보여 준다': (
        (context) => longPressDemo(context, firstTile),
        '복사하기',
      ),
      '보낸 뒤 시범은 실제 토스트 문구를 보여 준다': (
        (context) => sentBadgeDemo(context, firstTile, routineTitle: '양치하기'),
        '양치하기',
      ),
    };

    demosWithKeyText.forEach((name, spec) {
      testWidgets('동작 줄이기: $name — 멈춘 마지막 장면만 그린다', (tester) async {
        await pumpDemo(
          tester,
          Builder(builder: spec.$1),
          isMotionReduced: true,
        );
        // 돌아가는 애니메이션이 없어 pumpAndSettle 이 끝난다
        await tester.pumpAndSettle();
        expect(find.textContaining(spec.$2, findRichText: true), findsWidgets);
      });
    });

    testWidgets('끌어서 묶기 시범은 두 칸 사이를 오가고 예외 없이 반복된다', (tester) async {
      await pumpDemo(
        tester,
        Builder(
          builder: (context) => dragToGroupDemo(context, firstTile, secondTile),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('버튼으로 묶기 시범은 시트를 올리지 않고 탭만 보여 준다(문구를 가리지 않는다)', (tester) async {
      await pumpDemo(
        tester,
        Builder(builder: (c) => createGroupDemo(c, createButton)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('새 묶음 만들기'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('일반 모드: 누르기 시범이 1주기 넘게 돌아도 예외가 없다', (tester) async {
      await pumpDemo(tester, Builder(builder: (c) => tapDemo(c, firstTile)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
    });
  });
}

class _UnreadableStorage extends InMemoryStorage {
  @override
  bool get isManageCoachSeen => throw StateError('읽기 실패');
}

class _UnwritableStorage extends InMemoryStorage {
  _UnwritableStorage()
    : super(isManageCoachSeen: false, isGroupCoachSeen: false);

  @override
  Future<void> setManageCoachSeen(bool isSeen) async =>
      throw StateError('쓰기 실패');
}
