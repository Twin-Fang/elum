import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/data/routine_library_api.dart';
import 'package:elum/features/guardian/presentation/routine_manage_screen.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/stub_routine_repository.dart';
import 'helpers/test_storage.dart';

/// 일과관리 칸 (#805).
///
/// 깨지면: 만든 일과가 안 보이거나, 실패가 빈 목록으로 숨거나, 오늘 이미 보낸 일과를 또 보내거나,
/// 남이 만든 일과의 이름을 바꾸는 메뉴가 열린다.
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

  Future<void> pump(
    WidgetTester tester, {
    Attempt<List<Routine>>? library,
    List<Routine> today = const [],
  }) async {
    api = _FakeLibraryApi(library ?? Attempt.ok([routine('a', '아침 준비하기')]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(StubRoutineRepository()),
          routineLibraryApiProvider.overrideWithValue(api),
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
      library: Attempt.ok([
        routine('a', '아침 준비하기'),
        routine('b', '학교 가는 날'),
      ]),
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
    await pump(
      tester,
      today: [routine('today-copy', '아침 준비하기', source: 'a')],
    );
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

  test('서버 sourceRoutineId 를 읽고, 비어 있으면 원본(null)으로 본다', () {
    expect(
      Routine.fromJson({'id': 'x', 'sourceRoutineId': 'origin'}).sourceRoutineId,
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
    return Attempt.ok(Routine(id: 'copy-$routineId', sourceRoutineId: routineId));
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
