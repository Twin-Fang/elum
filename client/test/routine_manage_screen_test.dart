import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/library_entries.dart';
import 'package:elum/features/guardian/application/routine_group_controller.dart';
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
  }) async {
    api = _FakeLibraryApi(library ?? Attempt.ok([routine('a', '아침 준비하기')]));
    groupApi = _FakeGroupApi(groups);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
            home: const RoutineManageScreen(),
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
class _FakeLibraryApi implements RoutineLibraryApi {
  _FakeLibraryApi(this.library);

  final Attempt<List<Routine>> library;
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
