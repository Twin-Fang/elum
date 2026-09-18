import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_flow_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 일과를 만들다 나갈 때 확인 (이슈 #242).
///
/// **카드 생성은 AI 호출이라 30초 넘게 걸린다.** 잘못 눌러 날리면 그 시간을
/// 다시 쓴다. 그런데 잃을 것이 없을 때 묻는 팝업이 가장 성가시므로, 묻는
/// 조건도 함께 고정한다.
void main() {
  useFigmaViewport();

  Widget wrap({required bool confirmExit}) {
    final router = GoRouter(
      initialLocation: '/flow',
      routes: [
        GoRoute(
          path: '/before',
          builder: (context, state) => const Scaffold(body: Text('앞 화면')),
          routes: [
            GoRoute(
              path: 'flow',
              builder: (context, state) => RoutineFlowScaffold(
                confirmExit: confirmExit,
                onBack: () => context.pop(),
                child: const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/flow',
          builder: (context, state) => RoutineFlowScaffold(
            confirmExit: confirmExit,
            onBack: () => context.pop(),
            child: const SizedBox.shrink(),
          ),
        ),
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
    await tester.pumpWidget(wrap(confirmExit: true));
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);

    expect(find.text('만들던 일과가 사라져요'), findsOneWidget);
    expect(find.text('계속 만들기'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
    // 아직 나가지 않았다
    expect(find.text('보호자 홈'), findsNothing);
  });

  testWidgets('계속 만들기를 누르면 화면에 남는다', (tester) async {
    await tester.pumpWidget(wrap(confirmExit: true));
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);
    await tester.tap(find.text('계속 만들기'));
    await settle(tester);

    expect(find.text('보호자 홈'), findsNothing);
    expect(find.byType(RoutineFlowScaffold), findsOneWidget);
  });

  testWidgets('나가기를 누르면 홈으로 간다', (tester) async {
    await tester.pumpWidget(wrap(confirmExit: true));
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);
    await tester.tap(find.text('나가기'));
    await settle(tester);

    expect(find.text('보호자 홈'), findsOneWidget);
  });

  testWidgets('잃을 것이 없으면 묻지 않는다', (tester) async {
    await tester.pumpWidget(wrap(confirmExit: false));
    await settle(tester);

    await tester.tap(find.byType(GestureDetector).last);
    await settle(tester);

    // 물어볼 것이 없는데 묻는 팝업이 가장 성가시다
    expect(find.text('만들던 일과가 사라져요'), findsNothing);
    expect(find.text('보호자 홈'), findsOneWidget);
  });

  test('warn과 danger는 다른 색이다 (이슈 #242)', () {
    const colors = AppColors.light;

    // 아동도 보는 화면이라 붉은 경고를 함부로 쓰지 않는다.
    // `danger`는 되돌릴 수 없는 파괴(회원탈퇴)에만 쓴다.
    expect(colors.warn, isNot(colors.danger));
    expect(colors.warnText, colors.surface);
  });
}
