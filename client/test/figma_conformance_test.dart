@Tags(['golden'])
library;

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:elum/features/auth/presentation/role_select_screen.dart';
import 'package:elum/features/auth/presentation/consent_screen.dart';
import 'package:elum/features/auth/data/consent_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/link_code_screen.dart';
import 'package:elum/features/onboarding/presentation/card_completion_screen.dart';
import 'package:elum/features/onboarding/presentation/name_screen.dart';
import 'package:elum/features/onboarding/presentation/goals_screen.dart';
import 'package:elum/features/onboarding/presentation/character_screen.dart';
import 'package:elum/features/onboarding/presentation/widgets/character_card.dart';
import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/features/onboarding/presentation/pin_screen.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/guardian/presentation/question_screen.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:go_router/go_router.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_stars_screen.dart';
import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/features/child/domain/reward_character.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
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

  /// 추가질문 대조용. 시안(262:4766)이 그린 질문과 선택지 그대로.
  ///
  /// 이모지는 시험 환경에 글꼴이 없어 □ 로 나온다 — 자리만 본다.
  const designQuestion = RoutineQuestion(
    isRequired: true,
    questions: [
      QuestionItem(
        question: '하늘이가 비 오는 날\n평소와 다르게 챙겨야 하는\n물건이 있나요?',
        options: [
          QuestionOption(emoji: '☂️', label: '우산'),
          QuestionOption(emoji: '🧥', label: '우비'),
          QuestionOption(emoji: '👢', label: '장화'),
          QuestionOption(emoji: '🧦', label: '여벌 양말'),
          QuestionOption(emoji: '🧺', label: '작은 수건'),
        ],
      ),
    ],
  );

  Widget wrapQuestion() {
    final router = GoRouter(
      initialLocation: Routes.routineQuestion,
      routes: [
        GoRoute(
          path: Routes.routineQuestion,
          builder: (context, state) => const QuestionScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        routineRepositoryProvider.overrideWithValue(
          _QuestionRepo(designQuestion),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          // 다른 대조와 같은 안전영역을 준다 — 빼먹으면 화면이 59 위로 뜬다.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: deviceInsets),
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    );
  }

  /// 보상 화면 대조용 (시안 `309:4055` 루미 · `334:4320` 포포 · `343:4434` 루루).
  Widget wrapReward({RewardCharacter character = RewardCharacter.lumi}) =>
      ProviderScope(
    overrides: [
      testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
      memberProvider.overrideWith(
        (ref) async => Member(nickname: '하늘이', totalStars: 15),
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: deviceInsets),
          child: child!,
        ),
        home: RewardScreen(character: character),
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

  /// 온보딩 화면 하나를 시안과 같은 조건으로 세운다.
  ///
  /// **화면을 밀어 넣는다(push).** 뒤로가기는 `context.canPop()`으로 갈리므로
  /// 라우터에 화면 하나만 두면 시안에 있는 뒤로가기가 앱에서는 안 그려진다 —
  /// 시험이 만든 차이지 앱의 결함이 아니다. 실제 흐름처럼 앞 화면을 깔고
  /// 그 위로 올려야 시안과 같은 조건이 된다 (#297).
  ///
  /// 셋 다 앞 화면에서 받은 호칭을 제목에 넣으므로 저장소에 `하늘이`를
  /// 미리 넣어 둔다. 시안도 그 이름으로 그려져 있다 — 다르면 제목 줄이
  /// 통째로 어긋난 것으로 나온다.
  Future<void> pumpOnboarding(
    WidgetTester tester,
    String path,
    Widget Function() build, {
    String? nickname = '하늘이',
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
        GoRoute(path: path, builder: (context, state) => build()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(nickname: nickname),
          testMemberRepoOverride(),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    router.push(path);
    await tester.pump();
    // 화면 전환 애니메이션이 끝나야 자리가 고정된다
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('보호자 홈 — 일과 있음 (Figma 931:3896)', (tester) async {
    await tester.pumpWidget(
      wrap(
        routines: [
          routine('r1', '스스로 옷을 입어요', reward: '유튜브 시청 20분', percent: 50),
          routine('r2', '밥 먹기 전에 손을 씻어요', reward: '마이구미 5개 먹기', percent: 100),
        ],
        // 시안(931:3896)에 그려진 내용 그대로. 내용이 다르면 diff가 통째로
        // 붉어져 **정작 봐야 할 어긋남이 묻힌다.**
        // 시안(931:3896)이 그린 그대로. 지난 일과도 68 짜리 줄이고
        // 날짜·다시하기는 없다.
        past: [
          routine(
            'p1',
            '학교에 갈 준비를 해요',
            reward: '좋아하는 노래 들으며 학교 가기',
            percent: 100,
          ),
          routine('p2', '밥 먹기 전에 손을 씻어요', reward: '거실에서 저녁 먹기', percent: 50),
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

  // 역할 선택 (#297).
  testWidgets('역할 선택 (Figma 732:5176)', (tester) async {
    await pumpOnboarding(
      tester,
      Routes.roleSelect,
      () => const RoleSelectScreen(),
      nickname: null,
    );

    await expectLater(
      find.byType(RoleSelectScreen),
      matchesGoldenFile('figma/role_732-5176.png'),
    );
  });

  // 이름 (#297). 온보딩 두 번째 화면이다.
  testWidgets('이름 (Figma 204:991)', (tester) async {
    await pumpOnboarding(
      tester,
      Routes.onboardingName,
      () => const NameScreen(),
      nickname: null,
    );

    await expectLater(
      find.byType(NameScreen),
      matchesGoldenFile('figma/name_204-991.png'),
    );
  });

  // 로그인 (#297). **애플 버튼은 iOS 에서만 뜬다**(`Platform.isIOS`) — 시안은
  // 아이폰 화면이라 셋인데 시험 환경(macOS)에서는 둘이다. 그 한 줄은 차이로
  // 남는 것이 맞다.
  testWidgets('로그인 (Figma 238:1808)', (tester) async {
    final router = GoRouter(
      initialLocation: Routes.login,
      routes: [
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [testStorageOverride()],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    // 병아리 둘레의 빛이 끝나지 않는다 — settle 대신 시간을 밀어 고정한다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('figma/login_238-1808.png'),
    );
  });

  // 일과 만들기 완료 (#297). 1.5초 뒤 홈으로 스스로 넘어가므로 그 전에 찍는다.
  testWidgets('일과 만들기 완료 (Figma 425:4199)', (tester) async {
    // 1.5초 뒤 스스로 홈으로 넘어가므로 갈 곳을 만들어 준다 — 없으면
    // 타이머가 남아 테스트가 실패한다.
    final router = GoRouter(
      initialLocation: '/done',
      routes: [
        GoRoute(
          path: '/done',
          builder: (context, state) => const CardCompletionScreen(),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('홈')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [testStorageOverride(onboardingCompleted: true)],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(CardCompletionScreen),
      matchesGoldenFile('figma/complete_425-4199.png'),
    );

    // 남은 타이머를 흘려보낸다 (오로라는 계속 도므로 settle 은 쓰지 않는다)
    await tester.pump(const Duration(seconds: 2));
  });

  // 카드확인 (#297). **이 화면만 오로라를 껐다** — 배경이 정지라 대조가 정확하다.
  testWidgets('카드확인 (Figma 262:5124)', (tester) async {
    final container = ProviderContainer(
      overrides: [
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        speechServiceProvider.overrideWithValue(_SilentSpeech()),
      ],
    );
    addTearDown(container.dispose);

    // 시안(262:5124)은 카드 다섯 장을 그리고 첫 장을 보여 준다.
    container.read(routineFlowProvider.notifier).state = RoutineFlowState(
      routine: const Routine(
        id: 'r1',
        title: '학교에 가요',
        steps: [
          ActionCard(
            id: 'c1',
            stepOrder: 1,
            title: '옷을 입어요',
            description: '학교에 입고 갈 옷을 차례대로 입어요',
          ),
          ActionCard(
            id: 'c2',
            stepOrder: 2,
            title: '가방을 챙겨요',
            description: '설명',
          ),
          ActionCard(
            id: 'c3',
            stepOrder: 3,
            title: '신발을 신어요',
            description: '설명',
          ),
          ActionCard(
            id: 'c4',
            stepOrder: 4,
            title: '문을 열어요',
            description: '설명',
          ),
          ActionCard(
            id: 'c5',
            stepOrder: 5,
            title: '길을 걸어요',
            description: '설명',
          ),
        ],
      ),
    );

    final router = GoRouter(
      initialLocation: Routes.routineReview,
      routes: [
        GoRoute(
          path: Routes.routineReview,
          builder: (context, state) => const CardReviewScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(CardReviewScreen),
      matchesGoldenFile('figma/card_review_262-5124.png'),
    );
  });

  // 추가질문 (#297). 오로라가 깔린 화면이라 배경은 어긋난 채로 읽는다 —
  // 질문과 선택지 **자리**가 맞는지가 여기서 볼 것이다.
  testWidgets('추가질문 (Figma 262:4766)', (tester) async {
    await tester.pumpWidget(wrapQuestion());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuestionScreen)),
    );
    await container.read(routineFlowProvider.notifier).askQuestion();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await expectLater(
      find.byType(QuestionScreen),
      matchesGoldenFile('figma/question_262-4766.png'),
    );
  });

  // 이룸이 홈 빈 상태 (#297). 일과가 하나도 없을 때 무엇을 보여주는지는
  // 시안에 따로 그려져 있다 — 빈 화면이 아니라 시무룩한 캐릭터와 안내다.
  testWidgets('이룸이 홈 — 빈 상태 (Figma 343:4543)', (tester) async {
    await tester.pumpWidget(wrapChild(routines: const [], stars: 0));
    await tester.pumpAndSettle();
    await precacheAllImages(tester);

    await expectLater(
      find.byType(ChildHomeScreen),
      matchesGoldenFile('figma/child_home_empty_343-4543.png'),
    );
  });

  // 보상 화면 (#297). 별이 둥둥 떠다녀 pumpAndSettle 이 끝나지 않으므로
  // 등장 연출(700ms) 뒤 float 주기의 두 배 지점 — sin 이 0 으로 돌아오는 자리 —
  // 에서 프레임을 고정한다. 그래야 캡처마다 별 높이가 달라지지 않는다.
  testWidgets('보상 — 루미 (Figma 309:4055)', (tester) async {
    await tester.pumpWidget(wrapReward());
    await tester.pump();
    await precacheAllImages(tester);
    await tester.pump(AppMotion.float * 2);

    await expectLater(
      find.byType(RewardScreen),
      matchesGoldenFile('figma/reward_lumi_309-4055.png'),
    );
  });

  // 보상 — 포포 · 루루 (#297). 캐릭터만 바뀌는 같은 화면이지만 **그림과 문구가
  // 다르다** — 루미만 올려 두면 나머지 둘이 어긋나도 드러나지 않는다.
  testWidgets('보상 — 포포 (Figma 334:4320)', (tester) async {
    await tester.pumpWidget(wrapReward(character: RewardCharacter.popo));
    await tester.pump();
    await precacheAllImages(tester);
    await tester.pump(AppMotion.float * 2);

    await expectLater(
      find.byType(RewardScreen),
      matchesGoldenFile('figma/reward_popo_334-4320.png'),
    );
  });

  testWidgets('보상 — 루루 (Figma 343:4434)', (tester) async {
    await tester.pumpWidget(wrapReward(character: RewardCharacter.ruru));
    await tester.pump();
    await precacheAllImages(tester);
    await tester.pump(AppMotion.float * 2);

    await expectLater(
      find.byType(RewardScreen),
      matchesGoldenFile('figma/reward_ruru_343-4434.png'),
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


  // 목표 (#297). 온보딩 셋째 화면이다.
  testWidgets('목표 (Figma 204:1002)', (tester) async {
    await pumpOnboarding(tester, Routes.onboardingGoals, () => const GoalsScreen());
    await precacheAllImages(tester);
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(GoalsScreen),
      matchesGoldenFile('figma/goals_204-1002.png'),
    );
  });

  // 캐릭터 (#297). 카드 안이 그림이라 로딩을 기다린다.
  testWidgets('캐릭터 (Figma 204:1029)', (tester) async {
    await pumpOnboarding(
      tester,
      Routes.onboardingCharacter,
      () => const CharacterScreen(),
    );
    await precacheAllImages(tester);
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(CharacterScreen),
      matchesGoldenFile('figma/character_204-1029.png'),
    );
  });

  // 비밀번호 (#297). **시안 아래 절반은 iOS 시스템 키패드**다 — 앱이 그리는
  // 것이 아니라 OS 가 올려 준다. 시험 환경에는 키패드가 없으므로 그 구간은
  // 대조에서 빼고 본다 (`--mask-bottom 300`).
  testWidgets('비밀번호 (Figma 238:1909)', (tester) async {
    await pumpOnboarding(tester, Routes.onboardingPin, () => const PinScreen());
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(PinScreen),
      matchesGoldenFile('figma/pin_238-1909.png'),
    );
  });

  // 약관 동의 (#297). 시안 `726:5056`은 **전부 켜진** 상태다 — 같은 화면의
  // 두 상태 중 하나이므로 켠 상태로 맞춰 세운다.
  //
  // 문구는 서버에서 온다. 시험에서는 앱에 담긴 기본값을 꽂아 네트워크를 타지
  // 않게 한다. 나이 확인 문구는 **일부러 시안과 다르다** — 시안의
  // `만 14세 이상이며 아이의 법정대리인입니다`는 성인 이룸이에게 사실이
  // 아니라 #226에서 한 줄로 줄였다. 그 줄은 붉게 떠도 그대로 둔다.
  testWidgets('약관 동의 (Figma 726:5056)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(),
          consentRepositoryProvider.overrideWithValue(_SilentConsent()),
          consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            home: const ConsentScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 시안은 전체 동의가 눌린 상태다
    await tester.tap(find.textContaining('전체 동의'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ConsentScreen),
      matchesGoldenFile('figma/consent_726-5056.png'),
    );
  });

  /// 연결 암호 화면을 세운다. **1초 타이머가 계속 돌아** `pumpAndSettle`을
  /// 쓸 수 없다 — 필요한 만큼만 `pump()`한다.
  Future<_FakeLink> pumpLinkCode(WidgetTester tester) async {
    final repo = _FakeLink();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
        GoRoute(
          path: Routes.linkCode,
          builder: (context, state) =>
              const LinkCodeScreen(fromOnboarding: true),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceLinkRepositoryProvider.overrideWithValue(repo),
          testStorageOverride(nickname: '하늘이'),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    // 뒤로가기가 `canPop()` 으로 갈린다 — 실제 흐름처럼 밀어 넣어야 시안과 같다
    router.push(Routes.linkCode);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return repo;
  }

  // 코드연결 — 대기 (#297). 시안 `732:5334`.
  testWidgets('코드연결 — 대기 (Figma 732:5334)', (tester) async {
    await pumpLinkCode(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(LinkCodeScreen),
      matchesGoldenFile('figma/linkcode_732-5334.png'),
    );
  });

  // 코드연결 — 연결됨 (#297). 시안 `732:5850`. 타이머와 다시 만들기가 사라지고
  // 시작하기가 켜진다.
  testWidgets('코드연결 — 연결됨 (Figma 732:5850)', (tester) async {
    final repo = await pumpLinkCode(tester);
    await tester.pump(const Duration(milliseconds: 100));

    repo.linked = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(LinkCodeScreen),
      matchesGoldenFile('figma/linkcode_732-5850.png'),
    );
  });

  // 화면 전환 (#297). 시안 `309:2837` — 이룸이 화면에서 보호자 화면으로 넘어갈 때
  // PIN을 받는다. **아래 절반은 iOS 시스템 키패드**라 앱이 그리지 않는다
  // (`--mask-bottom 300`).
  testWidgets('화면 전환 (Figma 309:2837)', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
        GoRoute(
          path: Routes.modeSwitch,
          builder: (context, state) => const ModeSwitchScreen(
            target: ModeSwitchTarget.guardian,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [testStorageOverride(pin: '1234')],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: deviceInsets),
              child: child!,
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    router.push(Routes.modeSwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(ModeSwitchScreen),
      matchesGoldenFile('figma/modeswitch_309-2837.png'),
    );
  });

  // ── 고른 뒤 모습 (#297) ──────────────────────────────────────────────
  // 시안은 같은 화면을 **고르기 전/후**로 나눠 그린다. 고른 뒤만 아는 것이
  // 선택색·테두리 굵기·CTA 활성색이라, 전만 올려 두면 그 넷을 아무도 안 본다.
  // 실제로 목표 칩에 여우색이 들어간 적이 있다 (이슈 #11).

  testWidgets('목표 — 고른 뒤 (Figma 204:1147)', (tester) async {
    await pumpOnboarding(tester, Routes.onboardingGoals, () => const GoalsScreen());
    await precacheAllImages(tester);

    // 시안은 위 둘이 켜져 있다
    await tester.tap(find.text('해야 할 일을 순서대로 이해해요'));
    // 칩이 색을 바꾸는 동안에는 다음 탭이 먹지 않는다 — 끝까지 기다린다
    // (이 화면은 끝나지 않는 움직임이 없어 settle 을 써도 된다)
    await tester.pumpAndSettle();
    await tester.tap(find.text('필요한 준비물을 스스로 챙겨요'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GoalsScreen),
      matchesGoldenFile('figma/goal_selected_204-1147.png'),
    );
  });

  testWidgets('캐릭터 — 포포를 고른 뒤 (Figma 204:1121)', (tester) async {
    await pumpOnboarding(
      tester,
      Routes.onboardingCharacter,
      () => const CharacterScreen(),
    );
    await precacheAllImages(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is CharacterCard && w.character == CardCharacter.fox,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CharacterScreen),
      matchesGoldenFile('figma/char_popo_204-1121.png'),
    );
  });

  testWidgets('캐릭터 — 루루를 고른 뒤 (Figma 204:1134)', (tester) async {
    await pumpOnboarding(
      tester,
      Routes.onboardingCharacter,
      () => const CharacterScreen(),
    );
    await precacheAllImages(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is CharacterCard && w.character == CardCharacter.cat,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CharacterScreen),
      matchesGoldenFile('figma/char_ruru_204-1134.png'),
    );
  });

  // 역할 선택 — 고른 뒤 (#297).
  //
  // ⚠️ **시안 두 프레임의 제목이 서로 다르다.** 고르기 전(`732:5176`)은
  // `이 휴대폰은 누가`(폭 204)인데 고른 뒤(`732:5258`)는 `이 휴대폰 누가`(폭 177)다.
  // 앱은 앞쪽을 따르고 있어 이 화면에서는 제목 한 줄이 붉게 남는다.
  // **디자이너에게 물어야 할 것이라 임의로 바꾸지 않는다.**
  testWidgets('역할 선택 — 고른 뒤 (Figma 732:5258)', (tester) async {
    await pumpOnboarding(
      tester,
      Routes.roleSelect,
      () => const RoleSelectScreen(),
      nickname: null,
    );

    await tester.tap(find.text('일과를 만들고 관리해요'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RoleSelectScreen),
      matchesGoldenFile('figma/role_selected_732-5258.png'),
    );
  });

  // 비밀번호 — 두 번째 단계 (#297). 시안 `238:2924`.
  //
  // 네 자리를 두 번 맞춰 넣으면 키패드가 내려가고 `시작하기`가 나타난다.
  // **나타나는 것 자체가 다 됐다는 신호**라 이 상태가 시안에 따로 그려져 있다.
  testWidgets('비밀번호 — 다시 넣은 뒤 (Figma 238:2924)', (tester) async {
    await pumpOnboarding(tester, Routes.onboardingPin, () => const PinScreen());

    // 1단계 — 네 자리를 넣으면 재입력 단계로 자동 전환된다
    await tester.enterText(find.byType(EditableText), '1234');
    await tester.pumpAndSettle();
    // 2단계 — 같은 값을 넣으면 CTA 가 나타난다
    await tester.enterText(find.byType(EditableText), '1234');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PinScreen),
      matchesGoldenFile('figma/pinconfirm_238-2924.png'),
    );
  });

  // 보호자 홈 — 일과를 민 상태 (#297). 시안 `931:4179`.
  //
  // 담긴 일과는 `931:3896`과 **같다** — 시안이 같은 화면의 두 상태로 그렸다.
  // 두 번째 오늘 일과를 왼쪽으로 밀면 삭제·수정이 드러난다.
  testWidgets('보호자 홈 — 일과를 민 뒤 (Figma 931:4179)', (tester) async {
    await tester.pumpWidget(
      wrap(
        routines: [
          routine('r1', '스스로 옷을 입어요', reward: '유튜브 시청 20분', percent: 50),
          routine('r2', '밥 먹기 전에 손을 씻어요', reward: '마이구미 5개 먹기', percent: 100),
        ],
        past: [
          routine(
            'p1',
            '학교에 갈 준비를 해요',
            reward: '좋아하는 노래 들으며 학교 가기',
            percent: 100,
          ),
          routine('p2', '밥 먹기 전에 손을 씻어요', reward: '거실에서 저녁 먹기', percent: 50),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('마이구미 5개 먹기'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GuardianHomeScreen),
      matchesGoldenFile('figma/routine_menu_931-4179.png'),
    );
  });

  /// 이룸이가 카드를 보는 화면. 시안 `309:3548`(안 체크) · `309:3648`(체크).
  ///
  /// **카드 안 그림은 AI 가 만든다** — 시험에는 없으므로 대체 일러스트가 뜬다.
  /// 그 사각형은 차이로 남는 것이 맞다. 볼 것은 상단바·카드 틀·문구·체크 단추다.
  Widget wrapCardDetail() => ProviderScope(
    overrides: [
      offlineDioOverride(),
      testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
      // 읽어 주기는 오디오 채널을 타 시험에서 터진다 — 아무것도 안 하는 대역으로
      speechServiceProvider.overrideWithValue(_SilentSpeech()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp.router(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: deviceInsets),
          child: child!,
        ),
        // 마지막 단계를 체크하면 보상 화면으로 넘어간다 — 길이 없으면 터진다
        routerConfig: GoRouter(
          initialLocation: Routes.childRoutineDetail,
          routes: [
            GoRoute(
              path: Routes.childRoutineDetail,
              builder: (context, state) => const ChildRoutineDetailScreen(
                routine: Routine(
                  id: 'd1',
                  title: '비 오는 날 학교에 가요',
                  status: 'CONFIRMED',
                  steps: [
                    ActionCard(
                      id: 'd-c1',
                      stepOrder: 1,
                      title: '옷을 입어요',
                      description: '학교에 입고 갈 옷을 차례대로 입어요',
                    ),
                  ],
                ),
              ),
            ),
            GoRoute(
              path: Routes.childReward,
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('이룸이 카드 — 안 체크 (Figma 309:3548)', (tester) async {
    await tester.pumpWidget(wrapCardDetail());
    await tester.pump();
    await precacheAllImages(tester);
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(ChildRoutineDetailScreen),
      matchesGoldenFile('figma/childhome_309-3548.png'),
    );
  });

  // 체크한 뒤(`309:3648`)는 **대조에 올리지 않는다.** 체크하면 색종이가 터지는데
  // 조각 자리가 매번 무작위라 돌릴 때마다 0.1%씩 흔들려 골든이 스스로 깨진다.
  // 체크 단추 색은 `child_screens_golden_test.dart`가 회귀로 잡는다.

  /// 로딩 화면. 시안 `262:4569`(정리 중) · `262:4703`(카드 만드는 중).
  ///
  /// 서버 응답을 **일부러 늦춰** 마지막 단계에 머문 상태를 만든다 — 시안이
  /// 그린 것이 그 순간이다. 오로라 배경은 계속 흐르므로 수치가 크게 남는데,
  /// **볼 것은 글자와 체크 줄의 자리**다.
  Widget wrapLoading(RoutineLoadingKind kind) => ProviderScope(
    overrides: [
      fakeDioOverride(delay: const Duration(seconds: 8), const {
        'POST /api/routines/questions': {'questions': []},
        'POST /api/routines': {'id': 'r1'},
      }),
      testStorageOverride(onboardingCompleted: true),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp.router(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: deviceInsets),
          child: child!,
        ),
        routerConfig: GoRouter(
          initialLocation: '/loading',
          routes: [
            GoRoute(
              path: '/loading',
              builder: (context, state) => RoutineLoadingScreen(kind: kind),
            ),
            GoRoute(
              path: Routes.routineQuestion,
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: Routes.routineReview,
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('로딩 — 내용 정리 중 (Figma 262:4569)', (tester) async {
    await tester.pumpWidget(wrapLoading(RoutineLoadingKind.prepare));
    await tester.pump();
    await precacheAllImages(tester);
    // 세 줄이 다 드러날 만큼(2+1.5+2초) 흘려보낸다.
    // **한 번에 6초를 주면 안 된다** — 단계는 100ms 틱을 세며 드러나는데
    // 한 프레임만 그리면 틱이 한 번만 돌아 첫 줄에서 멈춘다.
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byType(RoutineLoadingScreen),
      matchesGoldenFile('figma/loading_262-4569.png'),
    );

    // 찍은 뒤에는 남은 타이머(응답 대기·마감)를 흘려보낸다 — 안 그러면
    // 위젯이 사라진 뒤에도 타이머가 남아 시험이 실패한다.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  // 추가질문 — 고른 뒤 (#297). 시안 `262:4854`.
  //
  // 고른 칩은 **검게 차고 글자가 희어진다**. 그리고 `카드 만들기`가 나타난다 —
  // 고르기 전에는 없던 버튼이라 나타나는 것 자체가 다음 할 일을 알린다.
  testWidgets('추가질문 — 고른 뒤 (Figma 262:4854)', (tester) async {
    await tester.pumpWidget(wrapQuestion());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuestionScreen)),
    );
    await container.read(routineFlowProvider.notifier).askQuestion();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // 시안이 고른 둘. 칩이 색을 바꾸는 동안에는 다음 탭이 먹지 않으므로
    // 사이를 충분히 띄운다. **`pumpAndSettle`은 못 쓴다** — 오로라가 끝나지 않는다.
    await tester.tap(find.textContaining('우비'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.textContaining('여벌 양말'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await expectLater(
      find.byType(QuestionScreen),
      matchesGoldenFile('figma/question_262-4854.png'),
    );
  });

  // 비밀번호 — 한 자리 넣은 뒤 (#297). 시안 `238:1997`.
  // 채운 점과 빈 점이 한 화면에 함께 보이는 유일한 상태다.
  testWidgets('비밀번호 — 한 자리 (Figma 238:1997)', (tester) async {
    await pumpOnboarding(tester, Routes.onboardingPin, () => const PinScreen());

    await tester.enterText(find.byType(EditableText), '1');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PinScreen),
      matchesGoldenFile('figma/pin_typed_238-1997.png'),
    );
  });

  // 비밀번호 확인 — 한 자리 (#297). 시안 `238:2767`.
  testWidgets('비밀번호 확인 — 한 자리 (Figma 238:2767)', (tester) async {
    await pumpOnboarding(tester, Routes.onboardingPin, () => const PinScreen());

    // 네 자리를 넣으면 재입력 단계로 자동 전환된다
    await tester.enterText(find.byType(EditableText), '1234');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '1');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PinScreen),
      matchesGoldenFile('figma/pinconfirm_238-2767.png'),
    );
  });

  // 코드연결 — 성공 팝업 (#297). 시안 `732:5702`.
  // **팝업은 화면 위에 뜨므로 앱 전체를 찍는다.**
  testWidgets('코드연결 — 성공 팝업 (Figma 732:5702)', (tester) async {
    final repo = await pumpLinkCode(tester);
    await tester.pump(const Duration(milliseconds: 100));

    repo.linked = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('figma/linkcode_732-5702.png'),
    );
  });
}

/// 연결 암호 대역. 시안(`732:5334`)이 그린 `5NJ280`과 `09:59`를 그대로 준다 —
/// 다른 값이면 글자가 통째로 어긋난 것으로 나온다.
class _FakeLink extends DeviceLinkRepository {
  _FakeLink()
    : super(dio: Dio(), tokens: InMemoryTokenStore(), storage: InMemoryStorage());

  bool linked = false;

  /// 600으로 둔다 — 화면을 세우는 데 1초가 채 안 걸리므로 내림하면 `09:59`가
  /// 남아 시안과 같은 글자가 된다. 599면 `09:58`이 되어 두 자리가 붉어진다.
  @override
  Future<IssuedLinkCode?> issue() async =>
      IssuedLinkCode.fromNow(code: '5NJ280', expiresInSeconds: 600);

  @override
  Future<LinkStatus> status() async => LinkStatus(
    devices: linked
        ? [LinkedDevice(linkId: 'l1', linkedAt: DateTime(2026, 9, 18))]
        : const [],
  );
}

/// 서버에 나가지 않는 대역. 대조는 그림만 본다.
class _SilentConsent extends ConsentRepository {
  _SilentConsent() : super(dio: Dio());

  @override
  Future<bool> agree({
    required Set<String> agreedKeys,
    required String version,
  }) async => true;
}

/// TTS 는 플랫폼 채널을 타므로 아무 것도 하지 않는 것으로 바꿔 끼운다.
class _SilentSpeech implements SpeechService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// 추가질문만 돌려준다.
class _QuestionRepo with FakeRewardApi implements RoutineRepository {
  _QuestionRepo(this.question);

  final RoutineQuestion question;

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async =>
      question;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
