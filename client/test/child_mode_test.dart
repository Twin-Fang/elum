
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/app_shake.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/features/guardian/application/routine_flow_state.dart';

/// Figma `아이_홈`(309:3548/309:3648) · `아이_보상`(309:4055 등) 정합 테스트.
void main() {
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
  ];

  Widget wrap(
    Widget screen, {
    List<ActionCard> steps = cards,
    String? pin,
    Member? member,
    bool elumiDevice = false,
  }) {
    final router = GoRouter(
      initialLocation: Routes.child,
      routes: [
        GoRoute(path: Routes.child, builder: (context, state) => screen),
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
        GoRoute(
          path: Routes.modeSwitch,
          builder: (context, state) => ModeSwitchScreen(
            target: ModeSwitchTarget.fromName(state.uri.queryParameters['to']),
          ),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(
          onboardingCompleted: true,
          pin: pin,
          elumiDevice: elumiDevice,
        ),
        // 실서버를 타지 않는다
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        memberProvider.overrideWith((ref) async => member),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  /// 승인된 일과를 주입한 뒤 화면을 띄운다.
  /// 아이 홈은 CONFIRMED 일과만 보여준다 (docs 원칙 3번).
  Future<ProviderContainer> pumpChild(
    WidgetTester tester, {
    List<ActionCard> steps = cards,
    String? pin,
    String status = 'CONFIRMED',
    Member? member,
  }) async {
    await tester.pumpWidget(
      wrap(const ChildHomeScreen(), steps: steps, pin: pin, member: member),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChildHomeScreen)),
    );
    container.read(routineFlowProvider.notifier).state = RoutineFlowState(
      routine: Routine(
        id: 'r1',
        title: '비 오는 날 학교에 가요',
        status: status,
        steps: steps,
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('아이 홈 (이슈 #69 — 일과 목록)', () {

    testWidgets('승인 전 일과는 목록에 없다', (tester) async {
      // 보호자 승인 전에는 아동에게 노출하지 않는다 (docs 원칙 3번)
      await pumpChild(tester, status: 'PENDING_REVIEW');

      expect(find.text('비 오는 날 학교에 가요'), findsNothing);
      expect(find.textContaining('일과가 없어요'), findsOneWidget);
    });

  });

  group('보상 조건', () {
    // 서버에 없는 로컬 일과 — 동기화 없이 토글 규칙만 본다.
    const local = Routine(id: 'local', status: 'CONFIRMED', steps: cards);
    final c1 = cards[0];

    test('처음 체크하면 보상을 준다', () {
      final container = ProviderContainer(overrides: [testStorageOverride()]);
      addTearDown(container.dispose);

      final notifier = container.read(childRoutineProvider.notifier);

      expect(notifier.toggle(routine: local, card: c1), isTrue);
    });

    test('해제했다 다시 체크하면 보상을 주지 않는다', () {
      // 매번 축하하면 보상이 가벼워진다
      final container = ProviderContainer(overrides: [testStorageOverride()]);
      addTearDown(container.dispose);

      final notifier = container.read(childRoutineProvider.notifier);

      expect(notifier.toggle(routine: local, card: c1), isTrue);
      expect(notifier.toggle(routine: local, card: c1), isFalse); // 해제
      expect(notifier.toggle(routine: local, card: c1), isFalse); // 재체크 — 보상 없음
    });

  });


  group('보상 별 렌더링', () {
    // 예전에 `Icon(Icons.star_rounded)`로 그려서 Figma 그라데이션 별과
    // 모양이 달랐고, 위젯 테스트에서는 아이콘 폰트가 없어 네모로 나왔다.
    // 도형은 전부 에셋이어야 한다 (client/CLAUDE.md §2).

    // 보상 화면은 852 높이를 꽉 채운다. 기본 뷰포트(800×600)로 돌리면
    // 화면이 아니라 테스트 환경 때문에 오버플로가 난다.
    useFigmaViewport();

  });


  group('아이 → 보호자 PIN 검증 (이슈 #61)', () {

    testWidgets('틀린 PIN으로는 보호자 화면에 가지 못한다', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ModeSwitchScreen(target: ModeSwitchTarget.guardian),
          pin: '1234',
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '9999');
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsNothing);
      // 틀렸다는 사실이 전달돼야 한다 (#180). 종전에는 입력만 조용히 사라져
      // 틀린 것인지 입력이 안 먹은 것인지 구분할 수 없었다.
      // 색은 여전히 쓰지 않는다 — 아동도 보는 화면이라 흔들림과 문구로만 알린다.
      expect(find.text('암호가 달라요. 다시 넣어주세요'), findsOneWidget);
      expect(find.text('암호를 입력하면 보호자 화면으로 바뀌어요'), findsNothing);
      expect(find.byType(AppShake), findsOneWidget);
    });

    testWidgets('보호자 → 아이 방향도 PIN을 요구한다', (tester) async {
      // 양방향 모두 막는다. 한쪽만 막으면 우회로가 생긴다.
      await tester.pumpWidget(
        wrap(
          const ModeSwitchScreen(target: ModeSwitchTarget.child),
          pin: '1234',
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '9999');
      await tester.pumpAndSettle();

      // 양방향 모두 같은 방식으로 알린다 (#180)
      expect(find.text('암호가 달라요. 다시 넣어주세요'), findsOneWidget);
      expect(find.byType(AppShake), findsOneWidget);
    });
  });

  group('누를 수 있는 것에 읽을 이름이 있다 (#339)', () {
    // 별 화면은 852 높이를 꽉 채운다 — 기본 뷰포트면 테스트 환경 탓에 넘친다
    useFigmaViewport();

  });

}
