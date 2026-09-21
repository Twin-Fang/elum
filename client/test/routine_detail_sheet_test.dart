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

  Widget wrap(_FakeRepo repo, {Routine value = routine, bool isPast = false}) {
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
            body: RoutineDetailSheet(routine: value, isPast: isPast),
          ),
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

  testWidgets('보상은 뱃지 + 카드로 보여준다 — 시안 짜임을 따른다 (#295)', (tester) async {
    await tester.pumpWidget(wrap(_FakeRepo()));
    await tester.pump();

    expect(find.text('유튜브 시청 20분'), findsOneWidget);
    // 시안(963:4422)은 단계와 같은 짜임으로 두고 뱃지만 다르게 한다.
    // 전에는 `다 하면`이라는 말로 대신했는데(#275) 시안이 뒤에 나와 그쪽을 따른다.
    expect(find.text('다 하면'), findsNothing);
    expect(find.text('⭐'), findsNothing, reason: '별은 이모지가 아니라 에셋이다');
  });

  testWidgets('보상을 정하지 않았으면 없다고 말해 준다 (#308)', (tester) async {
    await tester.pumpWidget(
      wrap(
        _FakeRepo(),
        value: const Routine(id: 'r2', title: '손 씻기', steps: steps),
      ),
    );
    await tester.pump();

    // 전에는 줄째 숨겼다. 그러면 보상을 넣을 수 있다는 것조차 보이지 않는다.
    // 시안(980:5174)은 빈 칸 대신 **말로** 알린다.
    expect(find.text('일과 완료 후 보상이 없어요'), findsOneWidget);
    expect(find.text('⭐'), findsNothing, reason: '별은 이모지가 아니라 에셋이다');

    // **별은 흐리게 하지 않는다.** 한때 흐리게 했는데 시안을 잘못 읽은 것이었다
    // — `980:5174`의 별은 보상이 없을 때도 선명하다 (#297).
    final dimmed = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .where((o) => o.opacity == 0.5);
    expect(dimmed, isEmpty, reason: '시안의 별은 보상이 없어도 선명하다');
  });

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

  // --- 지난 일과 (시안 980:4777 · #310) ---
  //
  // **지나간 것은 고치지 않는다.** 고쳐 봐야 어제 일과가 바뀔 뿐 오늘 할 일이
  // 생기지 않는다. 그래서 시안은 버튼을 바꾸고 순서 손잡이를 지웠다.
  group('지난 일과 시트', () {
    testWidgets('버튼이 일과 다시하기다', (tester) async {
      await tester.pumpWidget(wrap(_FakeRepo(), isPast: true));
      await tester.pumpAndSettle();

      expect(find.text('일과 다시하기'), findsOneWidget);
      expect(find.text('편집하기'), findsNothing);
    });

    testWidgets('순서를 바꾸는 손잡이가 없다', (tester) async {
      await tester.pumpWidget(wrap(_FakeRepo(), isPast: true));
      await tester.pumpAndSettle();

      expect(
        svgWithAsset(AppAssets.sheetReorderHandle),
        findsNothing,
        reason: '지나간 일과는 자리를 바꿔도 의미가 없다',
      );
    });

    testWidgets('오늘 일과에는 손잡이가 그대로 있다', (tester) async {
      await tester.pumpWidget(wrap(_FakeRepo()));
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.sheetReorderHandle), findsWidgets);
    });

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

  testWidgets('순서를 바꿔도 번호는 자리를 지킨다 (#296)', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(wrap(repo));
    await tester.pump();

    expect(find.text('옷을 골라요'), findsOneWidget);
    for (final n in ['1', '2', '3']) {
      expect(find.text(n), findsOneWidget);
    }

    await _grabAndDrag(tester, const Offset(0, 160));

    // **번호는 카드의 이름표가 아니라 몇 번째 자리인가를 뜻한다.** 옮긴 뒤에도
    // 왼쪽 줄은 1·2·3 그대로 서 있고 카드 내용만 자리를 바꾼다. 뱃지가 카드를
    // 따라다니면 내려놓는 순간 번호가 한꺼번에 다시 매겨져 헷갈린다.
    for (final n in ['1', '2', '3']) {
      expect(find.text(n), findsOneWidget, reason: '번호 $n 이 한 자리에 그대로 있다');
    }
    // 서버에는 바뀐 순서가 간다 — 화면만 그대로인 것이 아니다.
    expect(repo.lastStepIds, hasLength(3));
  });

  testWidgets('길게 누르고 있으면 줄이 떠오른다 — 움직이기 전에 잡혔음을 보여준다 (#274)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_FakeRepo()));
    await tester.pump();

    bool anyLifted() => tester
        .widgetList<Container>(find.byType(Container))
        .any(
          (c) =>
              ((c.decoration as BoxDecoration?)?.boxShadow ?? []).isNotEmpty,
        );

    expect(anyLifted(), isFalse, reason: '손대기 전에는 떠오른 줄이 없다');

    final gesture = await tester.startGesture(
      tester.getCenter(svgWithAsset(AppAssets.sheetReorderHandle).first),
    );
    // 첫 프레임은 Ticker가 시작점을 잡느라 경과가 0이다. 그 다음부터 흐른다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // 손가락을 아직 움직이지 않았는데도 떠올라 있어야 한다.
    // 예전에는 움직여야 그림자가 나타나 누르는 내내 아무 일도 없어 보였다.
    expect(anyLifted(), isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('스치듯 끌면 순서가 바뀌지 않는다 — 스크롤하다 놀라면 안 된다 (#274)', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(wrap(repo));
    await tester.pump();

    // 길게 누르지 않고 곧바로 끈다. 목록을 아래로 쓸어내리려던 손짓이다.
    await tester.drag(
      svgWithAsset(AppAssets.sheetReorderHandle).first,
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();

    // 잡지 않았으므로 아무 일도 일어나지 않는다 — 서버로도 보내지 않는다
    expect(repo.lastStepIds, isNull);
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
  Future<bool> reorderSteps(String routineId, List<String> stepIds) async {
    lastStepIds = stepIds;
    return reorderSucceeds;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} 은 이 테스트에서 쓰지 않는다');
}
