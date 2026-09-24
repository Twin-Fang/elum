import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/widgets/child_card_pager.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 행동카드 넘기기 화면에서 양옆 카드가 살짝 보인다 (이슈 #394).
///
/// 시안(`309:3548`)은 가운데 카드 한 장만 그린다. 옆으로 넘기면 더 있다는 것을
/// 글이 아니라 그림으로 알리려고 **양옆 카드를 가장자리에 조금 걸친다** — 사용자가
/// 승인한 시안 이탈이다. 가운데 카드의 크기·자리(345×431 @ 24,180)는 그대로다.
void main() {
  useFigmaViewport();

  const threeCards = [
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

  /// 시안 좌표 — 가운데 카드 자리와 화면 폭.
  const designCard = Rect.fromLTWH(24, 180, 345, 431);
  const screenWidth = 393.0;

  /// id를 `local`로 둔다 — 서버에 없는 일과라 동기화를 타지 않는다.
  Widget wrap({
    List<ActionCard> cards = threeCards,
    bool reduceMotion = false,
    double textScale = 1,
    _CountingSpeech? speech,
  }) => ProviderScope(
    overrides: [
      offlineDioOverride(),
      testStorageOverride(onboardingCompleted: true),
      speechServiceProvider.overrideWithValue(speech ?? _CountingSpeech()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp.router(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // 시안 프레임은 상태바 59·홈 인디케이터 21 을 포함해 그린다
            padding: const EdgeInsets.only(top: 59, bottom: 21),
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        routerConfig: GoRouter(
          initialLocation: Routes.childRoutineDetail,
          routes: [
            GoRoute(
              path: Routes.childRoutineDetail,
              builder: (context, state) => ChildRoutineDetailScreen(
                routine: Routine(
                  id: 'local',
                  title: '비 오는 날 학교에 가요',
                  status: 'CONFIRMED',
                  steps: cards,
                ),
              ),
            ),
            GoRoute(
              path: Routes.childReward,
              builder: (context, state) => const Scaffold(body: Text('보상 화면')),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ActionCard> cards = threeCards,
    bool reduceMotion = false,
    double textScale = 1,
    _CountingSpeech? speech,
  }) async {
    await tester.pumpWidget(
      wrap(
        cards: cards,
        reduceMotion: reduceMotion,
        textScale: textScale,
        speech: speech,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  PageController controllerOf(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;

  /// 카드 틀(테두리·그림자를 그리는 상자)이 화면에 그려진 자리.
  /// 옆 카드는 줄여 그리므로 변환까지 반영된 자리를 잰다.
  Rect cardRect(WidgetTester tester, String id) =>
      tester.getRect(find.byKey(ValueKey(id)));

  /// 카드에 걸린 불투명도.
  double opacityOf(WidgetTester tester, String id) => tester
      .widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(ValueKey(id)),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  /// 카드가 화면 안에 보이는 폭. 화면 밖이면 0.
  double visibleWidth(Rect r) =>
      (r.right.clamp(0, screenWidth) - r.left.clamp(0, screenWidth)).toDouble();

  group('가운데 카드는 시안 자리 그대로다', () {
    testWidgets('345×431 @ 24,180', (tester) async {
      await pumpScreen(tester);

      final r = cardRect(tester, 'c1');
      expect(r.left, closeTo(designCard.left, 0.5));
      expect(r.top, closeTo(designCard.top, 0.5));
      expect(r.width, closeTo(designCard.width, 0.5));
      // **카드가 자리 높이(431)를 채운다.** 내용 높이로 두면 시안보다 13 짧다.
      expect(r.height, closeTo(designCard.height, 0.5));
    });

    testWidgets('체크 버튼은 88×88 @ 153,675 그대로다', (tester) async {
      await pumpScreen(tester);

      final r = tester.getRect(
        find.byKey(ChildRoutineDetailScreen.checkButtonKey),
      );
      expect(r.width, closeTo(88, 0.5));
      expect(r.top, closeTo(675, 0.5));
      expect(r.center.dx, closeTo(screenWidth / 2, 0.5));
    });
  });

  // 시안 `309:3548` 카드 안 — 테두리(2, 안쪽)를 포함해 바깥에서 16 들어온 자리에
  // 그림칸 313×264, 그 아래 17 에 배지(40), 배지 오른쪽 8 에 제목, 배지 아래 18 에
  // 설명. 스피커(24)는 배지 칸 한가운데, 설명은 제목과 같은 x 에서 시작한다.
  group('카드 안 배치는 시안대로다', () {
    testWidgets('그림칸 313×264 @ 40,196', (tester) async {
      await pumpScreen(tester);

      final r = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('c1')),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(r.left, closeTo(40, 0.5));
      expect(r.top, closeTo(196, 0.5));
      expect(r.width, closeTo(313, 0.5));
      expect(r.height, closeTo(264, 0.5));
    });

    testWidgets('제목과 설명은 x=88 에서 시작한다 — 배지 오른쪽 8', (tester) async {
      await pumpScreen(tester);

      expect(tester.getRect(find.text('옷을 입어요')).left, closeTo(88, 0.5));
      final desc = tester.getRect(find.text('학교에 갈 옷을 차례대로 입어요'));
      expect(desc.left, closeTo(88, 0.5));
      // 배지 아래(517)에서 18
      expect(desc.top, closeTo(535, 0.5));
    });

    testWidgets('스피커는 배지 칸 가운데(48,535)에 24×24', (tester) async {
      await pumpScreen(tester);

      final r = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('c1')),
          matching: svgWithAsset(AppAssets.iconVolume),
        ),
      );
      expect(r.left, closeTo(48, 0.5));
      expect(r.top, closeTo(535, 0.5));
      expect(r.width, closeTo(24, 0.5));
    });
  });

  group('옆 카드가 가장자리에 살짝 보인다', () {
    testWidgets('P1 첫 카드 — 오른쪽만 보이고 왼쪽은 비어 있다', (tester) async {
      await pumpScreen(tester);

      final right = cardRect(tester, 'c2');
      // 가운데 카드 오른끝(369) + 카드 사이 간격 = 옆 카드 왼끝
      expect(right.left, closeTo(369 + ChildCardPager.cardGap, 0.5));
      expect(visibleWidth(right), closeTo(ChildCardPager.peekWidth, 0.5));
      // 첫 카드 왼쪽에는 아무 카드도 없다 — 가장자리 24 가 비어 있다
      expect(find.byKey(const ValueKey('c0')), findsNothing);
      for (final id in ['c2', 'c3']) {
        if (find.byKey(ValueKey(id)).evaluate().isEmpty) continue;
        expect(cardRect(tester, id).left, greaterThan(designCard.right));
      }
    });

    testWidgets('P2 마지막 카드 — 왼쪽만 보이고 오른쪽은 비어 있다', (tester) async {
      await pumpScreen(tester);
      controllerOf(tester).jumpToPage(2);
      await tester.pump();

      final left = cardRect(tester, 'c2');
      expect(left.right, closeTo(24 - ChildCardPager.cardGap, 0.5));
      expect(visibleWidth(left), closeTo(ChildCardPager.peekWidth, 0.5));

      final last = cardRect(tester, 'c3');
      expect(last.left, closeTo(designCard.left, 0.5));
      expect(last.width, closeTo(designCard.width, 0.5));
    });

    testWidgets('P3 카드 한 장 — 양옆에 아무것도 없다', (tester) async {
      await pumpScreen(tester, cards: [threeCards.first]);

      expect(find.byType(ActionCardView), findsOneWidget);
      final r = cardRect(tester, 'c1');
      expect(r.left, closeTo(designCard.left, 0.5));
    });

    testWidgets('옆 카드는 조금 작고 흐리다 — 가운데 카드는 그대로', (tester) async {
      await pumpScreen(tester);

      expect(opacityOf(tester, 'c1'), 1);
      expect(opacityOf(tester, 'c2'), ChildCardPager.sideOpacity);

      final side = cardRect(tester, 'c2');
      expect(side.height, closeTo(431 * ChildCardPager.sideScale, 0.5));
      // 줄어도 세로 가운데는 가운데 카드와 같다 — 아래로 처지지 않는다
      expect(side.center.dy, closeTo(designCard.center.dy, 0.5));
    });

    testWidgets('넘기는 동안 가운데로 오는 카드가 점점 커지고 선명해진다', (tester) async {
      await pumpScreen(tester);

      final controller = controllerOf(tester);
      final itemWidth =
          controller.position.viewportDimension * controller.viewportFraction;
      // 한 장의 절반만큼 민다
      controller.jumpTo(itemWidth * 0.5);
      await tester.pump();

      final halfway = 1 - (1 - ChildCardPager.sideOpacity) * 0.5;
      expect(opacityOf(tester, 'c1'), closeTo(halfway, 0.01));
      expect(opacityOf(tester, 'c2'), closeTo(halfway, 0.01));
    });

    testWidgets('동작 줄이기면 중간값 없이 가운데만 선명하다', (tester) async {
      await pumpScreen(tester, reduceMotion: true);

      final controller = controllerOf(tester);
      final itemWidth =
          controller.position.viewportDimension * controller.viewportFraction;
      controller.jumpTo(itemWidth * 0.3);
      await tester.pump();

      expect(opacityOf(tester, 'c1'), 1);
      expect(opacityOf(tester, 'c2'), ChildCardPager.sideOpacity);
    });
  });

  group('누르기와 화면 낭독기', () {
    testWidgets('P4 옆 카드를 누르면 그 카드로 넘어간다', (tester) async {
      final speech = _CountingSpeech();
      await pumpScreen(tester, speech: speech);

      // 오른쪽 가장자리에 걸친 옆 카드
      await tester.tapAt(const Offset(385, 400));
      await tester.pumpAndSettle();

      expect(controllerOf(tester).page, closeTo(1, 0.001));
      // 옆 카드 안의 스피커가 대신 눌리지 않는다
      expect(speech.spoken, isEmpty);
    });

    testWidgets('P5 체크 버튼은 언제나 가운데 카드를 체크한다', (tester) async {
      await pumpScreen(tester);

      await tester.tapAt(const Offset(385, 400));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ChildRoutineDetailScreen.checkButtonKey));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChildRoutineDetailScreen)),
      );
      final progress = container.read(childRoutineProvider);
      expect(progress.isChecked('local', threeCards[1]), isTrue);
      expect(progress.isChecked('local', threeCards[0]), isFalse);
      expect(progress.isChecked('local', threeCards[2]), isFalse);

      // 보상 화면으로 넘어가는 대기 타이머를 흘려보낸다
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('P6 화면 낭독기는 옆 카드를 읽지 않고 위치를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.semantics.byLabel(RegExp('옷을 입어요')), findsWidgets);
      expect(find.semantics.byLabel(RegExp('우산을 챙겨요')), findsNothing);
      // 스피커도 가운데 카드 것 하나만 읽힌다
      expect(find.semantics.byLabel('소리로 듣기'), findsOne);

      final position = find.bySemanticsLabel('카드 3장 중 1번째');
      expect(position, findsOneWidget);
      expect(
        tester.getSemantics(position),
        containsSemantics(isLiveRegion: true),
      );

      // 옆 카드 렌더 객체에 남은 옛 의미 정보가 아니라 **지금 트리**를 본다.
      // 넘기면 위치가 바뀐다 — 바뀐 값을 화면 낭독기가 읽는다(liveRegion)
      controllerOf(tester).jumpToPage(1);
      await tester.pump();
      expect(find.bySemanticsLabel('카드 3장 중 2번째'), findsOneWidget);
      expect(find.semantics.byLabel(RegExp('우산을 챙겨요')), findsWidgets);
      expect(find.semantics.byLabel(RegExp('옷을 입어요')), findsNothing);

      handle.dispose();
    });
  });

  // P8 — 시안(`309:3648`)은 체크해도 카드 자체는 그대로고 아래 버튼만 바뀐다. 그래서
  // 옆에 걸친 16 띠에는 체크 여부가 드러나지 않았다. 옆 띠 안에 앱의 체크 표시(민트
  // 원 + 흰 체크)를 둔다. 가운데 카드는 시안대로 아래 버튼으로만 알린다.
  group('P8 체크한 카드는 옆에 걸쳐 있을 때도 알아본다', () {
    Future<ProviderContainer> check(WidgetTester tester, int index) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChildRoutineDetailScreen)),
      );
      container.read(childRoutineProvider.notifier).toggle(
        routine: Routine(
          id: 'local',
          title: '비 오는 날 학교에 가요',
          status: 'CONFIRMED',
          steps: threeCards,
        ),
        card: threeCards[index],
      );
      await tester.pump();
      return container;
    }

    Finder mark(String id) => find.byKey(ValueKey('side-check-$id'));

    testWidgets('첫 카드를 체크하고 넘기면 왼쪽 띠 안에 체크 표시가 보인다', (tester) async {
      await pumpScreen(tester);
      await check(tester, 0);
      controllerOf(tester).jumpToPage(1);
      await tester.pump();

      expect(mark('c1'), findsOneWidget);
      final strip = cardRect(tester, 'c1');
      final m = tester.getRect(mark('c1'));
      // 화면 안, 옆 카드가 보이는 띠(0 ~ 16) 안에 든다 — 간격 쪽으로 조금 걸친다
      expect(m.left, greaterThanOrEqualTo(0));
      expect(m.right, lessThanOrEqualTo(strip.right + ChildCardPager.cardGap / 2));
      expect(m.left, lessThan(strip.right));
      // 옆 카드는 흐리게(0.5) 그리지만 표시는 또렷하다
      expect(_markOpacity(tester, mark('c1')), closeTo(1, 0.001));
      // 앱에 이미 있는 체크 그림을 쓴다 — 새 그림을 만들지 않는다
      expect(
        find.descendant(of: mark('c1'), matching: svgWithAsset(AppAssets.childCheckMark)),
        findsOneWidget,
      );
    });

    testWidgets('오른쪽에 걸친 체크한 카드는 오른쪽 띠 안에 보인다', (tester) async {
      await pumpScreen(tester);
      await check(tester, 1);

      expect(mark('c2'), findsOneWidget);
      final strip = cardRect(tester, 'c2');
      final m = tester.getRect(mark('c2'));
      expect(m.right, lessThanOrEqualTo(screenWidth));
      expect(m.left, greaterThanOrEqualTo(strip.left - ChildCardPager.cardGap / 2));
      expect(m.right, greaterThan(strip.left));
    });

    testWidgets('체크하지 않은 옆 카드에는 표시가 없다', (tester) async {
      await pumpScreen(tester);

      expect(mark('c2'), findsNothing);
    });

    testWidgets('가운데 카드는 체크해도 시안대로 카드에 표시하지 않는다', (tester) async {
      await pumpScreen(tester);
      await check(tester, 0);

      // 가운데 카드는 아래 체크 버튼이 이미 알린다 (시안 309:3648)
      expect(mark('c1'), findsNothing);
    });

    testWidgets('넘기는 동안 표시가 옆으로 갈수록 또렷해진다', (tester) async {
      await pumpScreen(tester);
      await check(tester, 0);

      final controller = controllerOf(tester);
      final itemWidth =
          controller.position.viewportDimension * controller.viewportFraction;
      controller.jumpTo(itemWidth * 0.5);
      await tester.pump();

      expect(_markOpacity(tester, mark('c1')), closeTo(0.5, 0.01));
    });

    testWidgets('동작 줄이기면 옆에 있을 때 바로 또렷하다', (tester) async {
      await pumpScreen(tester, reduceMotion: true);
      await check(tester, 1);

      expect(_markOpacity(tester, mark('c2')), 1);
    });

    testWidgets('화면 낭독기는 옆 카드와 그 표시를 여전히 읽지 않는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);
      await check(tester, 1);

      expect(mark('c2'), findsOneWidget);
      expect(find.semantics.byLabel(RegExp('우산을 챙겨요')), findsNothing);
      // 표시는 옆 카드와 같은 가림 안에 있다
      final excluded = tester.widget<ExcludeSemantics>(
        find.ancestor(of: mark('c2'), matching: find.byType(ExcludeSemantics)).first,
      );
      expect(excluded.excluding, isTrue);
      handle.dispose();
    });
  });

  group('P7 좁은 폭 · 큰 글꼴', () {
    testWidgets('360 폭 · 글꼴 2.0 에서도 넘치지 않고 가운데 카드 내용을 다 볼 수 있다', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(360, 780);
      addTearDown(view.resetPhysicalSize);

      await pumpScreen(tester, textScale: 2);

      // 넘침은 flutter_test_config 가 실패로 만든다
      expect(tester.takeException(), isNull);

      final center = cardRect(tester, 'c1');
      expect(center.left, greaterThanOrEqualTo(0));
      expect(center.right, lessThanOrEqualTo(360));
      // 옆 카드도 비율대로 걸친다
      expect(visibleWidth(cardRect(tester, 'c2')), greaterThan(8));

      // 카드 안에서 끝까지 내리면 설명 끝줄이 카드 안에 들어온다 — 잘려 사라지지 않는다
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('c1')),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final desc = tester.getRect(find.text('학교에 갈 옷을 차례대로 입어요'));
      expect(desc.bottom, lessThanOrEqualTo(center.bottom));
    });
  });
}

/// 읽어 주기를 센다 — 옆 카드의 스피커가 잘못 눌렸는지 본다.
class _CountingSpeech implements SpeechService {
  final spoken = <String>[];

  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// 체크 표시에 걸린 불투명도 — 표시 바로 위의 Opacity.
double _markOpacity(WidgetTester tester, Finder mark) => tester
    .widget<Opacity>(
      find.ancestor(of: mark, matching: find.byType(Opacity)).first,
    )
    .opacity;
