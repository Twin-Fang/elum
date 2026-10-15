import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_flow_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 일과를 만들다 나갈 때 확인 (이슈 #242 · #387).
///
/// **카드 생성은 AI 호출이라 30초 넘게 걸린다.** 잘못 눌러 날리면 그 시간을
/// 다시 쓴다. 그런데 잃을 것이 없을 때 묻는 팝업이 가장 성가시므로, 묻는
/// 조건도 함께 고정한다.
///
/// **무엇을 잃는지가 시점마다 다르다 (#387).** 카드를 만들기 전에는 적은 것이
/// 정말 남지 않는다. 카드를 만든 뒤에는 서버에 임시저장으로 남는다 — 거기에
/// `사라져요`라고 쓰면 사실이 아니다.
void main() {
  useFigmaViewport();

  /// [backLeavesFlow] 면 카드 확인처럼 뒤로가 흐름을 통째로 닫는다(앱과 같은 콜백).
  Widget wrap({
    RoutineLeave? leave,
    bool backLeavesFlow = false,
    String initial = '/flow',
  }) {
    Widget flow(BuildContext context) => RoutineFlowScaffold(
      leave: leave,
      backLeavesFlow: backLeavesFlow,
      onBack: backLeavesFlow
          ? () => leaveRoutineFlow(context)
          : () => context.pop(),
      child: const SizedBox.shrink(),
    );
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/before',
          builder: (context, state) => const Scaffold(body: Text('앞 화면')),
          routes: [
            GoRoute(path: 'flow', builder: (context, state) => flow(context)),
          ],
        ),
        GoRoute(path: '/flow', builder: (context, state) => flow(context)),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride()],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// 배경(aurora)이 무한 반복해 `pumpAndSettle`을 쓸 수 없다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('홈을 누르면 확인을 먼저 묻는다', (tester) async {
    await tester.pumpWidget(wrap(leave: RoutineLeave.discard));
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);

    expect(find.text('일과 만들기를 그만둘까요?'), findsOneWidget);
    expect(find.text('지금 나가면 적은 내용은 남지 않아요'), findsOneWidget);
    expect(find.text('계속 만들기'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
    // 아직 나가지 않았다
    expect(find.text('보호자 홈'), findsNothing);
  });


  testWidgets('나가기를 누르면 홈으로 간다', (tester) async {
    await tester.pumpWidget(wrap(leave: RoutineLeave.discard));
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);
    await tester.tap(find.text('나가기'));
    await settle(tester);

    expect(find.text('보호자 홈'), findsOneWidget);
  });

  testWidgets('잃을 것이 없으면 묻지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);

    // 물어볼 것이 없는데 묻는 팝업이 가장 성가시다
    expect(find.byType(ElumDialogCard<bool>), findsNothing);
    expect(find.text('보호자 홈'), findsOneWidget);
  });
}
