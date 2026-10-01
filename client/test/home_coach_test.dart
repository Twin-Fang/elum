import 'dart:ui' as ui;

import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/coach_mark_overlay.dart';
import 'package:elum/core/widgets/coach_mark_parts.dart';
import 'package:elum/core/widgets/character_badge.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/create_routine_button.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_swipe_actions.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/svg_finder.dart';

/// 보호자 홈 첫 진입 코치마크 (Figma 코치마크 1291:10801 · 이슈 #505).
///
/// 보여지는 조건 · 단계 이동 · 닫기와 기억 · 실패 경로 · 시안 간격을 함께 고정한다.
///
/// **반복 애니메이션(화살표 오감)이 있어 `pumpAndSettle` 을 쓰지 않는다** — 영영 끝나지 않는다.
/// 화살표가 대상 쪽으로 오가는 최대 거리. 시안 간격은 이 안에서 맞으면 된다.
const _bob = 3.2;

void main() {
  useFigmaViewport();

  late _FakeRepo repo;
  late InMemoryStorage storage;
  late GoRouter router;

  Routine routine(String id, String title, {bool? createdByMe}) => Routine(
    id: id,
    title: title,
    status: 'CONFIRMED',
    createdByMe: createdByMe,
    steps: [ActionCard(id: '$id-1', stepOrder: 1, description: '첫 단계')],
  );

  Widget wrap({
    List<Routine> today = const [],
    InMemoryStorage? store,
    bool todayFails = false,
  }) {
    repo = _FakeRepo(today: today, todayFails: todayFails);
    storage =
        store ??
        InMemoryStorage(
          onboardingCompleted: true,
          nickname: '하늘이',
          homeCoachSeen: false,
        );

    router = GoRouter(
      initialLocation: Routes.guardian,
      routes: [
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const GuardianHomeScreen(),
        ),
        GoRoute(
          path: Routes.guardianSettings,
          builder: (context, state) => const Scaffold(body: Text('설정 화면')),
        ),
        GoRoute(
          path: Routes.routineInput,
          builder: (context, state) => const Scaffold(body: Text('일과 입력')),
        ),
        GoRoute(
          path: Routes.child,
          builder: (context, state) => const Scaffold(body: Text('이룸이 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        routineRepositoryProvider.overrideWithValue(repo),
        memberProvider.overrideWith(
          (ref) async => const Member(nickname: '하늘이'),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  /// 목록을 받아 오고, 코치마크가 막을 올리는 연출까지 흘려보낸다.
  Future<void> open(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 홈이 맨 앞에서 잠시 가만히 있어야 시작한다(1.2초)
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 700));
    // 애니메이션은 시작한 프레임에서는 0이다. 한 프레임 더 흘려야 끝까지 간다.
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// 한 번 누르고 단계 이동 연출이 끝나길 기다린다.
  Future<void> tapAnywhere(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 760));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
  }

  Finder message(String part) => find.textContaining(part, findRichText: true);
  final overlay = find.byType(CoachMarkOverlay);

  CoachDots dots(WidgetTester tester) => tester.widget<CoachDots>(find.byType(CoachDots));

  group('보여지는 조건', () {
    testWidgets('처음 들어오면 1단계가 뜬다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));

      expect(overlay, findsOneWidget);
      expect(message('수행할'), findsOneWidget);
      expect(dots(tester).count, 3);
      expect(dots(tester).index, 0);
    });

    testWidgets('이미 본 휴대폰에서는 뜨지 않는다', (tester) async {
      await open(
        tester,
        wrap(
          today: [routine('a', '손 씻기')],
          store: InMemoryStorage(
            onboardingCompleted: true,
            nickname: '하늘이',
            homeCoachSeen: true,
          ),
        ),
      );

      expect(overlay, findsNothing);
    });

    testWidgets('오늘 일과를 받지 못했으면 뜨지 않는다', (tester) async {
      // 가리킬 줄이 있는지 모르는 채 막부터 덮으면 빈 화면을 가리키게 된다.
      await open(tester, wrap(todayFails: true));

      expect(overlay, findsNothing);
      expect(storage.isHomeCoachSeen, isFalse, reason: '못 본 것을 본 것으로 치면 안 된다');
    });

    testWidgets('다른 화면이 홈 위에 있으면 뜨지 않고, 걷히면 시작한다', (tester) async {
      await tester.pumpWidget(wrap(today: [routine('a', '손 씻기')]));
      // 홈이 맨 위가 아닌 채로 목록이 도착한다
      router.push(Routes.guardianSettings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('설정 화면'), findsOneWidget);
      expect(overlay, findsNothing);

      // 팝업이 걷혀도 홈은 다시 그려지지 않는다. 그래도 곧 알아채고 시작해야 한다.
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(overlay, findsOneWidget);
      expect(message('수행할'), findsOneWidget);
    });

    testWidgets('팝업이 연달아 뜨는 찰나에 홈이 잠깐 맨 앞이어도 시작하지 않는다', (tester) async {
      // 실기기에서 공지 팝업 둘이 이어 뜰 때, 앞이 닫히고 뒤가 올라오기 전 찰나에
      // 코치마크가 시작되어 뒤 팝업이 그 위에 겹쳤다.
      await tester.pumpWidget(wrap(today: [routine('a', '손 씻기')]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 홈이 맨 앞인 채로 0.5초 — 아직 지켜보는 중이다
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlay, findsNothing);

      // 그 찰나에 다음 팝업이 올라온다
      router.push(Routes.guardianSettings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('설정 화면'), findsOneWidget);
      expect(overlay, findsNothing, reason: '지켜보던 타이머가 취소돼야 한다');
    });

    testWidgets('일과가 없으면 2단계를 건너뛰어 점이 둘이다', (tester) async {
      await open(tester, wrap());

      expect(dots(tester).count, 2);

      await tapAnywhere(tester);
      expect(message('이룸이모드'), findsOneWidget);
      expect(message('스와이프'), findsNothing);
    });

    testWidgets('남이 만든 일과만 있어도 2단계를 건너뛴다', (tester) async {
      // 남이 만든 일과는 밀어도 삭제·수정이 나오지 않는다(서버 403).
      await open(
        tester,
        wrap(today: [routine('a', '엄마 일과', createdByMe: false)]),
      );

      expect(dots(tester).count, 2);
    });
  });

  group('단계 이동', () {
    testWidgets('누를 때마다 1 → 2 → 3 으로 가고 마지막에서 닫힌다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      expect(message('수행할'), findsOneWidget);

      await tapAnywhere(tester);
      expect(message('스와이프'), findsOneWidget);
      expect(dots(tester).index, 1);

      await tapAnywhere(tester);
      expect(message('이룸이모드'), findsOneWidget);
      expect(dots(tester).index, 2);

      await tapAnywhere(tester);
      expect(overlay, findsNothing);
    });

    testWidgets('2단계에서는 밀 수 있는 줄이 실제로 열리고, 벗어나면 닫힌다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      final closedX = tester.getTopLeft(find.text('손 씻기')).dx;

      await tapAnywhere(tester);
      final openX = tester.getTopLeft(find.text('손 씻기')).dx;
      expect(
        closedX - openX,
        closeTo(RoutineSwipeActions.revealWidth.w, 1.5),
        reason: '삭제·수정 버튼이 드러나도록 카드가 비켜나야 한다',
      );

      await tapAnywhere(tester);
      expect(tester.getTopLeft(find.text('손 씻기')).dx, closeTo(closedX, 1.5));
    });

    testWidgets('X를 누르면 어느 단계에서나 닫힌다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));

      await tester.tap(svgWithAsset(AppAssets.coachClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(overlay, findsNothing);
    });

    testWidgets('2단계에서 닫으면 열려 있던 줄도 함께 닫힌다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      final closedX = tester.getTopLeft(find.text('손 씻기')).dx;
      await tapAnywhere(tester);

      await tester.tap(svgWithAsset(AppAssets.coachClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(overlay, findsNothing);
      expect(tester.getTopLeft(find.text('손 씻기')).dx, closeTo(closedX, 1.5));
    });

    testWidgets('기기 뒤로가기는 홈을 떠나지 않고 안내만 닫는다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(overlay, findsNothing);
      expect(find.byType(GuardianHomeScreen), findsOneWidget);
    });

    testWidgets('막이 떠 있는 동안 아래 버튼은 눌리지 않는다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));

      // 구멍 안의 일과 만들기 버튼을 눌러도 화면이 넘어가지 않고 다음 단계로 간다
      await tester.tap(find.byType(CreateRoutineButton), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('일과 입력'), findsNothing);
      expect(message('스와이프'), findsOneWidget);
    });
  });

  group('기억', () {
    testWidgets('끝까지 보면 본 것으로 남고 다시 뜨지 않는다', (tester) async {
      await open(tester, wrap());
      await tapAnywhere(tester);
      await tapAnywhere(tester);

      expect(overlay, findsNothing);
      expect(storage.isHomeCoachSeen, isTrue);
    });

    testWidgets('중간에 닫아도 본 것으로 남는다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));

      await tester.tap(svgWithAsset(AppAssets.coachClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(storage.isHomeCoachSeen, isTrue);
    });

    testWidgets('저장하지 못해도 앱은 계속 되고, 같은 실행에서 다시 뜨지 않는다', (tester) async {
      await open(
        tester,
        wrap(
          store: _WriteFailingStorage(),
        ),
      );
      await tapAnywhere(tester);
      await tapAnywhere(tester);
      expect(overlay, findsNothing);

      // 홈을 떠났다 돌아와도 같은 실행에서는 다시 띄우지 않는다
      router.go(Routes.child);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      router.go(Routes.guardian);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 700));

      expect(overlay, findsNothing);
      expect(find.byType(GuardianHomeScreen), findsOneWidget);
    });

    testWidgets('읽지 못하는 저장소에서는 띄우지 않는다', (tester) async {
      await open(tester, wrap(store: _ReadFailingStorage()));

      expect(overlay, findsNothing);
    });
  });

  group('시안 1274:10277 · 1291:10401 · 1291:10680 의 간격', () {
    testWidgets('1단계: 화살표가 버튼 가운데 아래에서 시작하고 글은 42 아래에 선다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      final button = tester.getRect(find.byType(CreateRoutineButton));
      final text = tester.getRect(message('수행할'));
      final arrow = _arrowRect(tester);

      expect(arrow.top, closeTo(button.bottom, _bob), reason: '시안 323 → 화살표 시작 323');
      expect(arrow.center.dx, closeTo(button.center.dx, 1));
      expect(text.top - button.bottom, closeTo(42, 0.5), reason: '시안 365 − 323');
      expect(text.center.dx, closeTo(button.center.dx, 2), reason: '1단계는 가운데 맞춤');
    });

    testWidgets('2단계: 글 오른쪽 끝이 버튼 쌍 가운데 + 13 이다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      await tapAnywhere(tester);

      final row = tester.getRect(find.byType(RoutineSwipeActions));
      final actionsCenter = row.right - RoutineSwipeActions.revealWidth.w / 2 + 4.w / 2;
      final text = tester.getRect(message('스와이프'));
      final arrow = _arrowRect(tester);

      expect(arrow.top, closeTo(row.bottom, _bob), reason: '시안 줄 바닥 533 → 화살표 534');
      expect(arrow.center.dx, closeTo(actionsCenter, 2), reason: '시안 화살표 x=305');
      expect(text.right, closeTo(arrow.center.dx + 13, 2), reason: '시안 글 오른쪽 318');
    });

    testWidgets('3단계: 배지 3 아래에서 화살표가 시작하고 글이 오른쪽 맞춤이다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      await tapAnywhere(tester);
      await tapAnywhere(tester);

      final badge = tester.getRect(find.byType(CharacterBadge));
      final text = tester.getRect(message('이룸이모드'));
      final arrow = _arrowRect(tester);

      expect(arrow.top - badge.bottom, closeTo(3, _bob), reason: '시안 126 → 129');
      expect(arrow.center.dx, closeTo(badge.center.dx, 1));
      expect(text.right, closeTo(badge.center.dx + 13, 2), reason: '시안 314 = 301 + 13');
    });
  });

  group('구멍과 막', () {
    testWidgets('구멍 안은 원래 화면 그대로, 밖은 어둡다', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: wrap(today: [routine('a', '손 씻기')])));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      final button = tester.getRect(find.byType(CreateRoutineButton));
      final inside = await _pixel(tester, key, button.center);
      final outside = await _pixel(tester, key, Offset(button.center.dx, button.bottom + 300));

      // 바깥은 배경(밝음)에 검정 75% 가 얹혀 어둡다. 구멍 안은 알약 버튼 색 그대로다.
      final insideLuma = (inside.r + inside.g + inside.b) / 3;
      final outsideLuma = (outside.r + outside.g + outside.b) / 3;
      expect(outsideLuma, lessThan(0.30), reason: '막이 75% 덮는다');
      expect(insideLuma, greaterThan(outsideLuma + 0.25), reason: '구멍 안은 가려지지 않는다');
    });
  });

  group('움직임이 부드럽다 (docs/motion.md 기준)', () {
    CoachHole? holeNow(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<CoachScrimPainter>()
        .firstOrNull
        ?.hole;

    double scrimAlpha(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<CoachScrimPainter>()
        .first
        .color
        .a;

    testWidgets('등장: 막이 서서히 내려앉고, 구멍은 넓게 시작해 대상으로 좁혀진다', (tester) async {
      await tester.pumpWidget(wrap(today: [routine('a', '손 씻기')]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1300)); // 시작
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      final button = tester.getRect(find.byType(CreateRoutineButton));
      final early = holeNow(tester)!;
      expect(early.rect.width, greaterThan(button.width + 20), reason: '처음엔 대상보다 넓다');
      expect(scrimAlpha(tester), lessThan(0.5), reason: '막은 한 번에 덮이지 않는다');

      await tester.pump(const Duration(milliseconds: 150));
      final mid = holeNow(tester)!;
      expect(mid.rect.width, lessThan(early.rect.width));
      expect(mid.rect.width, greaterThan(button.width), reason: '좁혀 오는 중');

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 100));
      final end = holeNow(tester)!;
      expect(end.rect.left, closeTo(button.left, 0.01), reason: '끝은 정확히 제자리');
      expect(end.rect.right, closeTo(button.right, 0.01));
      expect(end.rect.top, closeTo(button.top, 0.01));
      expect(end.rect.bottom, closeTo(button.bottom, 0.01));
    });

    testWidgets('단계 이동: 구멍이 순간이동하지 않고 같은 방향으로 미끄러져 도착한다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      final start = holeNow(tester)!.rect;

      await tester.tapAt(const Offset(200, 760));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16)); // 이동 시작
      final samples = <double>[];
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        samples.add(holeNow(tester)!.rect.top);
      }
      await tester.pump(const Duration(milliseconds: 700));
      final end = holeNow(tester)!.rect;

      expect(end.top, isNot(closeTo(start.top, 1)), reason: '다른 줄로 옮겨 갔다');
      final goingDown = end.top > start.top;
      // 같은 방향으로만 가고(되돌아오지 않고), 첫 프레임에 도착해 있지도 않다
      for (var i = 1; i < samples.length; i++) {
        expect(goingDown ? samples[i] >= samples[i - 1] : samples[i] <= samples[i - 1], isTrue,
            reason: '뒷걸음질·출렁임이 없어야 한다: $samples');
      }
      expect((samples.first - end.top).abs(), greaterThan(1), reason: '순간이동하지 않는다');
      expect(end.top, closeTo(tester.getRect(find.byType(RoutineSwipeActions)).top, 0.01));
    });

    testWidgets('말풍선은 겹쳐 바뀐다 — 옛 글이 사라지는 동안 새 글이 나타난다', (tester) async {
      await open(tester, wrap(today: [routine('a', '손 씻기')]));

      await tester.tapAt(const Offset(200, 760));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16)); // 새 글이 막 붙는다
      await tester.pump(const Duration(milliseconds: 100));

      expect(message('수행할'), findsOneWidget, reason: '옛 글이 아직 남아 사라지는 중');
      expect(message('스와이프'), findsOneWidget, reason: '새 글이 나타나는 중');

      await tester.pump(const Duration(milliseconds: 700));
      expect(message('수행할'), findsNothing);
    });

    testWidgets('닫을 때 막이 걷히는 동안은 남아 있다가 사라진다', (tester) async {
      await open(tester, wrap());
      await tapAnywhere(tester);
      await tester.tapAt(const Offset(200, 760));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(overlay, findsOneWidget, reason: '한 프레임에 사라지지 않는다');
      expect(scrimAlpha(tester), lessThan(0.75));

      await tester.pump(const Duration(milliseconds: 400));
      expect(overlay, findsNothing);
    });
  });

  group('접근성 · 큰 글자 · 동작 줄이기', () {
    testWidgets('글자를 크게 키워도 말풍선이 화면 안에 있다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      const screen = Rect.fromLTWH(0, 0, 393, 852);
      for (var i = 0; i < 3; i++) {
        final text = tester.getRect(message(['수행할', '스와이프', '이룸이모드'][i]));
        expect(screen.contains(text.topLeft) && screen.contains(text.bottomRight), isTrue,
            reason: '${i + 1}단계 글이 화면 밖으로 나갔다: $text');
        if (i < 2) await tapAnywhere(tester);
      }
    });

    testWidgets('동작 줄이기를 켜도 모든 단계가 똑같이 동작한다', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await open(tester, wrap(today: [routine('a', '손 씻기')]));
      expect(message('수행할'), findsOneWidget);
      await tapAnywhere(tester);
      expect(message('스와이프'), findsOneWidget);
      await tapAnywhere(tester);
      expect(message('이룸이모드'), findsOneWidget);
      await tapAnywhere(tester);
      expect(overlay, findsNothing);
    });

    testWidgets('화면 낭독기에 단계와 문구, 닫기 버튼이 읽힌다', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, wrap(today: [routine('a', '손 씻기')]));

      expect(find.bySemanticsLabel(RegExp(r'안내 1/3\..*수행할')), findsOneWidget);
      expect(find.bySemanticsLabel('안내 닫기'), findsOneWidget);
      handle.dispose();
    });
  });

  group('CoachMarkOverlay 단독', () {
    testWidgets('가리킬 대상을 잴 수 없으면 그 단계를 건너뛴다', (tester) async {
      final ghost = GlobalKey();
      final real = GlobalKey();
      var index = 0;
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StatefulBuilder(
            builder: (context, setState) => ScreenUtilInit(
              designSize: const Size(393, 852),
              builder: (context, _) => Stack(
                children: [
                  Center(child: SizedBox(key: real, width: 100, height: 50)),
                  // ghost 는 어디에도 달려 있지 않다
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: CoachMarkOverlay(
                        steps: [
                          CoachMarkStep(target: ghost, message: '없는 곳'),
                          CoachMarkStep(target: real, message: '있는 곳'),
                        ],
                        index: index,
                        visible: !closed,
                        onNext: () => setState(() => index++),
                        onClose: () => setState(() => closed = true),
                        onDismissed: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));

      expect(index, 1, reason: '못 잰 첫 단계는 건너뛰고');
      expect(find.textContaining('있는 곳', findRichText: true), findsOneWidget);
      expect(find.textContaining('없는 곳', findRichText: true), findsNothing);
    });

    test('강조 표시는 줄바꿈을 넘어 이어진다', () {
      final spans = coachMessageSpans(
        '이룸이가 수행할 *새로운\n일과를 만들 수 있어요*',
        base: const TextStyle(color: Color(0xFFFFFFFF)),
        accent: const TextStyle(color: Color(0xFF55CFBA)),
      );

      expect(spans.length, 2);
      expect(spans[0].text, '이룸이가 수행할 ');
      expect(spans[1].text, '새로운\n일과를 만들 수 있어요');
      expect(spans[1].style?.color, const Color(0xFF55CFBA));
    });
  });
}

/// 화면에 그려진 한 점의 색(0~1).
Future<Color> _pixel(WidgetTester tester, GlobalKey key, Offset at) async {
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = (at.dy.round() * image.width + at.dx.round()) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }))!;
}

/// 말풍선의 점선 화살표 위치.
Rect _arrowRect(WidgetTester tester) =>
    tester.getRect(svgWithAsset(AppAssets.coachArrow));

/// 저장을 못 하는 저장소 — 디스크가 가득 찼을 때.
class _WriteFailingStorage extends InMemoryStorage {
  _WriteFailingStorage()
    : super(onboardingCompleted: true, nickname: '하늘이', homeCoachSeen: false);

  @override
  Future<void> setHomeCoachSeen(bool v) async => throw StateError('저장 실패');
}

/// 읽지 못하는 저장소.
class _ReadFailingStorage extends InMemoryStorage {
  _ReadFailingStorage()
    : super(onboardingCompleted: true, nickname: '하늘이', homeCoachSeen: false);

  @override
  bool get isHomeCoachSeen => throw StateError('읽기 실패');
}

class _FakeRepo with FakeRewardApi implements RoutineRepository {
  _FakeRepo({required this.today, this.todayFails = false});

  final List<Routine> today;
  final bool todayFails;

  @override
  Future<List<Routine>> getMyRoutines() async => today;

  @override
  Future<List<Routine>> getTodayRoutines() async {
    if (todayFails) throw Exception('서버에 닿지 못했어요');
    return today;
  }

  @override
  Future<List<Routine>> getPastRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];

  @override
  Future<AppFailure?> delete(String routineId) async => null;

  @override
  Future<AppFailure?> reorder(List<String> routineIds) async => null;

  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async =>
      const RoutineQuestion();

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
    String rewardText = '',
    String rewardPresetKey = '',
    String idempotencyKey = '',
  }) async => const Routine(id: 'new');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async => null;

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async => (routine: routine, failure: null);
}
