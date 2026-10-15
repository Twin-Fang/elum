import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/card_palette.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/features/guardian/application/routine_flow_state.dart';

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

    testWidgets('임시저장을 누르면 홈 버튼과 같은 나가기 팝업이 뜬다', (tester) async {
      await pump(tester);

      await tester.tap(find.text('임시저장'));
      await settle(tester);

      expect(find.text('임시저장에 두고 나갈까요?'), findsOneWidget);
    });

  });

  group('순서 변경 모드 (1197:5798)', () {

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
