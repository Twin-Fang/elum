@Tags(['golden'])
library;

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_stars_screen.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/precache_images.dart';
import 'helpers/test_storage.dart';

/// **시안 대조용** 렌더. 회귀 확인이 목적인 `*_golden_test.dart`와 다르다.
///
/// 여기서 만든 PNG는 `tool/figma_diff.py`가 `docs/figma/**`의 Figma export와
/// 픽셀로 맞대본다. 그래서 두 가지를 기기와 똑같이 맞춘다.
///
/// - **안전영역** — Figma 프레임은 상단 상태바 59, 하단 홈 인디케이터 21을
///   포함해 852로 그린다. 그 여백을 주지 않으면 본문이 59px 위로 떠서
///   모든 줄이 어긋난 것으로 나온다.
/// - **논리 크기 393×852** — `useFigmaViewport()`가 잡는다.
///
/// 상태바·홈 인디케이터 안의 내용(시계·배터리)은 앱이 그리지 않으므로
/// 비교 도구가 그 띠를 가린다.
void main() {
  useFigmaViewport();

  /// iPhone 16 실측 — 상단 59 · 하단 21
  const deviceInsets = EdgeInsets.only(top: 59, bottom: 21);

  Routine routine(
    String id,
    String title, {
    String reward = '',
    int percent = 0,
    DateTime? at,
  }) => Routine(
    id: id,
    title: title,
    status: 'CONFIRMED',
    rewardText: reward,
    progressPercent: percent,
    scheduledAt: at,
    steps: [
      ActionCard(
        id: 'c1',
        stepOrder: 1,
        description: '첫 단계',
        completed: percent >= 50,
      ),
      ActionCard(
        id: 'c2',
        stepOrder: 2,
        description: '둘째 단계',
        completed: percent >= 100,
      ),
    ],
  );

  /// 시트 대조용. 시안(956:4084)이 그린 네 단계를 그대로 담는다.
  /// 내용이 다르면 diff 가 통째로 붉어져 정작 봐야 할 어긋남이 묻힌다.
  Routine sheetRoutine() => Routine(
    id: 's1',
    title: '스스로 옷을 입어요',
    status: 'CONFIRMED',
    rewardText: '유튜브 시청 20분',
    progressPercent: 50,
    steps: const [
      ActionCard(
        id: 's-c1',
        stepOrder: 1,
        title: '옷을 골라요',
        description: '밖에 나갈 때 입을 옷을 꺼내요',
        completed: true,
      ),
      ActionCard(
        id: 's-c2',
        stepOrder: 2,
        title: '바지를 입어요',
        description: '양쪽 다리를 넣고 바지를 올려 입어요',
        completed: true,
      ),
      ActionCard(
        id: 's-c3',
        stepOrder: 3,
        title: '윗옷을 입어요',
        description: '머리와 팔을 넣어 윗옷을 입어요',
      ),
      ActionCard(
        id: 's-c4',
        stepOrder: 4,
        title: '양말을 신어요',
        description: '양쪽 발에 양말을 신어요',
      ),
    ],
  );

  /// 지난 일과 시트 대조용. 시안(980:4777)이 그린 여덟 단계를 그대로 담는다.
  /// 앞 넷이 채워지고 뒤 넷이 비어 있다 — 체크 두 모양을 한 화면에서 본다.
  Routine pastSheetRoutine() => Routine(
    id: 'p1',
    title: '밥 먹기 전에 손을 씻어요',
    status: 'CONFIRMED',
    rewardText: '거실에서 저녁 먹기',
    progressPercent: 50,
    steps: const [
      ActionCard(
        id: 'p-1',
        stepOrder: 1,
        title: '세면대로 가요',
        description: '손을 씻으러 세면대 앞으로 걸어가요',
        completed: true,
      ),
      ActionCard(
        id: 'p-2',
        stepOrder: 2,
        title: '물을 틀어요',
        description: '수도꼭지를 올려 물이 나오게 해요',
        completed: true,
      ),
      ActionCard(
        id: 'p-3',
        stepOrder: 3,
        title: '손에 물을 묻혀요',
        description: '흐르는 물에 두손을 넣어 물을 묻혀요',
        completed: true,
      ),
      ActionCard(
        id: 'p-4',
        stepOrder: 4,
        title: '비누에 손을 묻혀요',
        description: '비누를 손으로 잡고 문질러 거품을 만들어요',
        completed: true,
      ),
      ActionCard(
        id: 'p-5',
        stepOrder: 5,
        title: '손을 문질러 닦아요',
        description: '손바닥과 손등을 비비며 구석구석 문질러요',
      ),
      ActionCard(
        id: 'p-6',
        stepOrder: 6,
        title: '물로 비누를 씻어내요',
        description: '흐르는 물에 손을 대어 비누 거품을 모두 씻어요',
      ),
      ActionCard(
        id: 'p-7',
        stepOrder: 7,
        title: '수도꼭지를 잠가요',
        description: '물이 나오지 않게 수도꼭지를 내려 잠가요',
      ),
      ActionCard(
        id: 'p-8',
        stepOrder: 8,
        title: '수건으로 손을 닦아요',
        description: '수건에 손을 대고 문질러 물기를 닦아요',
      ),
    ],
  );

  /// 이룸이 홈 대조용. 보호자 홈과 쓰는 provider 가 다르다.
  Widget wrapChild({required List<Routine> routines, int stars = 0}) =>
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(
            _StubRepo(routines: routines, past: const []),
          ),
          todayRoutinesProvider.overrideWith((ref) async => routines),
          memberProvider.overrideWith(
            (ref) async => Member(nickname: '하늘이', totalStars: stars),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            // 시안에 없는 리본이라 차이로 잡힌다
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            home: const ChildHomeScreen(),
          ),
        ),
      );

  /// 삭제 확인 팝업 대조용 (931:4879 안의 팝업 `931:5018`).
  ///
  /// 뒤에 깔린 홈 화면까지 재현하려면 타일을 민 상태를 만들어야 해서, **카드만**
  /// 세워 맞댄다. 카드는 흰 바탕이라 뒤가 무엇이든 결과가 달라지지 않는다.
  Widget wrapDeleteDialog() => ProviderScope(
    overrides: [testStorageOverride(onboardingCompleted: true)],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        // 시안에 없는 리본이라 차이로 잡힌다
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(
            child: ElumDialogCard<bool>(
              title: '일과를 삭제하실건가요?',
              icon: ElumDialogIcon.trash,
              actions: [
                ElumDialogAction(
                  label: '취소',
                  value: false,
                  tone: ElumDialogTone.neutral,
                ),
                ElumDialogAction(
                  label: '삭제',
                  value: true,
                  tone: ElumDialogTone.danger,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// 별 모으기 화면 대조용. 시안(364:8219)은 별 15개를 그린다.
  ///
  /// 일과 목록이 필요 없는 화면이라 저장소를 끼우지 않는다 — 별 개수만 본다.
  Widget wrapStars({int stars = 15}) => ProviderScope(
    overrides: [
      testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
      memberProvider.overrideWith(
        (ref) async => Member(nickname: '하늘이', totalStars: stars),
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        // 시안에 없는 리본이라 차이로 잡힌다
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: deviceInsets),
          child: child!,
        ),
        home: const ChildStarsScreen(),
      ),
    ),
  );

  /// 일과 만들기 입력 대조용.
  ///
  /// **배경 오로라를 멈춘다.** 무한 반복이라 켜 두면 찍을 때마다 그림이 달라져
  /// 대조가 성립하지 않는다. 시안은 정지된 한 장이다.
  Widget wrapInput() => ProviderScope(
    overrides: [
      testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
      routineSuggestionsProvider.overrideWith(
        (ref) async => RoutineSuggestion.fallback,
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        // 시안에 없는 리본이라 차이로 잡힌다
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: deviceInsets, disableAnimations: true),
          child: child!,
        ),
        home: const RoutineInputScreen(),
      ),
    ),
  );

  Widget wrap({required List<Routine> routines, required List<Routine> past}) =>
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(
            _StubRepo(routines: routines, past: past),
          ),
          memberProvider.overrideWith(
            (ref) async => const Member(nickname: '하늘이'),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            // 시안에 없는 리본이라 차이로 잡힌다
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            home: const GuardianHomeScreen(),
          ),
        ),
      );

  testWidgets('보호자 홈 — 일과 있음 (Figma 931:3896)', (tester) async {
    await tester.pumpWidget(
      wrap(
        routines: [
          routine('r1', '스스로 옷을 입어요', reward: '유튜브 시청 20분', percent: 50),
          routine('r2', '밥 먹기 전에 손을 씻어요', reward: '마이구미 5개 먹기', percent: 100),
        ],
        // 시안(931:3896)에 그려진 내용 그대로. 내용이 다르면 diff가 통째로
        // 붉어져 **정작 봐야 할 어긋남이 묻힌다.**
        past: [
          routine(
            'p1',
            '학교에 갈 준비를 해요',
            reward: '좋아하는 노래 들으며 학교 가기',
            percent: 100,
            at: DateTime(2026, 9, 20),
          ),
          // 시안의 두 번째 카드는 날짜 없이 `일과 다시하기`만 있다.
          routine(
            'p2',
            '학교에 갈 준비를 해요',
            reward: '좋아하는 노래 들으며 학교 가기',
            percent: 100,
          ),
          routine('p3', '밥 먹기 전에 손을 씻어요', reward: '거실에서 저녁 먹기', percent: 50),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GuardianHomeScreen),
      matchesGoldenFile('figma/home_931-3896.png'),
    );
  });

  testWidgets('보호자 홈 — 일과 없음 (Figma 217:2655)', (tester) async {
    await tester.pumpWidget(wrap(routines: const [], past: const []));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GuardianHomeScreen),
      matchesGoldenFile('figma/home_217-2655.png'),
    );
  });

  // 오늘 일과를 눌렀을 때 뜨는 시트다. **여기가 가장 많이 어긋나 있던 화면이라**
  // 대조에 올린다 (#295 에서 글꼴·크기·체크·보상 줄까지 여섯 군데가 나왔다).
  // 시트는 홈 위에 덮이므로 화면 전체를 찍는다.
  testWidgets('일과 시트 (Figma 956:4084)', (tester) async {
    await tester.pumpWidget(wrap(routines: [sheetRoutine()], past: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('스스로 옷을 입어요'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('figma/sheet_956-4084.png'),
    );
  });

  // 이룸이가 직접 쓰는 화면이라 올려 둔다. 값으로 대조했을 때는 열두 값이
  // 모두 맞았지만(#297), 픽셀로 맞대본 적은 없었다.
  testWidgets('이룸이 홈 (Figma 356:5079)', (tester) async {
    await tester.pumpWidget(
      wrapChild(
        // 시안이 그린 내용 그대로. 다르면 차이 그림이 통째로 붉어진다.
        routines: [
          routine('c1', '비 오는 날 학교에 가요', percent: 50),
          routine('c2', '학원 준비물을 챙겨요', percent: 100),
        ],
        stars: 15,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChildHomeScreen),
      matchesGoldenFile('figma/child_home_356-5079.png'),
    );
  });

  // 오늘 고친 화면이다 (#305 — 시안에 없는 문구를 빼고 입력칸을 가운데로).
  // 고친 것이 시안에 맞는지 그림으로 확인한다.
  testWidgets('일과 만들기 입력 (Figma 238:1643)', (tester) async {
    await tester.pumpWidget(wrapInput());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await expectLater(
      find.byType(RoutineInputScreen),
      matchesGoldenFile('figma/input_238-1643.png'),
    );
  });

  // 이룸이가 모은 별을 보러 들어오는 화면이다. 큰 별의 후광과 작은 별 일곱의
  // 자리를 그림으로 맞대본 적이 한 번도 없다 (#297).
  //
  // 이 화면은 코드가 상태바를 52로 잡고 Figma y좌표에서 빼는데, 실제 기기는
  // 59다. 그 7 차이가 화면 전체를 밀어 올렸는지 여기서 드러난다.
  testWidgets('별 모으기 (Figma 364:8219)', (tester) async {
    await tester.pumpWidget(wrapStars());
    await tester.pumpAndSettle();
    // 별은 PNG라 로딩이 끝나야 그려진다. 안 기다리면 빈 밤하늘이 정답이 된다.
    await precacheAllImages(tester);

    await expectLater(
      find.byType(ChildStarsScreen),
      matchesGoldenFile('figma/stars_364-8219.png'),
    );
  });

  // 지난 일과 시트 (#310). 시안은 스크롤을 펼쳐 401×1136 으로 그려져 있어
  // 통짜로 맞댈 수 없다. 여기서는 앱이 그리는 그대로 남겨 두고, 시안과는
  // 제목을 기준점 삼아 상단부만 잘라 맞댄다.
  testWidgets('지난 일과 시트 (Figma 980:4777)', (tester) async {
    await tester.pumpWidget(
      wrap(routines: const [], past: [pastSheetRoutine()]),
    );
    await tester.pumpAndSettle();

    // **누르면 뜨는지부터 본다.** 눌러도 아무 일이 없던 것이 이 이슈다 —
    // 시트가 안 뜨면 아래 대조까지 가지 못하고 여기서 실패한다.
    await tester.tap(find.text('밥 먹기 전에 손을 씻어요'));
    await tester.pumpAndSettle();
    expect(
      find.text('일과 다시하기'),
      findsOneWidget,
      reason: '지난 일과 시트가 떠야 하고 버튼은 다시하기여야 한다',
    );
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('figma/past_sheet_980-4777.png'),
    );
  });

  // 일과를 지울 때 뜨는 확인 팝업 (#318). 버튼 색과 사이 간격이 시안과 달랐다.
  testWidgets('일과 삭제 팝업 (Figma 931:4879)', (tester) async {
    await tester.pumpWidget(wrapDeleteDialog());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ElumDialogCard<bool>),
      matchesGoldenFile('figma/dialog_delete_931-4879.png'),
    );
  });
}

/// 목록만 돌려준다. 대조용이라 쓰기는 일어나지 않는다.
class _StubRepo with FakeRewardApi implements RoutineRepository {
  _StubRepo({required this.routines, required this.past});

  final List<Routine> routines;
  final List<Routine> past;

  @override
  Future<List<Routine>> getMyRoutines() async => routines;

  @override
  Future<List<Routine>> getTodayRoutines() async => routines;

  @override
  Future<List<Routine>> getPastRoutines() async => past;

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
  Future<({Routine routine, bool synced})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async => (routine: routine, synced: true);
}
