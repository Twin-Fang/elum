import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_detail_sheet.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';

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

  Widget wrap(
    _FakeRepo repo, {
    Routine value = routine,
    bool isPast = false,
    bool isFinished = false,
  }) {
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
          home: Scaffold(
            body: RoutineDetailSheet(
              routine: value,
              isPast: isPast,
              isFinished: isFinished,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('편집하기를 누르면 edit을 돌려준다 — 화면 이동은 부르는 쪽이 한다', (tester) async {
    RoutineSheetAction? result;
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

    expect(result, RoutineSheetAction.edit);
  });

  // --- 다 끝낸 오늘 일과 (#534) ---
  //
  // 이룸이 화면은 다 끝낸 일과를 다시 그리지 않는다. 보호자가 고쳐도 반영되지 않으므로
  // 편집 버튼을 막고, 숨기지 않고 글자로 이유를 보인다.
  group('다 끝낸 일과 시트', () {
  });

  // --- 지난 일과 (시안 980:4777 · #310) ---
  //
  // **지나간 것은 고치지 않는다.** 고쳐 봐야 어제 일과가 바뀔 뿐 오늘 할 일이
  // 생기지 않는다. 그래서 시안은 버튼을 바꾸고 순서 손잡이를 지웠다.
  group('지난 일과 시트', () {
    testWidgets('다시하기를 누르면 rerun을 돌려준다', (tester) async {
      RoutineSheetAction? result;
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
                      result = await RoutineDetailSheet.show(
                        context,
                        routine,
                        isPast: true,
                      );
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
      await tester.tap(find.text('일과 다시하기'));
      await tester.pumpAndSettle();

      expect(result, RoutineSheetAction.rerun);
    });
  });

  testWidgets('손잡이를 끌면 전체 순서를 서버로 보낸다 (#266)', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(wrap(repo));
    await tester.pump();

    await _grabAndDrag(tester, const Offset(0, 160));

    // 부분이 아니라 보이는 전체를 보낸다 — 부분 갱신은 두 곳에서 동시에 바꿀 때 뒤엉킨다.
    expect(repo.lastStepIds, isNotNull);
    expect(repo.lastStepIds, hasLength(3));
    expect(repo.lastStepIds, containsAll(['c1', 'c2', 'c3']));
    // 번호 칸과 카드 칸을 나눠도(#434) 끈 카드가 실제로 자리를 옮긴다.
    expect(repo.lastStepIds!.first, isNot('c1'), reason: '맨 위 카드를 아래로 옮겼다');
  });

  testWidgets('순서 저장에 실패하면 알린다 — 조용히 넘어가지 않는다 (#266)', (tester) async {
    // 화면만 바뀐 채 두면 다음에 열었을 때 바꾼 적 없는 것처럼 보인다.
    final repo = _FakeRepo(reorderSucceeds: false);
    await tester.pumpWidget(wrap(repo));
    await tester.pump();

    await _grabAndDrag(tester, const Offset(0, 160));

    expect(find.textContaining('순서를 저장하지 못했어요'), findsOneWidget);
    expect(find.textContaining('E-STEP-ORDER'), findsOneWidget);
  });

}

/// 손잡이를 **길게 눌러 잡은 뒤** 끈다.
///
/// 스치는 것만으로는 잡히지 않게 바뀌었으므로(#274) 임계 시간만큼 누르고 있어야
/// 한다. `tester.drag`은 곧바로 움직여서 이제 아무 일도 일어나지 않는다.
Future<void> _grabAndDrag(WidgetTester tester, Offset offset) async {
  final gesture = await tester.startGesture(
    tester.getCenter(svgWithAsset(AppAssets.sheetReorderHandle).first),
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
  await gesture.moveBy(offset);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

class _FakeRepo with FakeRewardApi implements RoutineRepository {
  _FakeRepo({this.reorderSucceeds = true});

  final bool reorderSucceeds;
  List<String>? lastStepIds;

  @override
  Future<AppFailure?> reorderSteps(
    String routineId,
    List<String> stepIds,
  ) async {
    lastStepIds = stepIds;
    return reorderSucceeds ? null : const AppFailure(fault: NetworkFault.app);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} 은 이 테스트에서 쓰지 않는다');
}
