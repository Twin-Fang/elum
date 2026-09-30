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

    /// 지금 화면에 확대(scale>1)되어 서 있는 Transform 이 있는가 — 들린 카드의 표시.
    bool anyScaledUp(WidgetTester tester) => tester
        .widgetList<Transform>(find.byType(Transform))
        .any((t) => t.transform.getMaxScaleOnAxis() > 1.01);

    testWidgets('놓으면 카드 색이 새 자리 색으로 서서히 섞인다 — 확 바뀌지 않는다 (#451)', (
      tester,
    ) async {
      final container = await pump(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);

      final before = fillOf(tester, 'c1');
      expect(before, CardPalette.at(0).fill, reason: '첫 자리 색으로 시작한다');

      // dragCard 와 같되 손을 뗀 직후의 색을 잰다
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('c1'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(kTouchSlop + 1, 0));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(Offset((230 - kTouchSlop - 1) / 8, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pump();
      // 놓는 애니메이션이 끝나 순서가 확정되는 프레임까지 흘린다
      for (var i = 0; i < 60 && idsOf(container).indexOf('c1') == 0; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final newIndex = idsOf(container).indexOf('c1');
      expect(newIndex, isNot(0), reason: '카드가 다른 자리로 갔다');
      final target = CardPalette.at(newIndex).fill;

      // 카드가 정중앙으로 붙는 동안(400ms)에는 색이 그대로다 — 붙은 다음에 바뀐다 (#451)
      await tester.pump(const Duration(milliseconds: 150));
      expect(fillOf(tester, 'c1'), before, reason: '붙는 도중에는 아직 옛 색이다');

      // 다 붙은 직후부터 색이 섞인다(300ms)
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = fillOf(tester, 'c1');
      expect(mid, isNot(before), reason: '붙은 뒤 옛 색을 떠났다');
      expect(mid, isNot(target), reason: '아직 새 색에 닿지 않았다 — 한 번에 바뀌면 안 된다');

      await tester.pump(const Duration(seconds: 1));
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

    /// 애니메이션이 프레임마다 흐르도록 잘게 나눠 시간을 보낸다 — 한 번에 길게 넘기면
    /// 붙는 애니메이션이 끝난 프레임에서 멈춰 그 뒤에 시작하는 색 전환을 못 본다.
    Future<void> pumpFrames(WidgetTester tester, int ms) async {
      for (var t = 0; t < ms; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

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

    testWidgets('잡아 끄는 동안 카드가 확대되고 그림자가 생기며 진동이 울린다 (#451)', (tester) async {
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

      expect(anyScaledUp(tester), isFalse, reason: '손대기 전에는 들린 카드가 없다');

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('c1'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(kTouchSlop + 1, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 300));

      expect(anyScaledUp(tester), isTrue, reason: '잡힌 카드는 커진다');
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
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(anyScaledUp(tester), isFalse, reason: '놓으면 제 크기로 돌아온다');
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
  Future<bool> speak(String text) async => true;

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
