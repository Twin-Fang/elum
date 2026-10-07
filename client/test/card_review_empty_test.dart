import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_error_view.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/test_storage.dart';

/// 카드가 0장일 때 막다른 길이 되지 않는다.
void main() {
  useFigmaViewport();

  testWidgets('카드 0장이면 에러 코드와 다시 만들기가 보이고, 누르면 입력으로 돌아간다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        // 네트워크는 막혀 있다 — 다시 만들기가 AI 를 부르면 여기서 실패한다
        offlineDioOverride(),
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
      ],
    );
    addTearDown(container.dispose);
    container.read(routineFlowProvider.notifier).state = const RoutineFlowState(
      routine: Routine(id: 'r1', title: '학교에 가요', steps: []),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: GoRouter(
              initialLocation: Routes.routineReview,
              routes: [
                GoRoute(
                  path: Routes.routineReview,
                  builder: (context, state) => const CardReviewScreen(),
                ),
                GoRoute(
                  path: Routes.routineInput,
                  builder: (context, state) =>
                      const Scaffold(body: Text('일과 입력')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ElumErrorView), findsOneWidget);
    expect(find.text('만들어진 카드가 없어요'), findsOneWidget);
    expect(find.text('E-CARD'), findsWidgets);

    await tester.tap(find.text('다시 만들기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('일과 입력'), findsOneWidget);
    // 흐름을 비워 옛 빈 일과가 남지 않는다
    expect(container.read(routineFlowProvider).routine, isNull);
  });
}
