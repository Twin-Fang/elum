import 'dart:math';

import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/app_shake.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/domain/reward_character.dart';
import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/child_stars_screen.dart';
import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/card_palette.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/semantics_audit.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

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
        testStorageOverride(onboardingCompleted: true, pin: pin),
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
    testWidgets('일과 제목이 목록 타일로 보인다', (tester) async {
      await pumpChild(tester);

      expect(find.text('비 오는 날 학교에 가요'), findsOneWidget);
      // 카드 내용은 상세로 들어가기 전에는 보이지 않는다
      expect(find.text('옷을 입어요'), findsNothing);
    });

    testWidgets('타일을 탭하면 카드 상세로 들어간다', (tester) async {
      await pumpChild(tester);

      await tester.tap(find.text('비 오는 날 학교에 가요'));
      await tester.pumpAndSettle();

      expect(find.text('옷을 입어요'), findsOneWidget);
      expect(find.text('학교에 갈 옷을 차례대로 입어요'), findsOneWidget);
    });

    testWidgets('승인 전 일과는 목록에 없다', (tester) async {
      // 보호자 승인 전에는 아동에게 노출하지 않는다 (docs 원칙 3번)
      await pumpChild(tester, status: 'PENDING_REVIEW');

      expect(find.text('비 오는 날 학교에 가요'), findsNothing);
      expect(find.textContaining('일과가 없어요'), findsOneWidget);
    });

    testWidgets('체크 버튼이 아동 최소 터치 타겟을 넘는다', (tester) async {
      // 아동 모드는 64×64 이상이어야 한다 (CLAUDE.md)
      expect(
        ChildRoutineDetailScreen.checkButtonSize,
        greaterThanOrEqualTo(64),
      );
    });

    testWidgets('일과가 없으면 빈 상태를 보여준다', (tester) async {
      await tester.pumpWidget(wrap(const ChildHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('일과가 없어요'), findsOneWidget);
      expect(find.text('보호자 화면에서 일과를 만들 수 있어요'), findsOneWidget);
      // 시무룩한 루루는 코드가 아니라 에셋으로 그린다
      expect(svgWithAsset(AppAssets.ruruSad), findsOneWidget);
    });

    testWidgets('별 배지가 보이고 탭하면 별 화면으로 간다', (tester) async {
      await pumpChild(tester);

      expect(svgWithAsset(AppAssets.starBadge), findsOneWidget);

      await tester.tap(
        find
            .ancestor(
              of: svgWithAsset(AppAssets.starBadge),
              matching: find.byType(AppPressable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.text('별 화면'), findsOneWidget);
    });

    testWidgets('캐릭터 배지는 테두리가 있는 에셋을 쓴다', (tester) async {
      // 테두리 없는 맨 일러스트(characterBadgeRuru)를 쓰면 캐릭터만 덩그러니
      // 뜬다. Figma 356:5106은 둥근 사각형 테두리까지 포함한다.
      await pumpChild(tester);

      expect(
        svgWithAsset(AppAssets.characterBadgeFramed(CardCharacter.cat)),
        findsOneWidget,
      );
    });
  });

  group('보상 조건', () {
    // 서버에 없는 로컬 일과 — 동기화 없이 토글 규칙만 본다.
    const local = Routine(id: 'local', status: 'CONFIRMED', steps: cards);
    final c1 = cards[0];
    final c2 = cards[1];

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

    test('해제해도 보상 이력은 남는다', () {
      final container = ProviderContainer(overrides: [testStorageOverride()]);
      addTearDown(container.dispose);

      final notifier = container.read(childRoutineProvider.notifier);
      notifier
        ..toggle(routine: local, card: c1)
        ..toggle(routine: local, card: c1);

      final state = container.read(childRoutineProvider);
      expect(state.isChecked('local', c1), isFalse);
      expect(state.hasRewarded('local', 'c1'), isTrue);
    });

    test('카드마다 따로 보상한다', () {
      final container = ProviderContainer(overrides: [testStorageOverride()]);
      addTearDown(container.dispose);

      final notifier = container.read(childRoutineProvider.notifier);

      expect(notifier.toggle(routine: local, card: c1), isTrue);
      expect(notifier.toggle(routine: local, card: c2), isTrue);
    });

    test('새 일과를 시작하면 초기화된다', () {
      final container = ProviderContainer(overrides: [testStorageOverride()]);
      addTearDown(container.dispose);

      final notifier = container.read(childRoutineProvider.notifier)
        ..toggle(routine: local, card: c1)
        ..reset();

      expect(container.read(childRoutineProvider).progress, isEmpty);
      // 초기화 후에는 다시 보상을 받을 수 있다
      expect(notifier.toggle(routine: local, card: c1), isTrue);
    });
  });

  group('보상 캐릭터', () {
    test('세 캐릭터가 모두 나올 수 있다', () {
      final seen = <RewardCharacter>{};
      for (var seed = 0; seed < 50; seed++) {
        seen.add(RewardCharacter.pick(Random(seed)));
      }

      expect(seen.length, RewardCharacter.values.length);
    });

    test('캐릭터마다 문구가 다르다', () {
      final messages = RewardCharacter.values
          .map((c) => c.messageFor('하늘이'))
          .toSet();

      expect(messages.length, RewardCharacter.values.length);
    });

    test('문구에 캐릭터 이름이 들어간다', () {
      expect(RewardCharacter.lumi.messageFor('하늘이'), contains('루미'));
      expect(RewardCharacter.popo.messageFor('하늘이'), contains('포포'));
      expect(RewardCharacter.ruru.messageFor('하늘이'), contains('루루'));
    });

    test('문구에 아이 이름이 들어간다 (Figma 309:4055 · 343:4434)', () {
      expect(
        RewardCharacter.lumi.messageFor('하늘이'),
        '할 일을 해내서 루미가\n하늘이에게 별을 가져왔어요',
      );
      expect(
        RewardCharacter.ruru.messageFor('하늘이'),
        '하늘이가 할 일을 해내서\n루루가 선물을 가져왔어요',
      );
      expect(
        RewardCharacter.popo.messageFor('하늘이'),
        '포포가 하늘이에게\n축하의 선물로 큰 별을 가져왔어요',
      );
    });

    test('이름이 비어도 조사만 남지 않는다', () {
      // 온보딩을 건너뛰었거나 서버 닉네임이 없을 때 `가 할 일을 해내서`가 되면 안 된다
      expect(RewardCharacter.ruru.messageFor(''), contains('이룸이가'));
      expect(RewardCharacter.ruru.messageFor('   '), contains('이룸이가'));
      expect(RewardCharacter.lumi.messageFor(''), contains('이룸이에게'));
    });

    test('버튼 문구가 캐릭터마다 다르다', () {
      // 세 프레임의 버튼 문구가 전부 다르다 — 하드코딩하면 안 된다
      expect(RewardCharacter.lumi.buttonLabel, '오예!'); // 309:4055
      expect(RewardCharacter.popo.buttonLabel, '좋아요!'); // 334:4320
      expect(RewardCharacter.ruru.buttonLabel, '신난다!'); // 343:4434

      final labels = RewardCharacter.values.map((c) => c.buttonLabel).toSet();
      expect(labels.length, RewardCharacter.values.length);
    });
  });

  group('보상 별 렌더링', () {
    // 예전에 `Icon(Icons.star_rounded)`로 그려서 Figma 그라데이션 별과
    // 모양이 달랐고, 위젯 테스트에서는 아이콘 폰트가 없어 네모로 나왔다.
    // 도형은 전부 에셋이어야 한다 (client/CLAUDE.md §2).

    // 보상 화면은 852 높이를 꽉 채운다. 기본 뷰포트(800×600)로 돌리면
    // 화면이 아니라 테스트 환경 때문에 오버플로가 난다.
    useFigmaViewport();

    // 별은 등장 후 둥둥 떠다니는 float 애니메이션이 무한 반복이라
    // pumpAndSettle이 끝나지 않는다. 등장 연출이 끝날 만큼만 pump한다.
    // **별은 PNG다.** 후광·그림자·안쪽 하이라이트가 전부 SVG `filter`인데
    // flutter_svg가 그것을 버려서, SVG로 두면 후광용 반투명 별이 흐려지지 않고
    // 그대로 깔려 별 둘레에 탁한 띠가 생긴다 (#297).
    testWidgets('큰 별을 에셋으로 렌더링한다', (tester) async {
      await tester.pumpWidget(wrap(const RewardScreen()));
      await tester.pump(const Duration(seconds: 1));

      expect(imageWithAsset(AppAssets.starBig), findsWidgets);
    });

    testWidgets('주변 작은 별도 에셋으로 렌더링한다', (tester) async {
      await tester.pumpWidget(wrap(const RewardScreen()));
      await tester.pump(const Duration(seconds: 1));

      // Figma 실측 — 초록(`334:4293`) · 보라(`334:4294`).
      // **별 모으기 화면의 `starDeco`가 아니다** — 그쪽 초록별은 40%만
      // 불투명해 어두운 보상 배경에서 시커멓게 죽는다 (#297).
      expect(imageWithAsset(AppAssets.rewardStarGreen), findsOneWidget);
      expect(imageWithAsset(AppAssets.rewardStarPurple), findsOneWidget);
    });

    testWidgets('별을 아이콘 글리프로 그리지 않는다', (tester) async {
      await tester.pumpWidget(wrap(const RewardScreen()));
      await tester.pump(const Duration(seconds: 1));

      final starIcons = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.star_rounded,
      );
      expect(starIcons, findsNothing);
    });
  });

  group('모드 전환 PIN', () {
    testWidgets('방향에 따라 문구가 다르다', (tester) async {
      await tester.pumpWidget(
        wrap(const ModeSwitchScreen(target: ModeSwitchTarget.child)),
      );
      await tester.pumpAndSettle();

      expect(find.text('암호를 입력하면 이룸이 화면으로 바뀌어요'), findsOneWidget);
    });

    testWidgets('보호자 방향 문구도 맞다', (tester) async {
      await tester.pumpWidget(
        wrap(const ModeSwitchScreen(target: ModeSwitchTarget.guardian)),
      );
      await tester.pumpAndSettle();

      expect(find.text('암호를 입력하면 보호자 화면으로 바뀌어요'), findsOneWidget);
    });

    testWidgets('PIN이 틀려도 경고색을 쓰지 않는다', (tester) async {
      // 아동도 보는 화면이다 (CLAUDE.md)
      await tester.pumpWidget(
        wrap(const ModeSwitchScreen(target: ModeSwitchTarget.guardian)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '9999');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(t.style?.color, isNot(Colors.red));
      }
    });

    test('모르는 방향이면 아이 화면으로 본다', () {
      expect(ModeSwitchTarget.fromName(null), ModeSwitchTarget.child);
      expect(ModeSwitchTarget.fromName('nonsense'), ModeSwitchTarget.child);
      expect(ModeSwitchTarget.fromName('guardian'), ModeSwitchTarget.guardian);
    });
  });

  group('아이 → 보호자 PIN 검증 (이슈 #61)', () {
    testWidgets('아이 홈에서 보호자로 가려면 PIN 화면을 거친다', (tester) async {
      // 배지를 눌러 곧장 보호자 홈으로 가면 아이가 혼자 빠져나갈 수 있다.
      await pumpChild(tester, pin: '1234');

      // 상단 오른쪽 캐릭터 배지가 보호자 모드로 나가는 유일한 입구다
      await tester.tap(
        find
            .ancestor(
              of: svgWithAsset(
                AppAssets.characterBadgeFramed(CardCharacter.cat),
              ),
              matching: find.byType(AppPressable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.text('암호를 입력하면 보호자 화면으로 바뀌어요'), findsOneWidget);
      expect(find.text('보호자 홈'), findsNothing, reason: 'PIN 없이 보호자 홈에 도달했다');
    });

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

    testWidgets('맞는 PIN이면 보호자 화면으로 넘어간다', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ModeSwitchScreen(target: ModeSwitchTarget.guardian),
          pin: '1234',
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsOneWidget);
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

    testWidgets('별 배지는 숫자만이 아니라 무엇의 개수인지 읽힌다', (tester) async {
      // 배지 안 글자는 `10` 하나뿐이다. 그대로 두면 화면 낭독기가 "10, 버튼"만
      // 읽어 무엇이 10인지 알 수 없었다.
      await pumpChild(tester, member: const Member(totalStars: 10));

      expectLabeledButton(tester, '별 10개 모았어요');
      expect(find.bySemanticsLabel('10'), findsNothing,
          reason: '숫자만 따로 한 번 더 읽히면 안 된다');
    });

    testWidgets('캐릭터 배지는 보호자 화면으로 가는 입구라고 읽힌다', (tester) async {
      await pumpChild(tester);

      expectLabeledButton(tester, '보호자 화면으로 가기');
    });

    testWidgets('이룸이 홈에 이름 없는 누름 자리가 없다', (tester) async {
      await pumpChild(tester, member: const Member(totalStars: 3));

      expect(unnamedTapTargets(tester), isEmpty);
    });

    testWidgets('일과 상세의 뒤로가기·듣기·다 했어요가 읽힌다', (tester) async {
      await pumpChild(tester);
      await tester.tap(find.text('비 오는 날 학교에 가요'));
      await tester.pumpAndSettle();

      expectLabeledButton(tester, '뒤로 가기');
      expectLabeledButton(tester, '다 했어요');
      // 스피커는 카드마다 하나씩 있다 — 옆 카드도 미리 그려 두므로 둘이다
      final speak = find.bySemanticsLabel('소리로 듣기');
      expect(speak, findsWidgets);
      expect(
        tester.getSemantics(speak.first),
        containsSemantics(isButton: true, hasTapAction: true),
      );
      expect(unnamedTapTargets(tester), isEmpty);
    });

    testWidgets('다 했어요 버튼은 눌렀는지도 함께 알린다', (tester) async {
      // 누를 때마다 켜고 끄는 버튼이다. 이름만 있으면 이미 했는지 알 수 없다.
      await pumpChild(tester);
      await tester.tap(find.text('비 오는 날 학교에 가요'));
      await tester.pumpAndSettle();

      final check = find.bySemanticsLabel('다 했어요');
      expect(
        tester.getSemantics(check),
        containsSemantics(hasCheckedState: true, isChecked: false),
      );

      await tester.tap(find.byKey(ChildRoutineDetailScreen.checkButtonKey));
      // 한 프레임만 — 조금 뒤 별 화면이 올라와 이 화면을 덮는다
      await tester.pump();

      expect(
        tester.getSemantics(check),
        containsSemantics(hasCheckedState: true, isChecked: true),
      );

      // 별 화면으로 넘어가는 대기 타이머를 흘려보낸다. 별 화면은 계속 움직여
      // pumpAndSettle 이 끝나지 않는다 (child_card_advance_test 와 같은 방식).
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('별 화면의 뒤로가기가 읽힌다', (tester) async {
      await tester.pumpWidget(wrap(const ChildStarsScreen()));
      await tester.pumpAndSettle();

      expectLabeledButton(tester, '뒤로 가기');
      expect(unnamedTapTargets(tester), isEmpty);
    });

    testWidgets('암호 점을 누르는 자리가 암호 넣기라고 읽힌다', (tester) async {
      // 실제 입력칸은 투명이라 화면 낭독기에 드러나지 않는다. 키보드를 여는
      // 길은 이 점 자리 하나뿐이다.
      await tester.pumpWidget(
        wrap(const ModeSwitchScreen(target: ModeSwitchTarget.guardian)),
      );
      await tester.pumpAndSettle();

      expectLabeledButton(tester, '암호 넣기');
      expect(unnamedTapTargets(tester), isEmpty);
    });
  });

  group('카드 색', () {
    test('순서마다 다른 색을 준다', () {
      expect(CardPalette.at(0).fill, isNot(CardPalette.at(1).fill));
    });

    test('카드가 많아도 범위를 넘지 않는다', () {
      // AI가 9장을 만든 적이 있다. 범위를 넘으면 화면이 죽는다.
      expect(() => CardPalette.at(20), returnsNormally);
      expect(CardPalette.at(CardPalette.length), CardPalette.at(0));
    });
  });
}
