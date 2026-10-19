import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/coach_mark_overlay.dart';
import 'package:elum/features/guardian/application/library_entries.dart';
import 'package:elum/features/guardian/application/routine_group_controller.dart';
import 'package:elum/features/guardian/application/routine_manage_coach_notifier.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/data/routine_group_api.dart';
import 'package:elum/features/guardian/data/routine_library_api.dart';
import 'package:elum/features/guardian/domain/routine_group.dart';
import 'package:elum/features/guardian/presentation/routine_manage_screen.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/stub_routine_repository.dart';
import 'helpers/test_storage.dart';

/// 일과관리 칸 (#805) + 일과 묶음 (#807).
/// 깨지면: 만든 일과가 안 보임 · 실패가 빈 목록으로 숨음 · 두 번 보내기 · 남의 일과 이름 바꾸기 · 묶음 안 일과 중복 · 끌어도 안 묶임 · 1개 남은 묶음 안 풀림
void main() {
  useFigmaViewport();

  Routine routine(String id, String title, {bool? mine, String? source}) =>
      Routine(
        id: id,
        title: title,
        status: 'CONFIRMED',
        createdByMe: mine,
        sourceRoutineId: source,
        steps: const [ActionCard(id: 'c1', stepOrder: 1, description: '단계')],
      );

  late _FakeLibraryApi api;
  late _FakeGroupApi groupApi;

  Future<void> pump(
    WidgetTester tester, {
    Attempt<List<Routine>>? library,
    List<Routine> today = const [],
    List<RoutineGroup> groups = const [],
    InMemoryStorage? storage,
    bool isOnTopOfAnotherRoute = false,
  }) async {
    api = _FakeLibraryApi(library ?? Attempt.ok([routine('a', '아침 준비하기')]));
    groupApi = _FakeGroupApi(groups);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (storage != null)
            localStorageProvider.overrideWithValue(storage)
          else
            testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(StubRoutineRepository()),
          routineLibraryApiProvider.overrideWithValue(api),
          routineGroupApiProvider.overrideWithValue(groupApi),
          todayRoutinesProvider.overrideWith((ref) async => today),
          memberProvider.overrideWith((ref) async => null),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            // 뒤로가기 시험: 아래에 다른 화면이 깔려 있어야 pop 이 화면을 닫으려 든다
            home: isOnTopOfAnotherRoute
                ? const _PushesManageScreen()
                : const RoutineManageScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('원본 일과를 격자에 보여 준다', (tester) async {
    await pump(
      tester,
      library: Attempt.ok([routine('a', '아침 준비하기'), routine('b', '학교 가는 날')]),
    );
    expect(find.text('아침 준비하기'), findsOneWidget);
    expect(find.text('학교 가는 날'), findsOneWidget);
    expect(find.text('일과 만들기'), findsOneWidget);
  });

  testWidgets('목록을 못 받으면 빈 목록이 아니라 다시 시도와 에러 코드를 보인다', (tester) async {
    await pump(
      tester,
      library: const Attempt.failed(AppFailure(fault: NetworkFault.offline)),
    );
    expect(find.text('아직 만든 일과가 없어요'), findsNothing);
    // 제보받을 때 쓰는 에러 코드와 다시 시도 버튼
    expect(find.textContaining('E-'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('원본이 없으면 빈 상태 안내가 보인다', (tester) async {
    await pump(tester, library: const Attempt.ok([]));
    expect(find.text('아직 만든 일과가 없어요'), findsOneWidget);
  });

  testWidgets('오늘 이미 보낸 원본은 서버에 다시 보내지 않고 알린다', (tester) async {
    await pump(tester, today: [routine('today-copy', '아침 준비하기', source: 'a')]);
    expect(find.bySemanticsLabel(RegExp('오늘 보냈어요')), findsOneWidget);

    await tester.longPress(find.text('아침 준비하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 보내기'));
    await tester.pumpAndSettle();

    expect(api.sentIds, isEmpty);
    expect(find.text('오늘 이미 보낸 일과예요'), findsOneWidget);
  });

  testWidgets('보내지 않은 원본은 빠른 메뉴로 오늘 보낸다', (tester) async {
    await pump(tester);

    await tester.longPress(find.text('아침 준비하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 보내기'));
    await tester.pumpAndSettle();

    expect(api.sentIds, ['a']);
  });

  testWidgets('남이 만든 원본의 빠른 메뉴에는 이름 바꾸기·지우기가 없다', (tester) async {
    await pump(
      tester,
      library: Attempt.ok([routine('a', '아침 준비하기', mine: false)]),
    );

    await tester.longPress(find.text('아침 준비하기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 보내기'), findsOneWidget);
    expect(find.text('복사하기'), findsOneWidget);
    expect(find.text('이름 바꾸기'), findsNothing);
    expect(find.text('지우기'), findsNothing);
  });

  testWidgets('묶음 안 일과는 낱개 칸으로 또 나오지 않고 묶음 칸 하나로 보인다', (tester) async {
    await pump(
      tester,
      library: Attempt.ok([
        routine('a', '아침 준비하기'),
        routine('b', '양치하기'),
        routine('c', '학교 가는 날'),
      ]),
      groups: const [
        RoutineGroup(id: 'g1', name: '아침', routineIds: ['b', 'a']),
      ],
    );
    expect(find.text('아침'), findsOneWidget);
    expect(find.text('아침 준비하기'), findsNothing);
    expect(find.text('학교 가는 날'), findsOneWidget);
  });

  testWidgets('낱개를 끌어 다른 일과 위에 놓으면 놓인 자리 일과가 앞인 새 묶음이 된다', (tester) async {
    await pump(
      tester,
      library: Attempt.ok([routine('a', '아침 준비하기'), routine('b', '양치하기')]),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('아침 준비하기')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('양치하기')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(groupApi.created, [
      ['b', 'a'],
    ]);
    // 끌어 놓았으면 메뉴는 열리지 않는다
    expect(find.text('오늘 보내기'), findsNothing);
  });

  group('처음 사용 안내 코치마크 (#832)', () {
    InMemoryStorage unseenStorage() => InMemoryStorage(
      onboardingCompleted: true,
      nickname: '하늘이',
      isManageCoachSeen: false,
      isGroupCoachSeen: false,
    );

    // 안내가 뜨기까지: 목록 도착 > 맨 앞에서 가만히 1.2초 > 막이 내려앉는 연출
    Future<void> waitForCoach(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> tapThrough(WidgetTester tester) async {
      await tester.tapAt(const Offset(200, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
    }

    Finder message(String part) =>
        find.textContaining(part, findRichText: true);
    final overlay = find.byType(CoachMarkOverlay);

    testWidgets('일과 1개: 누르기 > 길게 누르기 > 보낸 뒤 순서로 뜨고, 끝내면 다시 안 뜬다', (tester) async {
      final storage = unseenStorage();
      await pump(tester, storage: storage);
      await waitForCoach(tester);

      expect(overlay, findsOneWidget);
      expect(message('카드를 볼 수 있어요'), findsOneWidget);
      await tapThrough(tester);
      expect(message('메뉴가 열려요'), findsOneWidget);
      await tapThrough(tester);
      expect(message('붙어요'), findsOneWidget);
      await tapThrough(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(overlay, findsNothing);
      expect(storage.isManageCoachSeen, isTrue);
      // 일과가 1개면 끌어다 놓을 대상이 없어 묶음 단계는 보여 주지 않았다
      expect(storage.isGroupCoachSeen, isFalse);
    });

    testWidgets('안내가 도는 동안 서버에는 아무것도 보내지 않는다', (tester) async {
      await pump(tester, storage: unseenStorage());
      await waitForCoach(tester);
      await tapThrough(tester);
      await tapThrough(tester);
      await tapThrough(tester);
      expect(api.sentIds, isEmpty);
    });

    testWidgets('이미 봤으면 뜨지 않는다', (tester) async {
      await pump(tester);
      await waitForCoach(tester);
      expect(overlay, findsNothing);
    });

    testWidgets('목록을 못 받았거나 0건이면 뜨지 않는다', (tester) async {
      await pump(
        tester,
        library: const Attempt.failed(AppFailure(fault: NetworkFault.offline)),
        storage: unseenStorage(),
      );
      await waitForCoach(tester);
      expect(overlay, findsNothing);

      await pump(tester, library: const Attempt.ok([]), storage: unseenStorage());
      await waitForCoach(tester);
      expect(overlay, findsNothing);
    });

    testWidgets('일과 2개 + 묶음 없음이면 기본 3단계 뒤에 묶음 단계가 이어진다', (tester) async {
      final storage = unseenStorage();
      await pump(
        tester,
        library: Attempt.ok([routine('a', '아침 준비하기'), routine('b', '양치하기')]),
        storage: storage,
      );
      await waitForCoach(tester);
      await tapThrough(tester);
      await tapThrough(tester);
      await tapThrough(tester);
      expect(message('꾹 눌러'), findsOneWidget);
      await tapThrough(tester);
      expect(message('묶을 수 있어요'), findsOneWidget);
      await tapThrough(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(storage.isGroupCoachSeen, isTrue);
    });

    testWidgets('일과가 전부 묶음 안에 있으면(낱개 칸 없음) 뜨지 않는다', (tester) async {
      await pump(
        tester,
        library: Attempt.ok([routine('a', '아침 준비하기'), routine('b', '양치하기')]),
        groups: const [
          RoutineGroup(id: 'g1', name: '아침', routineIds: ['b', 'a']),
        ],
        storage: unseenStorage(),
      );
      await waitForCoach(tester);
      expect(overlay, findsNothing);
    });

    testWidgets('첫 항목이 묶음이어도 낱개 일과 칸이 있으면 뜬다', (tester) async {
      await pump(
        tester,
        library: Attempt.ok([
          routine('a', '아침 준비하기'),
          routine('b', '양치하기'),
          routine('c', '학교 가는 날'),
        ]),
        groups: const [
          RoutineGroup(id: 'g1', name: '아침', routineIds: ['b', 'a']),
        ],
        storage: unseenStorage(),
      );
      await waitForCoach(tester);
      expect(overlay, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('다시 보기를 요청하면 이미 봤어도 안내가 뜬다', (tester) async {
      await pump(tester);
      await waitForCoach(tester);
      expect(overlay, findsNothing);

      ProviderScope.containerOf(tester.element(find.byType(RoutineManageScreen)))
          .read(routineManageCoachProvider.notifier)
          .requestReplay();
      await tester.pump();
      await waitForCoach(tester);

      expect(overlay, findsOneWidget);
    });

    testWidgets('뒤로가기로 닫아도 본 것으로 남는다', (tester) async {
      final storage = unseenStorage();
      await pump(tester, storage: storage, isOnTopOfAnotherRoute: true);
      await waitForCoach(tester);
      expect(overlay, findsOneWidget);

      await tester.binding.handlePopRoute();
      // 사라지는 연출은 상태가 바뀐 다음 프레임부터 돈다
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(overlay, findsNothing);
      expect(storage.isManageCoachSeen, isTrue);
    });

    testWidgets('도는 중에 목록이 비어 가리킬 칸이 사라져도 예외 없이 끝난다', (tester) async {
      await pump(tester, storage: unseenStorage());
      await waitForCoach(tester);
      expect(overlay, findsOneWidget);

      api.library = const Attempt.ok([]);
      ProviderScope.containerOf(
        tester.element(find.byType(RoutineManageScreen)),
      ).invalidate(routineLibraryProvider);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('태블릿 폭 · 큰 글자에서도 예외 없이 뜬다', (tester) async {
      tester.view
        ..physicalSize = const Size(1024, 768)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pump(tester, storage: unseenStorage());
      await waitForCoach(tester);
      expect(overlay, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('묶음에서 빼서 하나만 남으면 구성을 바꾸지 않고 묶음을 푼다', () async {
    final groupApi = _FakeGroupApi(const []);
    final container = ProviderContainer(
      overrides: [
        routineGroupApiProvider.overrideWithValue(groupApi),
        routineRepositoryProvider.overrideWithValue(StubRoutineRepository()),
      ],
    );
    addTearDown(container.dispose);
    const group = RoutineGroup(id: 'g1', name: '아침', routineIds: ['a', 'b']);

    final removal = await container
        .read(routineGroupControllerProvider)
        .remove(group, 'a');

    expect(removal.outcome, RemoveOutcome.ungrouped);
    expect(groupApi.ungroupedIds, ['g1']);
    expect(groupApi.replaced, isEmpty);
  });

  test('다른 기기에서 지워 2개 미만이 보이는 묶음은 낱개로 펼친다', () {
    final entries = composeLibraryEntries(
      [routine('a', '아침 준비하기'), routine('c', '학교 가는 날')],
      const [
        RoutineGroup(id: 'g1', name: '아침', routineIds: ['a', 'gone']),
      ],
    );
    expect(entries.whereType<LibraryGroupEntry>(), isEmpty);
    expect(entries.whereType<LibraryRoutineEntry>().length, 2);
  });

  test('서버 sourceRoutineId 를 읽고, 비어 있으면 원본(null)으로 본다', () {
    expect(
      Routine.fromJson({
        'id': 'x',
        'sourceRoutineId': 'origin',
      }).sourceRoutineId,
      'origin',
    );
    expect(Routine.fromJson({'id': 'x'}).sourceRoutineId, isNull);
    expect(
      Routine.fromJson({'id': 'x', 'sourceRoutineId': ''}).sourceRoutineId,
      isNull,
    );
  });
}

/// 서버 없이 일과관리 호출을 받는 가짜. 보낸 원본 id 를 기록한다
/// 일과관리 화면을 다른 화면 위에 올려 둔다 (뒤로가기가 화면을 닫으려 드는 상황)
class _PushesManageScreen extends StatefulWidget {
  const _PushesManageScreen();

  @override
  State<_PushesManageScreen> createState() => _PushesManageScreenState();
}

class _PushesManageScreenState extends State<_PushesManageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RoutineManageScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

class _FakeLibraryApi implements RoutineLibraryApi {
  _FakeLibraryApi(this.library);

  Attempt<List<Routine>> library;
  final sentIds = <String>[];

  @override
  Future<Attempt<List<Routine>>> fetchLibrary() async => library;

  @override
  Future<Attempt<Routine>> sendToday(String routineId) async {
    sentIds.add(routineId);
    return Attempt.ok(
      Routine(id: 'copy-$routineId', sourceRoutineId: routineId),
    );
  }

  @override
  Future<Attempt<Routine>> copy(String routineId) async =>
      Attempt.ok(Routine(id: 'copy-of-$routineId'));

  @override
  Future<Attempt<Routine>> rename(String routineId, String title) async =>
      Attempt.ok(Routine(id: routineId, title: title));

  @override
  Future<AppFailure?> removeFromLibrary(String routineId) async => null;
}

/// 서버 없이 묶음 호출을 받는 가짜. 만들기·구성 바꾸기·풀기를 기록한다
class _FakeGroupApi implements RoutineGroupApi {
  _FakeGroupApi(this.groups);

  final List<RoutineGroup> groups;
  final created = <List<String>>[];
  final replaced = <List<String>>[];
  final ungroupedIds = <String>[];

  RoutineGroup _group(String id, List<String> routineIds) =>
      RoutineGroup(id: id, name: '묶음', routineIds: routineIds);

  @override
  Future<Attempt<List<RoutineGroup>>> fetchGroups() async => Attempt.ok(groups);

  @override
  Future<Attempt<RoutineGroup>> create(
    String name,
    List<String> routineIds,
  ) async {
    created.add(routineIds);
    return Attempt.ok(_group('new', routineIds));
  }

  @override
  Future<Attempt<RoutineGroup>> rename(String groupId, String name) async =>
      Attempt.ok(_group(groupId, const []));

  @override
  Future<Attempt<RoutineGroup>> replaceRoutines(
    String groupId,
    List<String> routineIds,
  ) async {
    replaced.add(routineIds);
    return Attempt.ok(_group(groupId, routineIds));
  }

  @override
  Future<Attempt<RoutineGroup>> copy(String groupId) async =>
      Attempt.ok(_group('copy', const []));

  @override
  Future<AppFailure?> ungroup(String groupId) async {
    ungroupedIds.add(groupId);
    return null;
  }

  @override
  Future<Attempt<List<Routine>>> sendToday(String groupId) async =>
      const Attempt.ok([]);
}
