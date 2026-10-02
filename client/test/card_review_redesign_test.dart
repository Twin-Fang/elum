import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/card_palette.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/card_review_parts.dart';
import 'package:elum/features/guardian/presentation/widgets/card_review_reorder_list.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 보호자 카드확인 개편 (#444).
///
/// 시안 `1173:5541`(기본) · `1197:5798`(순서 변경) · `1197:5923`/`1197:6161`(수정 시트) ·
/// `1197:6044`(추가 시트). 테스트 뷰포트는 안전영역이 0 이라 시안의 상단바(59)만큼 모든
/// y 가 위에 선다 — 그래서 절대 y 는 **바닥에서 잰 값**(카드 끝 571, 저장 버튼 끝 796)과
/// 카드·보상·버튼 사이 간격으로 확인한다.
void main() {
  useFigmaViewport();

  const cards = [
    ActionCard(id: 'c1', stepOrder: 1, title: '옷을 입어요', description: '옷 설명'),
    ActionCard(id: 'c2', stepOrder: 2, title: '가방을 챙겨요', description: '가방 설명'),
    ActionCard(id: 'c3', stepOrder: 3, title: '신발을 신어요', description: '신발 설명'),
  ];

  late _Repo repo;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String rewardText = '젤리 4개 먹기',
    String status = 'PENDING_REVIEW',
    List<ActionCard> steps = cards,
    // 사진 바꾸기 칩(#456)은 서버 카드의 수정 시트만 키운다(그림 칸 +166). 시안
    // 1197:5923 은 그림 칸이 없는 시트라, 그 좌표는 서버 id 없는 일과('')로 잰다.
    String routineId = 'r1',
  }) async {
    repo = _Repo();
    final container = ProviderContainer(
      overrides: [
        offlineDioOverride(),
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        speechServiceProvider.overrideWithValue(_SilentSpeech()),
        routineRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(routineFlowProvider.notifier).state = RoutineFlowState(
      routine: Routine(
        id: routineId,
        title: '학교에 가요',
        status: status,
        rewardText: rewardText,
        steps: steps,
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

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Rect rectOfContainerAround(WidgetTester tester, Finder inner) =>
      tester.getRect(
        find.ancestor(of: inner, matching: find.byType(Container)).first,
      );

  /// 순서 변경 모드에서 [id] 카드를 오른쪽으로 [dx] 만큼 길게 눌러 끈다.
  Future<void> dragCard(WidgetTester tester, String id, double dx) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey(id))),
    );
    // 시안 문구 그대로 **길게** 눌러야 집힌다
    await tester.pump(const Duration(milliseconds: 700));
    // 집힌 뒤 첫 움직임은 터치 슬롭을 넘겨야 끌기가 시작된다
    await gesture.moveBy(const Offset(kTouchSlop + 1, 0));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(Offset((dx - kTouchSlop - 1) / 8, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    // 놓는 애니메이션은 한 프레임 뒤에 시작해 끝나야 순서가 확정된다
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('기본 화면 (1173:5541)', () {
    testWidgets('도구 버튼 3개와 카드 저장하기, 임시저장이 있다', (tester) async {
      await pump(tester);

      expect(find.text('카드 순서 변경'), findsOneWidget);
      expect(find.text('이 카드 수정'), findsOneWidget);
      expect(find.text('카드 추가'), findsOneWidget);
      expect(find.text('카드 저장하기'), findsOneWidget);
      expect(find.text('임시저장'), findsOneWidget);
      // 옛 시안의 알약 칩은 없다
      expect(find.text('이 카드 수정하기'), findsNothing);
      expect(find.text('저장하기'), findsNothing);
    });

    testWidgets('머리는 시안 문구이고 크레딧 줄은 없다', (tester) async {
      await pump(tester);

      expect(find.text('카드 3개를 만들었어요'), findsOneWidget);
      expect(svgWithAsset(AppAssets.iconSparklesHead), findsOneWidget);
      expect(find.textContaining('크레딧'), findsNothing);
    });

    testWidgets('바닥에서 카드 끝 571 · 보상 587 · 버튼 654 · 저장 730~796 이다', (
      tester,
    ) async {
      await pump(tester);

      final card = tester.getRect(find.byKey(const ValueKey('c1')));
      expect(card.left, moreOrLessEquals(30, epsilon: 0.5));
      expect(card.width, moreOrLessEquals(333, epsilon: 0.5));
      expect(card.bottom, moreOrLessEquals(571, epsilon: 0.5));

      final reward = tester.getRect(find.byType(CardReviewRewardRow));
      expect(reward.top, moreOrLessEquals(587, epsilon: 0.5));
      expect(reward.width, moreOrLessEquals(333, epsilon: 0.5));
      expect(reward.height, moreOrLessEquals(46, epsilon: 0.5));

      final reorder = rectOfContainerAround(tester, find.text('카드 순서 변경'));
      final edit = rectOfContainerAround(tester, find.text('이 카드 수정'));
      final add = rectOfContainerAround(tester, find.text('카드 추가'));
      for (final r in [reorder, edit, add]) {
        expect(r.width, moreOrLessEquals(110, epsilon: 0.5));
        expect(r.height, moreOrLessEquals(60, epsilon: 0.5));
        expect(r.top, moreOrLessEquals(654, epsilon: 0.5));
      }
      expect(edit.left - reorder.right, moreOrLessEquals(8, epsilon: 0.5));
      expect(add.left - edit.right, moreOrLessEquals(8, epsilon: 0.5));
      expect(reorder.left, moreOrLessEquals(24, epsilon: 1));

      final save = tester.getRect(find.byType(ElumButton));
      expect(save.top, moreOrLessEquals(730, epsilon: 0.5));
      expect(save.bottom, moreOrLessEquals(796, epsilon: 0.5));
    });

    testWidgets('보상 줄은 정한 것을 완료 시 ○○ 로, 안 정했으면 보상 정하기로 보인다', (tester) async {
      await pump(tester);
      final rich = tester.widget<Text>(
        find.descendant(
          of: find.byType(CardReviewRewardRow),
          matching: find.byType(Text),
        ),
      );
      expect(rich.textSpan!.toPlainText(), '완료 시 젤리 4개 먹기');
    });

    testWidgets('보상이 없으면 보상 정하기가 보인다', (tester) async {
      await pump(tester, rewardText: '');

      expect(find.text('보상 정하기'), findsOneWidget);
    });

    testWidgets('수정 연필은 도구 버튼 · 보상 줄에서 시안 에셋이다', (tester) async {
      await pump(tester);

      expect(svgWithAsset(AppAssets.iconInterlining), findsOneWidget);
      expect(svgWithAsset(AppAssets.iconPlus), findsOneWidget);
      // 도구 버튼(원색) + 보상 줄(민트)
      expect(svgWithAsset(AppAssets.iconPencilEdit), findsNWidgets(2));
    });

    testWidgets('임시저장을 누르면 홈 버튼과 같은 나가기 팝업이 뜬다', (tester) async {
      await pump(tester);

      await tester.tap(find.text('임시저장'));
      await settle(tester);

      expect(find.text('임시저장에 두고 나갈까요?'), findsOneWidget);
    });

    testWidgets('이미 저장한 일과의 임시저장도 홈과 같은 팝업이다', (tester) async {
      await pump(tester, status: 'CONFIRMED');

      await tester.tap(find.text('임시저장'));
      await settle(tester);

      // 홈 버튼이 묻는 것과 같은 문구다 — 저장하지 않고 나가는 것을 묻는다
      expect(find.text('임시저장에 두고 나갈까요?'), findsNothing);
      expect(find.textContaining('저장하지 않고'), findsOneWidget);
    });
  });

  group('순서 변경 모드 (1197:5798)', () {
    testWidgets('버튼을 누르면 모드가 바뀐다 — 제목·안내·완료가 나온다', (tester) async {
      await pump(tester);

      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      // 상단 제목 + 도구 버튼 라벨
      expect(find.text('카드 순서 변경'), findsNWidgets(2));
      expect(find.text('카드를 길게 눌러 순서를 변경하세요'), findsOneWidget);
      expect(find.text('완료'), findsOneWidget);
      expect(find.text('카드 저장하기'), findsNothing);
      expect(svgWithAsset(AppAssets.iconClose), findsOneWidget);
    });

    testWidgets('뒤로·홈·임시저장·머리·보상 줄이 사라진다', (tester) async {
      await pump(tester);

      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      expect(find.text('임시저장'), findsNothing);
      expect(svgWithAsset(AppAssets.iconBack), findsNothing);
      expect(svgWithAsset(AppAssets.iconHome), findsNothing);
      expect(find.textContaining('만들었어요'), findsNothing);
      expect(find.byType(CardReviewRewardRow), findsNothing);
    });

    testWidgets('✕ 는 왼쪽 x=16 에 서고 가운데 제목과 겹치지 않는다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final close = tester.getRect(svgWithAsset(AppAssets.iconClose));
      expect(close.left, moreOrLessEquals(16, epsilon: 0.5));
      expect(close.width, moreOrLessEquals(40, epsilon: 0.5));
      // 시안 y=67 (테스트 뷰포트는 안전영역이 0 이라 상단바 안에서는 16)
      expect(close.top, moreOrLessEquals(8, epsilon: 0.5));

      final title = tester.getRect(find.text('카드 순서 변경').first);
      expect(title.center.dx, moreOrLessEquals(196.5, epsilon: 1));
      expect(title.left, greaterThan(close.right), reason: '제목이 ✕ 에 겹치면 안 된다');
    });

    testWidgets('카드 X 는 그리지 않는다', (tester) async {
      await pump(tester);
      expect(svgWithAsset(AppAssets.iconCardDelete), findsWidgets);

      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      expect(svgWithAsset(AppAssets.iconCardDelete), findsNothing);
    });

    testWidgets('카드는 기본 화면과 같은 자리에 선다', (tester) async {
      await pump(tester);
      final before = tester.getRect(find.byKey(const ValueKey('c1')));

      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final after = tester.getRect(find.byKey(const ValueKey('c1')));
      expect(after.left, moreOrLessEquals(before.left, epsilon: 0.5));
      expect(after.top, moreOrLessEquals(before.top, epsilon: 0.5));
      expect(after.width, moreOrLessEquals(before.width, epsilon: 0.5));
      expect(after.height, moreOrLessEquals(before.height, epsilon: 0.5));
    });

    testWidgets('수정·추가 버튼은 눌리지 않는다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      await tester.tap(find.text('이 카드 수정'));
      await tester.tap(find.text('카드 추가'));
      await settle(tester);

      expect(find.text('카드 수정'), findsNothing);
      expect(find.text('새로운 카드 추가'), findsNothing);
    });

    testWidgets('길게 눌러 끌면 순서가 바뀌고 완료하면 모드를 나온다', (tester) async {
      final container = await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      await dragCard(tester, 'c1', 360);
      expect(
        idsOf(container),
        isNot(['c1', 'c2', 'c3']),
        reason: '첫 카드가 뒤로 갔다',
      );
      expect(idsOf(container).first, isNot('c1'));

      await tester.tap(find.text('완료'));
      await settle(tester);

      expect(find.text('카드 저장하기'), findsOneWidget);
      expect(idsOf(container).first, isNot('c1'), reason: '완료는 순서를 그대로 둔다');
    });

    /// 애니메이션이 프레임마다 흐르도록 잘게 나눠 시간을 보낸다 — 한 번에 길게 넘기면
    /// 붙는 애니메이션이 끝난 프레임에서 멈춰 그 뒤에 시작하는 색 전환을 못 본다.
    Future<void> pumpFrames(WidgetTester tester, int ms) async {
      for (var t = 0; t < ms; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    /// 카드 [id] 의 배경색 — 카드 루트 Container 의 decoration.
    Color fillOf(WidgetTester tester, String id) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(ValueKey(id)),
              matching: find.byType(Container),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color!;
    }

    testWidgets('놓으면 카드가 안착한 뒤에 새 자리 색으로 서서히 섞인다 — 확 바뀌지 않는다 (#451 · #471)', (
      tester,
    ) async {
      final container = await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final before = fillOf(tester, 'c1');
      expect(before, CardPalette.at(0).fill, reason: '첫 자리 색으로 시작한다');

      // 맨 끝 자리 너머로 끌어다 놓는다
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('c1'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveBy(const Offset(180, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      expect(
        idsOf(container).indexOf('c1'),
        isNot(0),
        reason: '놓는 순간 순서가 정해진다',
      );
      final target = CardPalette.at(idsOf(container).indexOf('c1')).fill;

      // 안착하는 300ms 동안에는 색이 그대로다 — 자리에 들어간 다음에 바뀐다
      await pumpFrames(tester, 150);
      expect(fillOf(tester, 'c1'), before, reason: '안착하는 도중에는 아직 옛 색이다');

      // 안착이 끝난 다음부터 색이 섞인다(300ms)
      await pumpFrames(tester, 320);
      final mid = fillOf(tester, 'c1');
      expect(mid, isNot(before), reason: '안착한 뒤 옛 색을 떠났다');
      expect(mid, isNot(target), reason: '아직 새 색에 닿지 않았다 — 한 번에 바뀌면 안 된다');

      await pumpFrames(tester, 800);
      expect(fillOf(tester, 'c1'), target, reason: '끝나면 새 자리 색이다');
    });

    testWidgets('놓으면 카드가 화면 정중앙으로 붙는다 — 자리에 걸쳐 있지 않다 (#451)', (tester) async {
      final container = await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final screenCenter =
          tester.getSize(find.byType(Scaffold).first).width / 2;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('c1'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(kTouchSlop + 1, 0));
      await tester.pump();
      // 카드 한 장 폭의 절반쯤만 끌어 놓아 정중앙에서 어긋난 자리에 놓는다
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(Offset((230 - kTouchSlop - 1) / 8, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pump();
      for (var i = 0; i < 60 && idsOf(container).indexOf('c1') == 0; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(idsOf(container).indexOf('c1'), isNot(0));

      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getCenter(find.byKey(const ValueKey('c1'))).dx,
        moreOrLessEquals(screenCenter, epsilon: 1),
        reason: '놓은 카드가 화면 정중앙에 선다',
      );
    });

    testWidgets('순서 변경 모드에서 옆으로 스크롤해도 카드가 한 장씩 정면에 붙는다 — 두 장이 걸치지 않는다 (#451)', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final screenCenter =
          tester.getSize(find.byType(Scaffold).first).width / 2;
      double centerOf(String id) =>
          tester.getCenter(find.byKey(ValueKey(id))).dx;

      // 카드 폭의 절반도 안 되게 살짝 넘기면 원래 카드로 돌아와 붙는다
      await tester.drag(find.byKey(const ValueKey('c1')), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(centerOf('c1'), moreOrLessEquals(screenCenter, epsilon: 1));

      // 반쯤(카드 한 장의 절반을 넘게) 넘기면 다음 카드가 정면에 붙는다
      await tester.drag(
        find.byKey(const ValueKey('c1')),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      expect(centerOf('c2'), moreOrLessEquals(screenCenter, epsilon: 1));
    });

    testWidgets('스크롤이 이미 끝인 채 맨 끝 자리로 옮겨도 색과 번호가 새 자리로 바뀐다 (#451)', (
      tester,
    ) async {
      final container = await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      // 먼저 맨 끝 카드까지 스크롤해 둔다 — 붙는 애니메이션의 목표가 지금 위치와 같아지는 조건
      await tester.drag(
        find.byKey(const ValueKey('c1')),
        const Offset(-700, 0),
      );
      await tester.pumpAndSettle();
      final width = tester.getSize(find.byType(Scaffold).first).width;
      expect(
        tester.getCenter(find.byKey(const ValueKey('c3'))).dx,
        moreOrLessEquals(width / 2, epsilon: 1),
        reason: '마지막 카드가 정면에 서 있다',
      );

      // 왼쪽에 빼꼼 보이는 두 번째 카드를 잡아 마지막 카드 너머로 끈다
      final y = tester.getCenter(find.byKey(const ValueKey('c3'))).dy;
      final gesture = await tester.startGesture(Offset(10, y));
      await pumpFrames(tester, 700);
      await gesture.moveBy(const Offset(kTouchSlop + 1, 0));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(46, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await pumpFrames(tester, 2500);

      final ids = idsOf(container);
      expect(ids.last, 'c2', reason: '두 번째 카드가 맨 끝으로 갔다');
      expect(
        fillOf(tester, 'c2'),
        CardPalette.at(2).fill,
        reason: '끝 자리(3번) 색으로 바뀐다',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('c2')),
          matching: find.text('3'),
        ),
        findsOneWidget,
        reason: '번호도 3으로 바뀐다',
      );
    });

    testWidgets('눌린 `카드 순서 변경` 버튼을 다시 누르면 모드를 나온다 — 옮긴 순서는 그대로 (#451)', (
      tester,
    ) async {
      final container = await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);
      await dragCard(tester, 'c1', 360);
      final moved = idsOf(container);
      expect(moved.first, isNot('c1'));

      // 상단바 제목과 같은 글이라 도구 버튼 줄 안에서 찾는다
      await tester.tap(
        find.descendant(
          of: find.byType(CardReviewToolRow),
          matching: find.text('카드 순서 변경'),
        ),
      );
      await settle(tester);

      expect(find.text('카드 저장하기'), findsOneWidget, reason: '모드를 나왔다');
      expect(find.text('카드를 길게 눌러 순서를 변경하세요'), findsNothing);
      expect(idsOf(container), moved, reason: '나가도 옮긴 순서는 그대로다(완료와 같다)');
    });

    testWidgets('잡아 끄는 동안 카드가 이웃보다 크고 그림자가 생기며 진동이 울린다 (#451 · #471)', (
      tester,
    ) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final idle = tester.getSize(find.byKey(const ValueKey('c2'))).width;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('c1'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 100));

      // 화면이 줄어든 만큼 이웃은 작아지고, 잡힌 카드는 그보다 4% 더 크다
      final neighbor = tester.getRect(find.byKey(const ValueKey('c2'))).width;
      final held = tester.getRect(find.byKey(const ValueKey('c1'))).width;
      expect(neighbor, lessThan(idle * 0.6), reason: '화면 전체가 줌아웃했다');
      expect(held / neighbor, moreOrLessEquals(1.04, epsilon: 0.005));
      final shadowed = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .any(
            (d) =>
                (d.decoration is BoxDecoration) &&
                ((d.decoration as BoxDecoration).boxShadow ?? []).isNotEmpty,
          );
      expect(shadowed, isTrue, reason: '잡힌 카드에는 그림자가 진다');
      expect(
        haptics.where((h) => h.contains('mediumImpact')),
        isNotEmpty,
        reason: '잡히는 순간 진동으로 알린다',
      );

      await gesture.up();
      await pumpFrames(tester, 1200);
      final back = tester.getRect(find.byKey(const ValueKey('c1'))).width;
      expect(
        back,
        moreOrLessEquals(idle, epsilon: 0.5),
        reason: '놓으면 제 크기로 돌아온다',
      );
    });

    testWidgets('잡은 카드는 원래 높이를 그대로 지킨다 — 아래가 잘리고 그림자만 남지 않는다 (#451)', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final idle = tester.getSize(find.byKey(const ValueKey('c1')));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('c1'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(kTouchSlop + 1, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 300));

      // 들린 사본이 그림자를 깔려고 감싼 Stack 에서 카드가 내용 높이로 줄어들었다.
      final lifted = tester.getSize(find.byKey(const ValueKey('c1')));
      expect(lifted.height, moreOrLessEquals(idle.height, epsilon: 0.5));
      expect(lifted.width, moreOrLessEquals(idle.width, epsilon: 0.5));

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('짧게 눌러서는 카드가 집히지 않는다', (tester) async {
      final container = await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('c1'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(300, 0));
      await gesture.up();
      await settle(tester);

      expect(idsOf(container), ['c1', 'c2', 'c3']);
    });

    testWidgets('✕ 를 누르면 들어오기 전 순서로 돌아간다', (tester) async {
      final container = await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);
      await dragCard(tester, 'c1', 360);

      await tester.tap(svgWithAsset(AppAssets.iconClose));
      await settle(tester);

      expect(idsOf(container), ['c1', 'c2', 'c3']);
      expect(find.text('카드 저장하기'), findsOneWidget);
    });

    testWidgets('기기 뒤로는 나가기 팝업이 아니라 모드만 닫는다', (tester) async {
      final container = await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);
      await dragCard(tester, 'c1', 360);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text('임시저장에 두고 나갈까요?'), findsNothing);
      expect(find.text('카드 저장하기'), findsOneWidget);
      expect(idsOf(container), ['c1', 'c2', 'c3']);
    });

    testWidgets('바꾼 순서는 카드 저장하기가 서버로 보낸다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);
      await dragCard(tester, 'c1', 360);
      await tester.tap(find.text('완료'));
      await settle(tester);
      expect(repo.reorderCalls, isEmpty, reason: '옮기는 동안은 서버를 부르지 않는다');

      await tester.tap(find.text('카드 저장하기'));
      await settle(tester);

      expect(repo.reorderCalls, hasLength(1));
      expect(repo.reorderCalls.single.toSet(), {'c1', 'c2', 'c3'});
      expect(repo.reorderCalls.single.first, isNot('c1'));
    });
  });

  group('손가락을 따라다니는 순서 변경 (#471)', () {
    /// [id] 카드를 길게 눌러 집고 줌아웃이 끝날 때까지 기다린다.
    Future<TestGesture> grab(WidgetTester tester, String id) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey(id))),
      );
      // 길게 누름(500ms) 뒤 줌아웃(300ms)이 끝나기까지
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      return gesture;
    }

    Rect rectOf(WidgetTester tester, String id) =>
        tester.getRect(find.byKey(ValueKey(id)));

    double screenWidth(WidgetTester tester) =>
        tester.getSize(find.byType(Scaffold).first).width;

    Future<void> enter(WidgetTester tester) async {
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);
    }

    Future<void> frames(WidgetTester tester, int ms) async {
      for (var t = 0; t < ms; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    test('들어갈 사이는 눈에 보이는 배치(벌어진 틈 포함)에서 중심이 지나온 카드 수다', () {
      int at(double x, int gap) => reorderInsertionIndex(
        contentX: x,
        count: 3,
        leading: 25,
        extent: 343,
        gap: gap,
      );

      // 틈이 맨 앞(0)이면 카드 셋의 중심은 539.5 · 882.5 · 1225.5
      expect(at(0, 0), 0);
      expect(at(400, 0), 0, reason: '틈 안에 있는 동안은 자리가 바뀌지 않는다');
      expect(at(540, 0), 1, reason: '첫 이웃의 중심을 지나야 틈이 옮겨 간다');
      // 틈이 1 이면 중심은 196.5 · 882.5 · 1225.5 — 이웃이 틈 앞으로 물러나 있다
      expect(at(190, 1), 0);
      expect(at(200, 1), 1);
      expect(at(700, 1), 1, reason: '틈(368~711) 안에서는 그대로다');
      expect(at(5000, 2), 3, reason: '맨 끝 너머는 맨 뒤 자리다');
    });

    test('나머지 카드가 없으면 들어갈 자리는 하나뿐이다', () {
      expect(
        reorderInsertionIndex(
          contentX: 300,
          count: 0,
          leading: 25,
          extent: 343,
          gap: 0,
        ),
        0,
      );
    });

    testWidgets('3번을 보다 들어가도 1번으로 튀지 않고 3번이 그대로 선다', (tester) async {
      await pump(tester);
      final width = screenWidth(tester);
      // 기본 화면에서 세 번째 카드까지 넘긴다
      for (var i = 0; i < 2; i++) {
        await tester.drag(
          find.byKey(ValueKey(i == 0 ? 'c1' : 'c2')),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
      }
      expect(
        rectOf(tester, 'c3').center.dx,
        moreOrLessEquals(width / 2, epsilon: 1),
      );

      await enter(tester);

      expect(
        rectOf(tester, 'c3').center.dx,
        moreOrLessEquals(width / 2, epsilon: 1),
        reason: '순서 변경에 들어가도 보던 3번 카드가 정면이다',
      );
    });

    testWidgets('옮기고 완료하면 옮긴 카드에서 이어 본다 — 첫 카드로 돌아가지 않는다', (tester) async {
      final container = await pump(tester);
      await enter(tester);
      final width = screenWidth(tester);

      final gesture = await grab(tester, 'c1');
      await gesture.moveBy(const Offset(330, 0));
      await frames(tester, 300);
      await gesture.up();
      await frames(tester, 1200);
      expect(idsOf(container).last, 'c1');

      await tester.tap(find.text('완료'));
      await settle(tester);

      expect(
        rectOf(tester, 'c1').center.dx,
        moreOrLessEquals(width / 2, epsilon: 1),
        reason: '옮긴 카드가 보이는 자리에서 기본 화면이 이어진다',
      );
    });

    testWidgets('✕ 로 나오면 들어오기 전에 보던 카드로 돌아간다', (tester) async {
      await pump(tester);
      final width = screenWidth(tester);
      await tester.drag(
        find.byKey(const ValueKey('c1')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      await enter(tester);
      final gesture = await grab(tester, 'c2');
      await gesture.moveBy(const Offset(-330, 0));
      await frames(tester, 300);
      await gesture.up();
      await frames(tester, 1200);

      await tester.tap(svgWithAsset(AppAssets.iconClose));
      await settle(tester);

      expect(
        rectOf(tester, 'c2').center.dx,
        moreOrLessEquals(width / 2, epsilon: 1),
      );
    });

    testWidgets('집으면 화면이 줌아웃해 옆 카드가 더 보인다', (tester) async {
      await pump(tester);
      await enter(tester);
      final width = screenWidth(tester);
      expect(
        rectOf(tester, 'c2').right,
        greaterThan(width),
        reason: '평소에는 두 번째 카드가 화면 밖으로 걸쳐 있다',
      );
      final idle = rectOf(tester, 'c2').width;

      final gesture = await grab(tester, 'c1');

      expect(
        rectOf(tester, 'c2').center.dx,
        lessThan(width),
        reason: '줌아웃하면 두 번째 카드가 화면 안으로 들어온다',
      );
      expect(
        rectOf(tester, 'c2').width,
        lessThan(idle * 0.5),
        reason: '카드가 절반 밑으로 줄어든다',
      );
      await gesture.up();
      await frames(tester, 1200);
    });

    testWidgets('잡은 카드는 손가락을 따라 위아래로도 움직인다', (tester) async {
      await pump(tester);
      await enter(tester);
      final gesture = await grab(tester, 'c1');
      final before = rectOf(tester, 'c1');

      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 50));
      final after = rectOf(tester, 'c1');
      expect(after.top - before.top, moreOrLessEquals(120, epsilon: 1));

      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        rectOf(tester, 'c1').left - after.left,
        moreOrLessEquals(40, epsilon: 1),
      );

      await gesture.up();
      await frames(tester, 1200);
    });

    testWidgets('카드를 사이에 가져다 대면 그 자리가 벌어진다', (tester) async {
      await pump(tester);
      await enter(tester);
      final gesture = await grab(tester, 'c1');
      final y = tester.getCenter(find.byKey(const ValueKey('c1'))).dy;
      await frames(tester, 300);
      final rest = rectOf(tester, 'c2');
      final cardWidth = rest.width;

      // 집은 카드의 원래 자리가 그대로 손가락 아래에 열려 있다
      expect(
        rest.left,
        greaterThan(cardWidth * 0.9),
        reason: '두 번째 카드 앞에 빈 자리(집은 카드의 자리)가 있다',
      );

      // 두 번째 카드의 중심을 지나 두 번째와 세 번째 카드 사이로 가져간다
      await gesture.moveTo(Offset(rest.center.dx + 12, y));
      await frames(tester, 400);
      final opened = rectOf(tester, 'c2');

      expect(
        rest.left - opened.left,
        greaterThan(cardWidth * 0.9),
        reason: '두 번째 카드가 앞으로 당겨진다',
      );
      expect(
        rectOf(tester, 'c3').left - opened.right,
        greaterThan(cardWidth * 0.9),
        reason: '두 카드 사이에 카드 한 장만 한 틈이 열린다',
      );

      // 손가락이 틈 안에 있는 동안은 자리가 그대로다
      // (가장자리 자동 스크롤 구역을 피해 틈 안쪽 왼편에 둔다)
      await gesture.moveTo(Offset(opened.right + 30, y));
      await frames(tester, 300);
      expect(
        rectOf(tester, 'c2').left,
        moreOrLessEquals(opened.left, epsilon: 1),
      );

      // 다시 앞으로 돌아가면 벌어진 자리도 따라간다
      await gesture.moveTo(Offset(opened.center.dx - 12, y));
      await frames(tester, 400);
      // (두 번째 카드의 중심이 화면 가장자리 구역에 걸려 스크롤이 조금 밀렸을 수 있다)
      expect(
        rectOf(tester, 'c2').left,
        greaterThan(opened.left + cardWidth * 0.5),
        reason: '틈이 앞으로 돌아가 두 번째 카드가 다시 뒤로 밀린다',
      );
      await gesture.up();
      await frames(tester, 1200);
    });

    testWidgets('놓으면 벌어져 있던 사이로 들어간다', (tester) async {
      final container = await pump(tester);
      await enter(tester);
      final gesture = await grab(tester, 'c1');
      final y = tester.getCenter(find.byKey(const ValueKey('c1'))).dy;
      await frames(tester, 300);
      final rest = rectOf(tester, 'c2');

      await gesture.moveTo(Offset(rest.center.dx + 12, y));
      await frames(tester, 400);
      await gesture.up();
      await tester.pump();

      expect(idsOf(container), ['c2', 'c1', 'c3'], reason: '놓는 순간 순서가 정해진다');
      await frames(tester, 1200);
      final width = screenWidth(tester);
      expect(
        rectOf(tester, 'c1').center.dx,
        moreOrLessEquals(width / 2, epsilon: 1),
        reason: '안착하면서 화면이 원래 크기로 돌아와 그 카드가 정면이다',
      );
      expect(
        rectOf(tester, 'c1').width,
        moreOrLessEquals(rectOf(tester, 'c3').width, epsilon: 0.5),
      );
    });

    testWidgets('제스처가 끊기면 옮기지 않고 원래 자리로 돌아온다', (tester) async {
      final container = await pump(tester);
      await enter(tester);
      final gesture = await grab(tester, 'c1');
      await gesture.moveBy(const Offset(320, 0));
      await frames(tester, 300);

      await gesture.cancel();
      await frames(tester, 1200);

      expect(idsOf(container), ['c1', 'c2', 'c3']);
      final width = screenWidth(tester);
      expect(
        rectOf(tester, 'c1').center.dx,
        moreOrLessEquals(width / 2, epsilon: 1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('가장자리에서 자동 스크롤은 빠르지 않다 — 한 번에 두세 장씩 밀리지 않는다', (tester) async {
      final many = [
        for (var i = 1; i <= 8; i++)
          ActionCard(
            id: 'k$i',
            stepOrder: i,
            title: '카드$i',
            description: '설명$i',
          ),
      ];
      await pump(tester, steps: many);
      await enter(tester);
      final gesture = await grab(tester, 'k1');
      final start = tester.getCenter(find.byKey(const ValueKey('k1')));

      // 손가락을 오른쪽 끝에 붙이고 1초 기다린다
      await gesture.moveTo(Offset(screenWidth(tester) - 4, start.dy));
      final scroll = tester
          .widget<SingleChildScrollView>(
            find
                .descendant(
                  of: find.byType(CardReviewReorderList),
                  matching: find.byType(SingleChildScrollView),
                )
                .first,
          )
          .controller!;
      final before = scroll.offset;
      await frames(tester, 1000);
      final moved = scroll.offset - before;

      expect(moved, greaterThan(50), reason: '가장자리에 닿으면 스크롤된다');
      expect(moved, lessThan(380), reason: '1초에 카드 두 장(줌아웃 기준 약 380)을 넘지 않는다');
      await gesture.up();
      await frames(tester, 1200);
    });

    testWidgets('카드가 한 장이면 길게 눌러도 집히지 않는다', (tester) async {
      await pump(tester, steps: [cards.first]);
      await enter(tester);
      final idle = rectOf(tester, 'c1');

      final gesture = await grab(tester, 'c1');
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(rectOf(tester, 'c1'), idle, reason: '줌아웃도 따라오기도 없다');
      await gesture.up();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('스크린리더가 카드를 한 칸씩 옮길 수 있다', (tester) async {
      final handle = tester.ensureSemantics();
      final container = await pump(tester);
      await enter(tester);

      final movable = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.customSemanticsActions?.keys.any(
                  (a) => a.label == '뒤로 옮기기',
                ) ??
                false),
      );
      expect(movable, findsWidgets);
      final action = movable.evaluate().first.widget as Semantics;
      final back = action.properties.customSemanticsActions!.entries
          .firstWhere((e) => e.key.label == '뒤로 옮기기')
          .value;

      back();
      await frames(tester, 800);

      expect(idsOf(container), ['c2', 'c1', 'c3']);
      handle.dispose();
    });
  });

  group('카드 추가 시트 (1197:6044)', () {
    Future<void> openAdd(WidgetTester tester) async {
      await tester.tap(find.text('카드 추가'));
      await settle(tester);
    }

    Future<void> fill(WidgetTester tester) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '양치를 해요');
      await tester.enterText(fields.last, '이를 닦아요');
      await tester.pump();
    }

    testWidgets('제목·버튼 문구와 빈 입력칸으로 열린다', (tester) async {
      await pump(tester);

      await openAdd(tester);

      expect(find.text('새로운 카드 추가'), findsOneWidget);
      expect(find.text('추가하기'), findsOneWidget);
      expect(find.text('제목'), findsOneWidget);
      expect(find.text('설명'), findsOneWidget);
      // 시안 잔재였던 `설명` 글자 하나가 더 있으면 둘이 된다
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.every((f) => f.controller!.text.isEmpty), isTrue);
    });

    testWidgets('제목과 설명이 다 있어야 추가하기가 켜진다', (tester) async {
      await pump(tester);
      await openAdd(tester);

      await tester.tap(find.text('추가하기'));
      await settle(tester);
      expect(repo.addCalls, 0, reason: '빈 카드는 서버에 가지 않는다');

      await tester.enterText(find.byType(TextField).first, '양치를 해요');
      await tester.pump();
      await tester.tap(find.text('추가하기'));
      await settle(tester);
      expect(repo.addCalls, 0, reason: '설명이 비었다');
    });

    testWidgets('추가하면 카드가 맨 뒤에 붙고 머리 개수가 는다', (tester) async {
      final container = await pump(tester);
      await openAdd(tester);
      await fill(tester);

      await tester.tap(find.text('추가하기'));
      await settle(tester);

      expect(repo.addCalls, 1);
      expect(repo.lastAdd, (title: '양치를 해요', description: '이를 닦아요'));
      expect(find.text('새로운 카드 추가'), findsNothing, reason: '시트가 닫힌다');
      expect(idsOf(container), ['c1', 'c2', 'c3', 'n1']);
      expect(find.text('카드 4개를 만들었어요'), findsOneWidget);
    });

    testWidgets('실패하면 시트가 열린 채 쓴 글이 남고 에러 코드가 뜬다', (tester) async {
      final container = await pump(tester);
      repo.failAdd = true;
      await openAdd(tester);
      await fill(tester);

      await tester.tap(find.text('추가하기'));
      await settle(tester);

      expect(find.text('새로운 카드 추가'), findsOneWidget, reason: '시트가 남는다');
      expect(find.textContaining('E-STEP-ADD'), findsOneWidget);
      final first = tester.widget<TextField>(find.byType(TextField).first);
      expect(first.controller!.text, '양치를 해요', reason: '쓴 글이 사라지지 않는다');
      expect(idsOf(container), ['c1', 'c2', 'c3']);
    });
  });

  group('시트 좌표 (1197:5923 · 1197:6044 · 1197:6161)', () {
    Rect fieldRect(WidgetTester tester, int index) =>
        rectOfContainerAround(tester, find.byType(TextField).at(index));

    testWidgets('수정 시트는 높이 450 이고 시안 자리에 선다', (tester) async {
      await pump(tester, routineId: '');
      await tester.tap(find.text('이 카드 수정'));
      await settle(tester);

      final title = tester.getRect(find.text('카드 수정'));
      expect(title.left, moreOrLessEquals(24, epsilon: 0.5));
      expect(title.top, moreOrLessEquals(402 + 40, epsilon: 1));

      expect(
        tester.getRect(find.text('제목')).top,
        moreOrLessEquals(402 + 84, epsilon: 1),
      );
      final titleField = fieldRect(tester, 0);
      expect(titleField.left, moreOrLessEquals(16, epsilon: 0.5));
      expect(titleField.top, moreOrLessEquals(402 + 109, epsilon: 0.5));
      expect(titleField.width, moreOrLessEquals(361, epsilon: 0.5));
      expect(titleField.height, moreOrLessEquals(68, epsilon: 0.5));

      expect(
        tester.getRect(find.text('설명')).top,
        moreOrLessEquals(402 + 193, epsilon: 1),
      );
      expect(
        fieldRect(tester, 1).top,
        moreOrLessEquals(402 + 218, epsilon: 0.5),
      );

      final button = tester.getRect(
        find
            .descendant(
              of: find.ancestor(
                of: find.text('완료'),
                matching: find.byType(ElumButton),
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(button.bottom, moreOrLessEquals(796, epsilon: 0.5));
      expect(button.height, moreOrLessEquals(66, epsilon: 0.5));
    });

    testWidgets('손잡이는 선 가운데가 y=16 이다 (윗변 14 · 굵기 4 · 폭 40)', (tester) async {
      await pump(tester, routineId: '');
      await tester.tap(find.text('이 카드 수정'));
      await settle(tester);

      final handle = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color ==
                AppTheme.light.extension<AppColors>()!.sheetHandle,
      );
      final rect = tester.getRect(handle.first);
      expect(rect.top, moreOrLessEquals(402 + 14, epsilon: 0.5));
      expect(rect.height, moreOrLessEquals(4, epsilon: 0.5));
      expect(rect.width, moreOrLessEquals(40, epsilon: 0.5));
      expect(rect.center.dx, moreOrLessEquals(196.5, epsilon: 0.5));
    });

    testWidgets('추가 시트는 40 더 높다 (488)', (tester) async {
      await pump(tester);
      await tester.tap(find.text('카드 추가'));
      await settle(tester);

      expect(
        tester.getRect(find.text('새로운 카드 추가')).top,
        moreOrLessEquals(364 + 40, epsilon: 1),
      );
      expect(
        tester.getRect(find.text('제목')).top,
        moreOrLessEquals(364 + 124, epsilon: 1),
      );
      expect(
        fieldRect(tester, 0).top,
        moreOrLessEquals(364 + 149, epsilon: 0.5),
      );
      expect(
        tester.getRect(find.text('설명')).top,
        moreOrLessEquals(364 + 233, epsilon: 1),
      );
      expect(
        fieldRect(tester, 1).top,
        moreOrLessEquals(364 + 258, epsilon: 0.5),
      );
    });

    testWidgets('키보드가 올라오면 시트가 y=82 까지 자라고 입력칸은 그대로 키보드 위다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('이 카드 수정'));
      await settle(tester);

      showKeyboard(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 시트 윗변 82 → 제목 글자 82 + 40
      expect(
        tester.getRect(find.text('카드 수정')).top,
        moreOrLessEquals(82 + 40, epsilon: 1),
      );
      final descField = fieldRect(tester, 1);
      expect(descField.top, moreOrLessEquals(82 + 218, epsilon: 0.5));
      // 키보드(336)는 y=516 부터다 — 입력칸이 가려지지 않는다
      expect(descField.bottom, lessThan(852 - 336));
    });
  });

  group('실패해도 화면이 깨지지 않는다', () {
    testWidgets('카드가 한 장이어도 순서 변경·추가 버튼이 있고 X 는 없다', (tester) async {
      await pump(
        tester,
        steps: const [
          ActionCard(id: 'c1', stepOrder: 1, title: '옷', description: '설명'),
        ],
      );

      expect(find.text('카드 순서 변경'), findsOneWidget);
      expect(find.text('카드 추가'), findsOneWidget);
      expect(svgWithAsset(AppAssets.iconCardDelete), findsNothing);
    });

    testWidgets('글꼴 2.0 에서도 임시저장은 한 줄이고 72×40 안에 든다', (tester) async {
      // 실기기(2026-09-29)에서 `임시저 / 장` 으로 꺾이고 둘째 줄이 잘렸다
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester);

      final text = tester.getRect(find.text('임시저장'));
      expect(text.width, lessThanOrEqualTo(72.5));
      expect(text.height, lessThanOrEqualTo(40));
      // 한 줄이다 — 글꼴 2.0 에서 16 글자 한 줄은 32, 두 줄이면 64 다
      final laidOut = tester.getSize(find.text('임시저장')).height;
      expect(laidOut, lessThan(40), reason: '두 줄로 꺾이지 않았다');
    });

    testWidgets('글꼴 2.0 에서도 순서 모드 안내는 한 줄이고 보상 줄 자리(46) 안에 든다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final hint = tester.getRect(find.text('카드를 길게 눌러 순서를 변경하세요'));
      final box = tester.getRect(find.byType(CardReviewReorderHint));
      expect(
        hint.bottom,
        lessThanOrEqualTo(box.bottom + 0.5),
        reason: '안내가 자리 밖으로 잘리지 않는다',
      );
      expect(hint.width, lessThanOrEqualTo(box.width + 0.5));
    });

    testWidgets('글꼴을 키워도 도구 버튼이 넘치지 않는다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pump(tester);

      // 오버플로는 flutter_test_config 가 자동으로 실패시킨다
      expect(find.text('카드 순서 변경'), findsOneWidget);
    });
  });
}

class _Repo implements RoutineRepository {
  final reorderCalls = <List<String>>[];
  var addCalls = 0;
  ({String title, String description})? lastAdd;
  var failAdd = false;

  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async {
    addCalls++;
    lastAdd = (title: title, description: description);
    if (failAdd) {
      // 서버가 이유를 주지 않은 실패 — 화면 코드(E-STEP-ADD)가 나선다
      return (
        routine: routine,
        failure: const AppFailure(fault: NetworkFault.app),
      );
    }
    return (
      routine: routine.copyWith(
        steps: [
          ...routine.steps,
          ActionCard(
            id: 'n1',
            description: description,
            stepOrder: routine.steps.length + 1,
          ),
        ],
      ),
      failure: null,
    );
  }

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async => null;

  @override
  Future<AppFailure?> reorderSteps(
    String routineId,
    List<String> stepIds,
  ) async {
    reorderCalls.add(stepIds);
    return null;
  }

  @override
  Future<Routine> confirm(Routine routine) async =>
      routine.copyWith(status: 'CONFIRMED');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentSpeech implements SpeechService {
  @override
  Future<bool> speak(String text, {String language = 'ko'}) async => true;

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
