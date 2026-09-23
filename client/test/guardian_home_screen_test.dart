import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_detail_sheet.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_summary_tile.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_swipe_actions.dart';
import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// Figma `보호자_홈` 개편(931:3896 기본 / 931:4179 밀림 / 931:4879 삭제) 정합 테스트.
///
/// 개편으로 홈이 **오늘 일과 · 지난 일과 두 칸**이 됐다. 추천 일과가 빠졌고,
/// 접기/펼치기 대신 밀어서 삭제·수정 · 손잡이로 순서 바꾸기가 들어왔다.
void main() {
  // Figma 실측값(68 · 105 · 40)을 그대로 검증하려면 뷰포트가 기기와 같아야 한다.
  useFigmaViewport();

  late _FakeRoutineRepo repo;

  Widget wrap({
    List<Routine> routines = const [],
    List<Routine> past = const [],
    List<Routine>? today,
    Member? member,
  }) {
    repo = _FakeRoutineRepo(routines: routines, past: past, today: today);

    final router = GoRouter(
      initialLocation: Routes.guardian,
      routes: [
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const GuardianHomeScreen(),
        ),
        GoRoute(
          path: Routes.routineInput,
          builder: (context, state) => const Scaffold(body: Text('일과 입력')),
        ),
        GoRoute(
          path: Routes.routineReview,
          builder: (context, state) => const Scaffold(body: Text('카드 검토')),
        ),
        GoRoute(
          path: Routes.guardianSettings,
          builder: (context, state) => const Scaffold(body: Text('설정 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        // 실서버를 타지 않는다. 목록 조회도 삭제·순서도 이 fake가 받는다.
        routineRepositoryProvider.overrideWithValue(repo),
        memberProvider.overrideWith((ref) async => member),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  /// 카드 [cards]장을 가진 일과.
  Routine routine(
    String title,
    int cards, {
    String reward = '',
    int percent = 0,
    DateTime? at,
  }) => Routine(
    id: title,
    title: title,
    rewardText: reward,
    progressPercent: percent,
    scheduledAt: at,
    steps: [
      for (var i = 0; i < cards; i++)
        ActionCard(
          id: '$title-$i',
          title: '카드 ${i + 1} 제목',
          description: '카드 ${i + 1} 설명',
          stepOrder: i + 1,
        ),
    ],
  );

  /// [title] 카드 뒤에 깔린 동작 버튼의 아이콘.
  Finder actionIn(String title, String asset) => find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byType(RoutineSwipeActions),
    ),
    matching: svgWithAsset(asset),
  );

  /// 얼마나 드러났는가(0~1).
  ///
  /// 버튼은 **늘 카드 뒤에 있다** — 카드가 비켜나며 그림이 살아날 뿐이라
  /// `findsNothing`으로는 닫힘을 확인할 수 없다.
  double revealOf(WidgetTester tester, Finder icon) {
    final opacity = find.ancestor(of: icon, matching: find.byType(Opacity));
    return tester.widget<Opacity>(opacity.first).opacity;
  }

  group('오늘 일과는 오늘 것만 보여준다 (이슈 #353)', () {
    testWidgets('전체 목록이 아니라 오늘 목록을 본다', (tester) async {
      // 서버는 `/today` 로 **오늘 것만** 준다 — 어제 것도, 아직 이룸이에게
      // 보내지 않은 것(`PENDING_REVIEW`)도 빼고. 홈이 전체 목록을 보고 있어서
      // 그 둘이 오늘 할 일에 섞여 있었고, 실기기에서 같은 일과가 오늘과 지난에
      // 동시에 떴다 (#353).
      await tester.pumpWidget(wrap(
        routines: [routine('오늘 할 일', 2), routine('어제 것', 2), routine('승인 전', 2)],
        today: [routine('오늘 할 일', 2)],
      ));
      await tester.pumpAndSettle();

      expect(find.text('오늘 할 일'), findsOneWidget);
      expect(find.text('어제 것'), findsNothing,
          reason: '날짜가 지난 일과가 오늘 할 일에 남으면 초기화가 안 된 것이다');
      expect(find.text('승인 전'), findsNothing,
          reason: '이룸이 화면에 없는 것이 보호자 오늘 할 일에 있으면 둘이 어긋난다');
    });

    testWidgets('이룸이 홈과 같은 목록을 본다', (tester) async {
      // 보호자가 "오늘 할 일"로 믿는 것과 이룸이 화면에 뜨는 것이 같아야 한다.
      // 둘 다 `todayRoutinesProvider` 를 본다.
      await tester.pumpWidget(wrap(
        routines: [routine('가', 2), routine('나', 2)],
        today: [routine('가', 2)],
      ));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GuardianHomeScreen)),
      );
      final today = await container.read(todayRoutinesProvider.future);
      expect(today.map((r) => r.title), ['가']);
    });
  });

  group('보호자_홈 구성', () {
    testWidgets('Figma 섹션 문구가 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('오늘 일과'), findsOneWidget);
      expect(find.text('지난 일과'), findsOneWidget);
      expect(find.text('새로운 일과 만들기'), findsOneWidget);
      expect(find.text('오늘은 어떤 일과를 준비할까요?'), findsOneWidget);
    });

    testWidgets('추천 일과가 더는 없다', (tester) async {
      // 자리를 많이 쓰는 데 비해 눌리지 않아 지난 일과에 자리를 내줬다.
      // 되살리려면 디자인부터 다시 정해야 하므로 여기서 막는다.
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('추천 일과'), findsNothing);
    });

    testWidgets('하단 고정 CTA가 없다', (tester) async {
      // 만들기 버튼이 본문 알약으로 올라와 있다. 하단 버튼을 다시 붙이면 막는다.
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(ElumButton), findsNothing);
    });

    testWidgets('아이콘을 코드로 그리지 않고 SVG 에셋으로 렌더링한다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.homeLogo), findsOneWidget);
      // 캐릭터 배지는 헤더 하나뿐이다 — 개편 시안에서 빈 상태의 배지가 빠졌다
      expect(
        svgWithAsset(AppAssets.characterBadgeFramed(CardCharacter.cat)),
        findsOneWidget,
      );
      expect(svgWithAsset(AppAssets.iconTodayRoutine), findsOneWidget);
      expect(svgWithAsset(AppAssets.iconTimePast), findsOneWidget);
      // 만들기 버튼의 반짝임
      expect(svgWithAsset(AppAssets.iconSparkles), findsOneWidget);
    });

    testWidgets('서버 호칭이 있으면 인사말에 쓴다', (tester) async {
      await tester.pumpWidget(wrap(member: const Member(nickname: '하늘이')));
      await tester.pumpAndSettle();

      expect(find.text('안녕하세요,\n하늘이 보호자님 👋🏻'), findsOneWidget);
    });

    testWidgets('서버 조회가 비어도 화면이 뜬다', (tester) async {
      // 서버가 죽어도 홈은 떠야 한다 (docs 원칙 6번)
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('오늘 일과'), findsOneWidget);
    });
  });

  group('오늘 일과', () {
    testWidgets('0건이면 Figma 빈 상태를 보여준다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('아직 만든 일과가 없어요'), findsOneWidget);
      expect(find.text('지난 일과가 없어요'), findsOneWidget);
    });

    testWidgets('제목과 보상이 한 줄 요약으로 보인다', (tester) async {
      await tester.pumpWidget(
        wrap(
          routines: [
            routine('스스로 옷을 입어요', 5, reward: '유튜브 시청 20분'),
            routine('밥 먹기 전에 손을 씻어요', 3),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('스스로 옷을 입어요'), findsOneWidget);
      expect(find.text('밥 먹기 전에 손을 씻어요'), findsOneWidget);
      expect(find.text('완료 시'), findsOneWidget);
      expect(find.text('유튜브 시청 20분'), findsOneWidget);
      // 펼치기가 없어졌다 — 카드 목록은 수정 화면에서 본다
      expect(find.text('카드 1 제목'), findsNothing);
    });

    testWidgets('보상이 없으면 `완료 시` 줄 자체가 없다', (tester) async {
      // 안 정한 자리를 비워두면 하다 만 것처럼 보인다
      await tester.pumpWidget(wrap(routines: [routine('손 씻기', 2)]));
      await tester.pumpAndSettle();

      expect(find.text('완료 시'), findsNothing);
    });

    testWidgets('탭하면 먼저 시트로 보여준다 (이슈 #266)', (tester) async {
      // 예전에는 곧바로 편집 화면으로 넘어갔다. 보호자가 훨씬 자주 하는 일은
      // "오늘 어디까지 했나"를 보는 것이라, 확인은 시트에서 가볍게 한다.
      await tester.pumpWidget(wrap(routines: [routine('손 씻기', 2)]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('손 씻기'));
      await tester.pumpAndSettle();

      expect(find.byType(RoutineDetailSheet), findsOneWidget);
      expect(find.text('카드 검토'), findsNothing, reason: '아직 편집 화면이 아니다');
    });

    testWidgets('시트의 편집하기를 눌러야 수정 화면으로 간다 (이슈 #266)', (tester) async {
      await tester.pumpWidget(wrap(routines: [routine('손 씻기', 2)]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('손 씻기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('편집하기'));
      await tester.pumpAndSettle();

      expect(find.text('카드 검토'), findsOneWidget);
      // 시트를 닫고 가야 뒤로가기 한 번에 홈으로 나온다.
      expect(find.byType(RoutineDetailSheet), findsNothing);
    });

    testWidgets('title이 비어 와도 대체 제목으로 뜬다', (tester) async {
      // AI가 title을 못 만들어도 화면이 비지 않는다 (docs 원칙 6번)
      await tester.pumpWidget(
        wrap(
          routines: [
            const Routine(
              id: 'r',
              steps: [ActionCard(id: 'a', description: '설명만 있는 카드')],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('오늘의 일과'), findsOneWidget);
    });

    // 시안(931:3896)에서 손잡이가 빠졌다. 홈에서는 줄을 밀어 편집·삭제하고,
    // 순서는 줄을 눌러 여는 시트에서 바꾼다. 손잡이를 그리면 그만큼 링이
    // 왼쪽으로 밀려 시안과 어긋난다 (#297).
    testWidgets('줄에 순서 바꾸기 손잡이를 그리지 않는다', (tester) async {
      await tester.pumpWidget(
        wrap(routines: [routine('하나', 1), routine('둘', 1)]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RoutineDragHandle), findsNothing);
    });

    testWidgets('지난 일과에는 손잡이가 없다', (tester) async {
      // 지나간 것의 순서는 날짜가 정한다
      await tester.pumpWidget(wrap(past: [routine('어제 한 일', 1)]));
      await tester.pumpAndSettle();

      expect(find.byType(RoutineDragHandle), findsNothing);
    });
  });

  group('밀어서 삭제·수정 (Figma 931:4179)', () {
    testWidgets('밀면 삭제·수정 버튼이 드러난다', (tester) async {
      await tester.pumpWidget(wrap(routines: [routine('손 씻기', 2)]));
      await tester.pumpAndSettle();

      expect(revealOf(tester, actionIn('손 씻기', AppAssets.iconTrash)), 0);

      await tester.drag(find.text('손 씻기'), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(revealOf(tester, actionIn('손 씻기', AppAssets.iconTrash)), 1);
      expect(revealOf(tester, actionIn('손 씻기', AppAssets.iconPencil)), 1);
    });

    testWidgets('삭제를 누르면 확인부터 묻는다', (tester) async {
      await tester.pumpWidget(wrap(routines: [routine('손 씻기', 2)]));
      await tester.pumpAndSettle();

      await tester.drag(find.text('손 씻기'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(svgWithAsset(AppAssets.iconTrash));
      await tester.pumpAndSettle();

      expect(find.text('일과를 삭제하실건가요?'), findsOneWidget);

      // 취소하면 아무 일도 일어나지 않는다 — 되돌릴 수 없는 동작이다
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(find.text('손 씻기'), findsOneWidget);
    });

    testWidgets('확인하면 서버에 삭제를 보낸다', (tester) async {
      await tester.pumpWidget(wrap(routines: [routine('손 씻기', 2)]));
      await tester.pumpAndSettle();

      await tester.drag(find.text('손 씻기'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(svgWithAsset(AppAssets.iconTrash));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      expect(repo.deleted, ['손 씻기']);
    });

    testWidgets('수정을 누르면 그 일과가 검토 화면으로 올라간다', (tester) async {
      await tester.pumpWidget(wrap(routines: [routine('손 씻기', 2)]));
      await tester.pumpAndSettle();

      await tester.drag(find.text('손 씻기'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(svgWithAsset(AppAssets.iconPencil));
      await tester.pumpAndSettle();

      expect(find.text('카드 검토'), findsOneWidget);
    });

    testWidgets('한 번에 하나만 열린다', (tester) async {
      await tester.pumpWidget(
        wrap(routines: [routine('하나', 1), routine('둘', 1)]),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('하나'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(revealOf(tester, actionIn('하나', AppAssets.iconTrash)), 1);

      await tester.drag(find.text('둘'), const Offset(-200, 0));
      await tester.pumpAndSettle();

      // 둘이 동시에 열리면 어느 버튼이 누구 것인지 알 수 없다
      expect(revealOf(tester, actionIn('둘', AppAssets.iconTrash)), 1);
      expect(revealOf(tester, actionIn('하나', AppAssets.iconTrash)), 0);
    });

    testWidgets('지난 일과는 밀리지 않는다', (tester) async {
      await tester.pumpWidget(wrap(past: [routine('어제 한 일', 1)]));
      await tester.pumpAndSettle();

      await tester.drag(find.text('어제 한 일'), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.iconTrash), findsNothing);
    });
  });

  group('지난 일과 (Figma 931:3896)', () {
    // 시안(931:3896)에서 날짜 줄이 빠졌다 — 지난 일과도 오늘과 같은 68 짜리 줄이다.
    testWidgets('줄에 날짜를 붙이지 않는다', (tester) async {
      await tester.pumpWidget(
        wrap(
          past: [
            routine('학교에 갈 준비를 해요', 3, percent: 100, at: DateTime(2026, 9, 20)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026년 9월 20일'), findsNothing);
    });

    testWidgets('날짜가 안 오면 그 줄만 빠지고 화면은 뜬다', (tester) async {
      await tester.pumpWidget(wrap(past: [routine('학교 가기', 3, percent: 100)]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('학교 가기'), findsOneWidget);
    });

    // 시안(931:3896)에서 줄에 붙던 날짜와 `일과 다시하기`가 빠졌다.
    // 지난 일과도 오늘 일과와 같은 68 짜리 줄이고, 다시하기는 줄을 눌러
    // 여는 시트 안으로 들어갔다 (#310).
    testWidgets('줄에는 다시하기가 붙지 않는다', (tester) async {
      await tester.pumpWidget(
        wrap(
          past: [
            routine('끝낸 일과', 2, percent: 100),
            routine('하다 만 일과', 2, percent: 50),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('일과 다시하기'), findsNothing);
    });

    testWidgets('줄을 눌러 연 시트에서 다시하기를 누르면 복제를 요청한다', (tester) async {
      await tester.pumpWidget(wrap(past: [routine('끝낸 일과', 2, percent: 100)]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('끝낸 일과'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일과 다시하기'));
      await tester.pumpAndSettle();

      expect(repo.duplicated, ['끝낸 일과']);
    });
  });

  group('새로운 일과 만들기', () {
    testWidgets('누르면 입력 화면으로 간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('새로운 일과 만들기'));
      await tester.pumpAndSettle();

      expect(find.text('일과 입력'), findsOneWidget);
    });
  });

  testWidgets('설정 진입점이 있고 누르면 설정으로 간다 (#181)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 로그아웃할 방법이 없어 계정을 바꿀 수 없던 문제라, 진입점 자체가 계약이다.
    // 시안 톱니는 Material 아이콘과 모양이 달라 SVG 에셋으로 그린다.
    final gear = svgWithAsset(AppAssets.iconSettings);
    expect(gear, findsOneWidget);

    await tester.tap(gear);
    await tester.pumpAndSettle();

    expect(find.text('설정 화면'), findsOneWidget);
  });

  testWidgets('설정에서 뒤로가기로 홈에 돌아온다 (이슈 #194)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(svgWithAsset(AppAssets.iconSettings));
    await tester.pumpAndSettle();
    expect(find.text('설정 화면'), findsOneWidget);

    // 기기 뒤로가기. go로 열면 스택이 교체돼 여기서 아무 일도 일어나지 않는다.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('설정 화면'), findsNothing);
    expect(
      svgWithAsset(AppAssets.iconSettings),
      findsOneWidget,
      reason: '홈으로 돌아와야 톱니가 다시 보인다',
    );
  });

  group('추천 문구 폴백 (서버 #39 배포 전 호환)', () {
    test('입력창에는 라벨이 아니라 자연어 문장이 들어간다', () {
      const s = RoutineSuggestion(
        icon: '☔️',
        text: '비 오는 날 등교',
        prompt: '비 오는 날 우산 챙겨서 학교 가는 준비를 하고 싶어요',
      );
      expect(s.inputText, s.prompt);
      expect(s.inputText, isNot(s.text));
    });

    test('서버가 prompt를 안 주면 라벨로 폴백한다', () {
      const s = RoutineSuggestion(icon: '☔️', text: '비 오는 날 등교');
      expect(s.inputText, '비 오는 날 등교');
    });
  });
}

/// 홈이 부르는 것만 받는 저장소. 삭제·순서·복제는 **보냈는지**를 기록한다.
class _FakeRoutineRepo with FakeRewardApi implements RoutineRepository {
  _FakeRoutineRepo({required this.routines, required this.past, this.today});

  final List<Routine> routines;
  final List<Routine> past;

  /// `/api/routines/today` 가 주는 것. null 이면 전체와 같다고 본다.
  final List<Routine>? today;

  final deleted = <String>[];
  final duplicated = <String>[];
  final reordered = <List<String>>[];

  @override
  Future<List<Routine>> getMyRoutines() async => routines;

  @override
  // **전체 목록과 따로 준다.** 서버가 `/today` 와 `/api/routines` 를 다르게
  // 주는데 fake 가 같은 값을 주면, 홈이 어느 쪽을 보는지 테스트가 구분하지
  // 못한다 — 실제로 그래서 #353 이 테스트를 통과한 채 배포됐다.
  Future<List<Routine>> getTodayRoutines() async => today ?? routines;

  @override
  Future<List<Routine>> getPastRoutines() async => past;

  @override
  Future<AppFailure?> delete(String routineId) async {
    deleted.add(routineId);
    return null;
  }

  @override
  Future<Attempt<Routine>> duplicate(String routineId) async {
    duplicated.add(routineId);
    return Attempt.ok(routines.isEmpty ? past.first : routines.first);
  }

  @override
  Future<AppFailure?> reorder(List<String> routineIds) async {
    reordered.add(routineIds);
    return null;
  }

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];

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
  }) async => const Routine(id: 'new');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async => (routine: routine, failure: null);
}
