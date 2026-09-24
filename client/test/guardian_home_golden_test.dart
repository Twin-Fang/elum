@Tags(['golden'])
library;

import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/create_routine_button.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elum/core/widgets/inset_shadow.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 보호자 홈 개편(이슈 #258)의 렌더 회귀 고정.
///
/// **AI를 부르지 않는다.** 이미 만들어진 일과를 넣어 그리기만 한다 —
/// 일과를 실제로 만들면 카드 생성 API가 돌아 비용이 나간다.
///
/// 기준 이미지는 Figma 931:3896과 눈으로 대조해 승인한 것이다.
/// 골든은 "Figma와 같은가"를 판단하지 못하므로 첫 승인은 사람이 한다.
void main() {
  useFigmaViewport();

  Routine routine(
    String id,
    String title, {
    String reward = '',
    int percent = 0,
    DateTime? at,
  }) =>
      Routine(
        id: id,
        title: title,
        status: 'CONFIRMED',
        rewardText: reward,
        progressPercent: percent,
        scheduledAt: at,
        // 링은 카드의 완료 여부로 셈한다. 퍼센트만 넣고 카드를 미완료로 두면
        // 서버가 절대 주지 않는 조합이 되어 골든이 거짓말을 한다.
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

  Widget wrap({
    required List<Routine> routines,
    required List<Routine> past,
  }) =>
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider
              .overrideWithValue(_GoldenRepo(routines: routines, past: past)),
          memberProvider.overrideWith(
            (ref) async => const Member(nickname: '하늘이'),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: const GuardianHomeScreen(),
          ),
        ),
      );

  testWidgets('일과가 있는 홈 — 오늘 · 지난 두 칸', (tester) async {
    await tester.pumpWidget(wrap(
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
          at: DateTime(2026, 9, 20),
        ),
        routine('p2', '밥 먹기 전에 손을 씻어요',
            reward: '거실에서 저녁 먹기', percent: 50, at: DateTime(2026, 9, 19)),
      ],
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GuardianHomeScreen),
      matchesGoldenFile('goldens/guardian_home_filled.png'),
    );
  });

  /// 컴포넌트 하나만 **크게** 찍는다.
  ///
  /// 전체 화면 골든은 이 버튼을 361×68로 그린다. 그 크기에서는 안쪽 그림자가
  /// 거의 보이지 않아, 효과 네 줄 중 세 줄이 빠진 채로도 통과했다 (이슈 #258).
  /// 그림자·발광·테두리처럼 **작게 보면 사라지는 것**은 따로 크게 찍어
  /// `docs/figma/home-redesign/ref_create_button.png`와 나란히 본다.
  testWidgets('새로운 일과 만들기 버튼 — 효과 네 겹', (tester) async {
    // 시안 export(3배)와 같은 크기로 찍는다. 1배에서는 10px 안쪽 그림자가
    // 몇 픽셀로 뭉개져 있으나 마나다.
    //
    // 화면을 3배로 넓히고 dpr은 1로 둔다. ScreenUtil이 designSize(393)를
    // 기준으로 `.w`를 3.0으로 잡아 상자와 여백이 3배로 그려진다.
    // **dpr을 올리는 방법은 통하지 않는다** — 골든은 논리 픽셀로 캡처한다.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [testStorageOverride(onboardingCompleted: true)],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              // `.w`는 3배가 되지만 **fontSize는 ScreenUtil이 건드리지 않는다.**
              // 글자만 1배로 남으면 3배 골든이 실제 화면과 다른 그림이 된다.
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: Scaffold(
              backgroundColor: AppColors.light.background,
              body: Center(
                // RepaintBoundary가 없으면 화면 전체가 찍힌다 —
                // 컴포넌트만 보려고 만든 골든이 의미를 잃는다.
                child: RepaintBoundary(
                  child: Padding(
                    // 바깥 발광이 잘리지 않을 만큼 띄운다
                    padding: const EdgeInsets.all(24),
                    child: CreateRoutineButton(onTap: () {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/create_routine_button.png'),
    );
  });

  /// 골든은 **사람이 봐야** 틀린 줄 안다. 효과가 통째로 빠져도 기준 이미지를
  /// 새로 만들면 그대로 통과한다 — 실제로 그렇게 빠진 채 배포됐다 (이슈 #258).
  ///
  /// 그래서 시안의 `effects` 문자열을 값으로 박아 둔다. 한 줄이라도 빠지거나
  /// 숫자가 달라지면 눈이 아니라 테스트가 먼저 잡는다.
  testWidgets('버튼 효과가 시안 네 줄과 값까지 같다', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: Center(child: CreateRoutineButton(onTap: () {}))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 바깥 한 줄 — 0px 4px 20px 0px rgba(204,188,246,1)
    final outer = tester
        .widgetList<Container>(find.descendant(
          of: find.byType(CreateRoutineButton),
          matching: find.byType(Container),
        ))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .expand((d) => d.boxShadow ?? const <BoxShadow>[])
        .toList();
    expect(outer, hasLength(1));
    expect(outer.single.color, AppColors.light.routineCreateGlow);
    expect(outer.single.blurRadius, 20);
    expect(outer.single.offset, const Offset(0, 4));

    // 안쪽 세 줄 — 빠지기 쉬운 자리다. Flutter가 inset을 기본 지원하지 않아
    // 옮기는 사람이 "나중에"로 미루면 아무도 알아채지 못한다.
    final painter = tester
        .widget<CustomPaint>(find.descendant(
          of: find.byType(CreateRoutineButton),
          matching: find.byType(CustomPaint),
        ).first)
        .foregroundPainter! as InsetShadowPainter;
    expect(painter.shadows, hasLength(3),
        reason: '시안 effects의 inset 줄 수와 같아야 한다');

    // inset 0px 8px 24px -16px rgba(255,255,255,0.24)
    expect(painter.shadows[0].offset, const Offset(0, 8));
    expect(painter.shadows[0].blur, 24);
    expect(painter.shadows[0].spread, -16);
    expect(painter.shadows[0].color.a, closeTo(0.24, 0.01));
    // inset 0px -24px 32px 0px rgba(255,255,255,0.24)
    expect(painter.shadows[1].offset, const Offset(0, -24));
    expect(painter.shadows[1].blur, 32);
    expect(painter.shadows[1].spread, 0);
    expect(painter.shadows[1].color.a, closeTo(0.24, 0.01));
    // inset 0px 0px 10px 2px rgba(255,255,255,1)
    expect(painter.shadows[2].offset, Offset.zero);
    expect(painter.shadows[2].blur, 10);
    expect(painter.shadows[2].spread, 2);
    expect(painter.shadows[2].color, const Color(0xFFFFFFFF));
  });

  testWidgets('빈 홈 — 두 칸 모두 비었을 때', (tester) async {
    await tester.pumpWidget(wrap(routines: const [], past: const []));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GuardianHomeScreen),
      matchesGoldenFile('goldens/guardian_home_empty.png'),
    );
  });
}

/// 목록만 돌려주는 저장소. 쓰기는 골든에서 일어나지 않는다.
class _GoldenRepo with FakeRewardApi implements RoutineRepository {
  _GoldenRepo({required this.routines, required this.past});

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
    String idempotencyKey = '',
  }) async =>
      const Routine(id: 'new');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async =>
      null;

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async =>
      (routine: routine, failure: null);
}
