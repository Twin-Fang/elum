import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_storage.dart';

/// `secured by ELUM AI DLP` 배지는 **어느 화면에도 나오지 않는다**.
///
/// 원래는 카드확인(262:5124)만 시안에 배지가 없어 그 화면만 껐었다(이슈 #79 후속).
/// 지금은 DLP를 비활성화해 둔 상태라, 보호받고 있다고 적어 두면 사실이 아니게 된다.
/// 화면 전체에서 걷어냈고 이 테스트가 되살아나는 것을 막는다.
void main() {
  const badgeText = 'secured by ELUM AI DLP';

  const cards = [
    ActionCard(id: 'c1', description: '옷을 입어요', stepOrder: 1),
    ActionCard(id: 'c2', description: '신발을 신어요', stepOrder: 2),
  ];

  /// 카드확인 화면을 [steps]로 띄운다.
  ///
  /// `routineFlowProvider`는 NotifierProvider라 override로 초기 상태를 넣을 수
  /// 없다. 대신 컨테이너를 만들어 notifier 상태를 세팅하고 그대로 주입한다.
  /// TTS는 플랫폼 채널을 타므로 fake로 바꿔 끼운다.
  Widget wrapReview(WidgetTester tester, List<ActionCard> steps) {
    final container = ProviderContainer(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        speechServiceProvider.overrideWithValue(_SilentSpeech()),
      ],
    );
    addTearDown(container.dispose);

    container.read(routineFlowProvider.notifier).state = RoutineFlowState(
      routine: Routine(id: 'r1', title: '학교에 가요', steps: steps),
    );

    final router = GoRouter(
      initialLocation: Routes.routineReview,
      routes: [
        GoRoute(
          path: Routes.routineReview,
          builder: (context, state) => const CardReviewScreen(),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('홈')),
        ),
      ],
    );

    return UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  Widget wrapLoading() {
    final router = GoRouter(
      initialLocation: '/loading',
      routes: [
        GoRoute(
          path: '/loading',
          builder: (context, state) =>
              const RoutineLoadingScreen(kind: RoutineLoadingKind.generate),
        ),
        GoRoute(
          path: Routes.routineReview,
          builder: (context, state) => const Scaffold(body: Text('카드 확인')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride(onboardingCompleted: true)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// 배경 애니메이션이 무한 반복하므로 pumpAndSettle을 쓸 수 없다
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  testWidgets('카드확인 화면엔 DLP 배지가 없다', (tester) async {
    await tester.pumpWidget(wrapReview(tester, cards));
    await settle(tester);

    // 카드가 실제로 떠 있는지 함께 확인해 오탐(화면이 안 그려져서 통과)을 막는다
    expect(find.text('카드 2개를 만들었어요'), findsOneWidget);
    expect(find.text(badgeText), findsNothing);
  });

  testWidgets('카드가 0장인 빈 상태에서도 배지가 없다', (tester) async {
    await tester.pumpWidget(wrapReview(tester, const []));
    await settle(tester);

    expect(find.text(badgeText), findsNothing);
  });

  testWidgets('로딩 화면에도 배지가 없다', (tester) async {
    // 예전엔 이 화면만 배지를 남겼다. DLP를 끈 지금은 여기도 없어야 한다.
    await tester.pumpWidget(wrapLoading());
    await settle(tester);

    // 화면이 실제로 떠 있는지 먼저 본다 — 안 떠도 findsNothing은 통과한다
    expect(find.byType(RoutineLoadingScreen), findsOneWidget);
    expect(find.text(badgeText), findsNothing);

    // 로딩이 끝나 화면이 넘어가며 pending 타이머가 남지 않게 마저 흘려보낸다
    final total = RoutineLoadingKind.generate.stages
        .map((s) => s.hold)
        .fold(Duration.zero, (a, b) => a + b);
    await tester.pump(total);
    await settle(tester);
  });
}

/// 소리를 내지 않는 fake. 카드확인 화면이 initState에서 잡아가지만
/// 배지 테스트에선 재생이 필요 없다.
class _SilentSpeech implements SpeechService {
  @override
  Future<bool> speak(String text) async => true;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
