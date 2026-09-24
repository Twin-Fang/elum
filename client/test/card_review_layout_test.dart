import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 카드 확인의 카드 안 배치 (#401 · Figma `262:5124` 보호자_카드확인, 2026-09-24 덤프).
///
/// 시안은 카드 333 @ x=30, 안쪽 여백 10(테두리 포함), 그림칸 313×230, 스피커는
/// 배지 칸 가운데, 설명은 제목과 같은 x(88)다. 앱은 여백 16(테두리 밖)에 스피커가
/// 카드 왼끝이라 **설명이 제목보다 16 왼쪽에서 시작했다.**
///
/// 이룸이 상세(`309:3548`, #394)는 다른 시안이라 여기서 보지 않는다 —
/// `child_card_peek_test`·`action_card_layout_test` 가 그대로 지킨다.
void main() {
  useFigmaViewport();

  const title = '옷을 입어요';
  const description = '학교에 입고 갈 옷을 차례대로 입어요';

  Future<void> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        speechServiceProvider.overrideWithValue(_SilentSpeech()),
      ],
    );
    addTearDown(container.dispose);
    container.read(routineFlowProvider.notifier).state = RoutineFlowState(
      routine: const Routine(
        id: 'r1',
        title: '학교에 가요',
        steps: [
          ActionCard(id: 'c1', stepOrder: 1, title: title, description: description),
          ActionCard(id: 'c2', stepOrder: 2, title: '가방을 챙겨요', description: '설명'),
        ],
      ),
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
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder firstCard() => find.byKey(const ValueKey('c1'));
  Finder inFirst(Finder f) => find.descendant(of: firstCard(), matching: f);

  testWidgets('카드는 333 @ x=30, 옆 카드는 10 띄워 x=373 에서 20 보인다', (tester) async {
    await pump(tester);

    final card = tester.getRect(firstCard());
    expect(card.left, moreOrLessEquals(30, epsilon: 0.5));
    expect(card.width, moreOrLessEquals(333, epsilon: 0.5));

    final next = tester.getRect(find.byKey(const ValueKey('c2')));
    expect(next.left, moreOrLessEquals(373, epsilon: 0.5));
  });

  testWidgets('그림칸은 테두리 포함 10 안쪽에 313×230 이다', (tester) async {
    await pump(tester);

    final card = tester.getRect(firstCard());
    final illustration = tester.getRect(inFirst(find.byType(AspectRatio)));
    expect(illustration.left - card.left, moreOrLessEquals(10, epsilon: 0.5));
    expect(illustration.top - card.top, moreOrLessEquals(10, epsilon: 0.5));
    expect(illustration.width, moreOrLessEquals(313, epsilon: 0.5));
    expect(illustration.height, moreOrLessEquals(230, epsilon: 0.5));
  });

  testWidgets('그림칸 → 배지 10, 배지 → 제목 8 (제목 x=88)', (tester) async {
    await pump(tester);

    final card = tester.getRect(firstCard());
    final illustration = tester.getRect(inFirst(find.byType(AspectRatio)));
    final badge = tester.getRect(
      find.ancestor(of: inFirst(find.text('1')), matching: find.byType(Container)).first,
    );
    final titleRect = tester.getRect(inFirst(find.text(title)));

    expect(badge.left - card.left, moreOrLessEquals(10, epsilon: 0.5));
    expect(badge.top - illustration.bottom, moreOrLessEquals(10, epsilon: 0.5));
    expect(titleRect.left - card.left, moreOrLessEquals(58, epsilon: 0.5)); // 88 - 30
  });

  testWidgets('설명은 제목과 같은 x 에서 시작하고 스피커는 배지 칸 가운데다', (tester) async {
    await pump(tester);

    final card = tester.getRect(firstCard());
    final badge = tester.getRect(
      find.ancestor(of: inFirst(find.text('1')), matching: find.byType(Container)).first,
    );
    final titleRect = tester.getRect(inFirst(find.text(title)));
    final body = tester.getRect(inFirst(find.text(description)));
    final speaker = tester.getRect(inFirst(svgWithAsset(AppAssets.iconVolume)));

    // 시안: 제목·설명 x=88, 스피커 x=48 (배지 40~80 의 가운데)
    expect(body.left, moreOrLessEquals(titleRect.left, epsilon: 0.5));
    expect(speaker.left - card.left, moreOrLessEquals(18, epsilon: 0.5)); // 48 - 30
    expect(speaker.center.dx, moreOrLessEquals(badge.center.dx, epsilon: 0.5));
    // 배지 끝 493 → 설명 511
    expect(body.top - badge.bottom, moreOrLessEquals(18, epsilon: 0.5));
  });

  testWidgets('지우기 버튼은 그림칸 위·오른쪽에서 6 안쪽에 30 이다', (tester) async {
    await pump(tester);

    final illustration = tester.getRect(inFirst(find.byType(AspectRatio)));
    final delete = tester.getRect(inFirst(svgWithAsset(AppAssets.iconCardDelete)));
    expect(delete.width, moreOrLessEquals(30, epsilon: 0.5));
    expect(delete.top - illustration.top, moreOrLessEquals(6, epsilon: 0.5));
    expect(illustration.right - delete.right, moreOrLessEquals(6, epsilon: 0.5));
  });

  testWidgets('카드에 그림자가 없다 (시안 effects 비어 있음)', (tester) async {
    await pump(tester);

    final box = tester
        .widgetList<Container>(inFirst(find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null);
    expect(box.boxShadow ?? const [], isEmpty);
  });

  testWidgets('카드확인 배치는 review 이다 — 이룸이 상세 배치를 쓰지 않는다', (tester) async {
    await pump(tester);

    final view = tester.widget<ActionCardView>(firstCard());
    expect(view.layout, ActionCardLayout.review);
  });
}

class _SilentSpeech implements SpeechService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
