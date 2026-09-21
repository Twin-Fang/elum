import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_detail_sheet.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 오늘 일과 시트 (Figma 956:4084, 이슈 #266).
void main() {
  const steps = [
    ActionCard(
      id: 'c1',
      title: '옷을 골라요',
      description: '밖에 나갈 때 입을 옷을 꺼내요',
      stepOrder: 1,
      completed: true,
    ),
    ActionCard(
      id: 'c2',
      title: '바지를 입어요',
      description: '양쪽 다리를 넣고 바지를 올려 입어요',
      stepOrder: 2,
    ),
    ActionCard(
      id: 'c3',
      title: '윗옷을 입어요',
      description: '머리와 팔을 넣어 윗옷을 입어요',
      stepOrder: 3,
    ),
  ];

  const routine = Routine(
    id: 'r1',
    title: '스스로 옷을 입어요',
    status: 'CONFIRMED',
    steps: steps,
    rewardText: '유튜브 시청 20분',
  );

  Widget wrap(_FakeRepo repo, {Routine value = routine}) {
    return ProviderScope(
      overrides: [
        offlineDioOverride(),
        testStorageOverride(onboardingCompleted: true),
        routineRepositoryProvider.overrideWithValue(repo),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: RoutineDetailSheet(routine: value)),
        ),
      ),
    );
  }

  testWidgets('제목과 단계가 번호와 함께 보인다', (tester) async {
    await tester.pumpWidget(wrap(_FakeRepo()));
    await tester.pump();

    expect(find.text('스스로 옷을 입어요'), findsOneWidget);
    expect(find.text('옷을 골라요'), findsOneWidget);
    expect(find.text('윗옷을 입어요'), findsOneWidget);
    // 번호는 1부터 붙는다
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('보상 본문은 글자만 — 별은 왼쪽 뱃지에만 있다 (#275)', (tester) async {
    await tester.pumpWidget(wrap(_FakeRepo()));
    await tester.pump();

    // 본문에도 그림을 붙이면 한 줄에 별이 두 번 나온다. 시안도 글자만 그린다.
    expect(find.text('유튜브 시청 20분'), findsOneWidget);
    expect(find.text('⭐'), findsOneWidget);
  });

  testWidgets('보상이 없으면 그 줄을 그리지 않는다 — 빈 칸은 덜 만들어진 것처럼 보인다', (tester) async {
    await tester.pumpWidget(
      wrap(
        _FakeRepo(),
        value: const Routine(id: 'r2', title: '손 씻기', steps: steps),
      ),
    );
    await tester.pump();

    expect(find.text('⭐'), findsNothing);
  });

  testWidgets('편집하기를 누르면 true를 돌려준다 — 화면 이동은 부르는 쪽이 한다', (tester) async {
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(_FakeRepo()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await RoutineDetailSheet.show(context, routine);
                  },
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('편집하기'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('손잡이를 끌면 전체 순서를 서버로 보낸다 (#266)', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(wrap(repo));
    await tester.pump();

    // 첫 줄 손잡이를 아래로 끈다. ReorderableDragStartListener라 길게 누를 필요가 없다.
    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();

    // 부분이 아니라 보이는 전체를 보낸다 — 부분 갱신은 두 곳에서 동시에 바꿀 때 뒤엉킨다.
    expect(repo.lastStepIds, isNotNull);
    expect(repo.lastStepIds, hasLength(3));
    expect(repo.lastStepIds, containsAll(['c1', 'c2', 'c3']));
  });

  testWidgets('순서 저장에 실패하면 알린다 — 조용히 넘어가지 않는다 (#266)', (tester) async {
    // 화면만 바뀐 채 두면 다음에 열었을 때 바꾼 적 없는 것처럼 보인다.
    final repo = _FakeRepo(reorderSucceeds: false);
    await tester.pumpWidget(wrap(repo));
    await tester.pump();

    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('순서를 저장하지 못했어요'), findsOneWidget);
    expect(find.textContaining('E-STEP-ORDER'), findsOneWidget);
  });
}

class _FakeRepo with FakeRewardApi implements RoutineRepository {
  _FakeRepo({this.reorderSucceeds = true});

  final bool reorderSucceeds;
  List<String>? lastStepIds;

  @override
  Future<bool> reorderSteps(String routineId, List<String> stepIds) async {
    lastStepIds = stepIds;
    return reorderSucceeds;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} 은 이 테스트에서 쓰지 않는다');
}
