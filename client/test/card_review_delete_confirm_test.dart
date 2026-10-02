import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/test_storage.dart';

/// 카드 확인의 `✕` 는 묻고 나서 지운다 (#497).
///
/// 이전에는 `✕` 가 곧바로 `removeStep` 을 불러 잘못 눌러도 되돌릴 길이 없었다.
/// 지우기 자체(목록 변화, 마지막 한 장 보호)는 `card_review_delete_test` 가 본다.
/// 여기서는 **화면이 팝업을 거치는지** 만 본다.
void main() {
  useFigmaViewport();

  const cards = [
    ActionCard(id: 'c1', stepOrder: 1, title: '옷을 입어요', description: '옷 설명'),
    ActionCard(id: 'c2', stepOrder: 2, title: '가방을 챙겨요', description: '가방 설명'),
  ];

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    List<ActionCard> steps = cards,
  }) async {
    final container = ProviderContainer(
      overrides: [
        offlineDioOverride(),
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        speechServiceProvider.overrideWithValue(_SilentSpeech()),
      ],
    );
    addTearDown(container.dispose);
    container.read(routineFlowProvider.notifier).state = RoutineFlowState(
      routine: Routine(id: 'r1', title: '학교에 가요', steps: steps),
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
                  path: Routes.guardian,
                  builder: (context, state) =>
                      const Scaffold(body: Text('보호자 홈')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  List<String> idsOf(ProviderContainer c) => [
    for (final s in c.read(routineFlowProvider).routine!.steps) s.id,
  ];

  /// `✕` — 접근성 이름으로 찾는다 (에셋 경로가 바뀌어도 이 테스트가 따라온다).
  final deleteButton = find.byWidgetPredicate(
    (w) => w is AppPressable && w.semanticLabel == '이 카드 지우기',
  );

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.tap(deleteButton.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('카드 지우기 확인 (#497)', () {
    testWidgets('✕ 를 눌러도 바로 지워지지 않고 팝업이 먼저 뜬다', (tester) async {
      final container = await pump(tester);

      await tapDelete(tester);

      expect(find.text('카드를 삭제하실건가요?'), findsOneWidget);
      expect(idsOf(container), ['c1', 'c2'], reason: '팝업만 떴고 아직 지우지 않았다');
    });

    testWidgets('삭제를 누르면 그 카드가 빠진다', (tester) async {
      final container = await pump(tester);

      await tapDelete(tester);
      await tester.tap(find.text('삭제'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('카드를 삭제하실건가요?'), findsNothing);
      expect(idsOf(container), ['c2']);
    });

    testWidgets('취소를 누르면 카드가 그대로 남는다', (tester) async {
      final container = await pump(tester);

      await tapDelete(tester);
      await tester.tap(find.text('취소'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('카드를 삭제하실건가요?'), findsNothing);
      expect(idsOf(container), ['c1', 'c2']);
    });

    testWidgets('바깥을 눌러 닫아도 카드는 그대로다', (tester) async {
      final container = await pump(tester);

      await tapDelete(tester);
      // 이 팝업은 barrierDismissible 이 꺼져 있어 바깥은 눌러도 닫히지 않는다.
      // 닫히지 않는 동안에도 카드는 지워지지 않아야 한다.
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();

      expect(idsOf(container), ['c1', 'c2']);
    });

    testWidgets('한 장만 남으면 ✕ 자체가 없다', (tester) async {
      await pump(tester, steps: [cards.first]);

      expect(deleteButton, findsNothing);
    });
  });
}

class _SilentSpeech implements SpeechService {
  @override
  Future<bool> speak(String text, {String language = 'ko'}) async => true;

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
