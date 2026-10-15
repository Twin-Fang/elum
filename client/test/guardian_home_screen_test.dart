import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_error_view.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_detail_sheet.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_swipe_actions.dart';
import 'package:elum/shared/models/support_goal.dart';
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
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';

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
    bool todayFails = false,
  }) {
    repo = _FakeRoutineRepo(
      routines: routines,
      past: past,
      today: today,
      todayFails: todayFails,
    );

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



  group('오늘 일과', () {

    testWidgets('못 불러오면 실패를 로딩·빈 상태와 같은 회색 칸 안에 보인다', (tester) async {
      await tester.pumpWidget(wrap(todayFails: true));
      await tester.pumpAndSettle();

      final error = find.byType(ElumErrorView);
      expect(error, findsOneWidget);
      // 칸은 일과 줄과 같은 바탕색의 상자다.
      final shell = find.ancestor(
        of: error,
        matching: find.byWidgetPredicate(
          (w) =>
              w is AnimatedContainer &&
              (w.decoration as BoxDecoration?)?.color ==
                  AppColors.light.routineTileBg,
        ),
      );
      expect(shell, findsOneWidget);
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



    // 시안(931:3896)에서 손잡이가 빠졌다. 홈에서는 줄을 밀어 편집·삭제하고,
    // 순서는 줄을 눌러 여는 시트에서 바꾼다. 손잡이를 그리면 그만큼 링이
    // 왼쪽으로 밀려 시안과 어긋난다 (#297).

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




  });

  group('지난 일과 (Figma 931:3896)', () {
    // 시안(931:3896)에서 날짜 줄이 빠졌다 — 지난 일과도 오늘과 같은 68 짜리 줄이다.


    // 시안(931:3896)에서 줄에 붙던 날짜와 `일과 다시하기`가 빠졌다.
    // 지난 일과도 오늘 일과와 같은 68 짜리 줄이고, 다시하기는 줄을 눌러
    // 여는 시트 안으로 들어갔다 (#310).

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





}

/// 홈이 부르는 것만 받는 저장소. 삭제·순서·복제는 **보냈는지**를 기록한다.
class _FakeRoutineRepo with FakeRewardApi implements RoutineRepository {
  // 카드확인 카드 추가 (#444) — 이 테스트는 쓰지 않는다
  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
  _FakeRoutineRepo({
    required this.routines,
    required this.past,
    this.today,
    this.todayFails = false,
  });

  /// 오늘 목록 조회가 실패한다 (연결 끊김 등).
  final bool todayFails;

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
  Future<List<Routine>> getTodayRoutines() async {
    if (todayFails) throw Exception('오늘 목록 조회 실패');
    return today ?? routines;
  }

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
    String idempotencyKey = '',
  }) async => const Routine(id: 'new');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async =>
      null;

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
}
