import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 카드를 체크하고 별 화면을 닫으면 다음 카드로 넘어간다 (이슈 #293).
///
/// **"다음"은 순서가 아니라 아직 안 한 카드 중 가장 앞이다.** 이 화면의 목적이
/// "지금 할 일 하나를 보여주는 것"이라, 건너뛴 카드를 두고 앞으로만 가면
/// 빠뜨린 것이 영영 남는다.
void main() {
  useFigmaViewport();

  const cards = [
    ActionCard(
      id: 'c1',
      title: '옷을 입어요',
      description: '학교에 갈 옷을 차례대로 입어요',
      stepOrder: 1,
    ),
    ActionCard(
      id: 'c2',
      title: '우산을 챙겨요',
      description: '현관에서 우산을 챙겨요',
      stepOrder: 2,
    ),
    ActionCard(
      id: 'c3',
      title: '신발을 신어요',
      description: '현관에서 신발을 신어요',
      stepOrder: 3,
    ),
  ];

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.child,
      routes: [
        GoRoute(
          path: Routes.child,
          builder: (context, state) => const ChildHomeScreen(),
        ),
        GoRoute(
          path: Routes.childRoutineDetail,
          builder: (context, state) =>
              ChildRoutineDetailScreen(routine: state.extra! as Routine),
        ),
        GoRoute(
          path: Routes.childStars,
          builder: (context, state) => const Scaffold(body: Text('별 화면')),
        ),
        GoRoute(
          path: Routes.childReward,
          builder: (context, state) => const RewardScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        // 실서버를 타지 않는다. 일과는 아래에서 직접 주입한다.
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        memberProvider.overrideWith((ref) async => null),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  /// 홈에 일과를 주입하고 상세 화면까지 들어간다.
  ///
  /// id를 `local`로 둔다 — 서버에 없는 일과라 동기화를 타지 않고 전환 규칙만 본다.
  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChildHomeScreen)),
    );
    container.read(routineFlowProvider.notifier).state = const RoutineFlowState(
      routine: Routine(
        id: 'local',
        title: '비 오는 날 학교에 가요',
        status: 'CONFIRMED',
        steps: cards,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('비 오는 날 학교에 가요'));
    await tester.pumpAndSettle();
    expect(find.byType(ChildRoutineDetailScreen), findsOneWidget);
  }

  PageController controllerOf(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;

  /// 지금 보고 있는 카드의 순번(0부터).
  int currentPage(WidgetTester tester) =>
      (controllerOf(tester).page ?? 0).round();

  Future<void> goToCard(WidgetTester tester, int index) async {
    controllerOf(tester).jumpToPage(index);
    await tester.pump();
  }

  /// 별 화면은 반짝임이 계속 돌아 `pumpAndSettle`이 끝나지 않는다. 컨페티도 마찬가지다.
  /// 그래서 시간을 직접 밀어 준다 — 기존 보상 화면 테스트와 같은 방식이다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // 체크 뒤 기다림 + 화면 전환
    await tester.pump(const Duration(seconds: 2)); // 카드 이동 애니메이션
  }

  Future<void> tapCheck(WidgetTester tester) async {
    await tester.tap(find.byKey(ChildRoutineDetailScreen.checkButtonKey));
    await settle(tester);
  }

  /// 별 화면의 버튼을 눌러 닫는다. 버튼 문구는 캐릭터마다 달라 타입으로 찾는다.
  Future<void> closeReward(WidgetTester tester) async {
    expect(find.byType(RewardScreen), findsOneWidget);
    await tester.tap(find.byType(ElumButton));
    await settle(tester);
  }

  testWidgets('별 화면을 닫으면 다음 카드로 넘어간다', (tester) async {
    await pumpDetail(tester);
    expect(currentPage(tester), 0);

    await tapCheck(tester);
    await closeReward(tester);

    expect(currentPage(tester), 1, reason: '첫 카드를 끝냈으니 둘째 카드가 보여야 한다');
  });

  testWidgets('건너뛰고 체크해도 안 한 카드 중 가장 앞으로 간다', (tester) async {
    await pumpDetail(tester);
    await goToCard(tester, 2);

    await tapCheck(tester);
    await closeReward(tester);

    expect(
      currentPage(tester),
      0,
      reason: '셋째를 먼저 했어도 빠뜨린 첫째로 되짚어야 한다',
    );
  });

  testWidgets('안 한 카드가 없으면 그대로 머문다', (tester) async {
    await pumpDetail(tester);

    // 첫째 → 둘째까지 끝내고 마지막 하나만 남긴다
    await tapCheck(tester);
    await closeReward(tester);
    await tapCheck(tester);
    await closeReward(tester);
    expect(currentPage(tester), 2);

    await tapCheck(tester);
    await closeReward(tester);

    expect(currentPage(tester), 2, reason: '남은 카드가 없으면 움직이지 않는다');
  });

  testWidgets('체크를 해제할 때는 넘어가지 않는다', (tester) async {
    await pumpDetail(tester);
    await tapCheck(tester);
    await closeReward(tester);

    // 첫 카드로 돌아가 체크를 해제한다
    await goToCard(tester, 0);
    await tapCheck(tester);

    expect(find.byType(RewardScreen), findsNothing, reason: '해제에는 별이 뜨지 않는다');
    expect(currentPage(tester), 0, reason: '되돌리는 동작에서 화면이 움직이면 안 된다');
  });

  testWidgets('이미 보상한 카드를 다시 체크해도 넘어가지 않는다', (tester) async {
    await pumpDetail(tester);
    await tapCheck(tester);
    await closeReward(tester);

    await goToCard(tester, 0);
    await tapCheck(tester); // 해제
    await tapCheck(tester); // 재체크 — 보상 이력이 남아 별이 뜨지 않는다

    expect(find.byType(RewardScreen), findsNothing);
    expect(
      currentPage(tester),
      0,
      reason: '연출 없이 화면만 바뀌면 무엇이 일어났는지 알 수 없다',
    );
  });
}
