import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_storage.dart';
import 'helpers/fake_dio.dart';
import 'helpers/fake_reward_api.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/features/guardian/application/routine_flow_state.dart';

/// 카드 수정 바텀시트 · 카드확인/아이 상세 Figma 정합 (이슈 #77) ·
/// `/today` 진행률 계약 (이슈 #75).
void main() {
  const cards = [
    ActionCard(
      id: 'c1',
      title: '옷을 입어요',
      description: '학교에 입고 갈 옷을 차례대로 입어요',
      stepOrder: 1,
    ),
    ActionCard(
      id: 'c2',
      title: '우산을 챙겨요',
      description: '현관에서 우산을 챙겨요',
      stepOrder: 2,
    ),
  ];

  const routine = Routine(
    id: 'r1',
    title: '비 오는 날 학교에 가요',
    status: 'PENDING_REVIEW',
    steps: cards,
  );

  group('Routine 모델 — /today 계약 (이슈 #75)', () {

    test('진행률이 문자열로 와도 죽지 않는다', () {
      final parsed = Routine.fromJson(const {
        'id': 'r1',
        'progressPercent': '40',
        'totalStepCount': '이상한값',
      });

      expect(parsed.progressPercent, 40);
      expect(parsed.totalStepCount, 0);
    });

  });

  group('RoutineFlowNotifier.updateStep — 제목·설명 수정 (이슈 #77)', () {
    ProviderContainer containerWith(_FakeRepo repo) {
      final container = ProviderContainer(
        overrides: [
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      container.read(routineFlowProvider.notifier).state =
          const RoutineFlowState(routine: routine);
      return container;
    }

    test('서버 응답에 title이 없어도 다른 카드의 로컬 제목이 지워지지 않는다', () async {
      // 서버 RoutineStep에는 title 컬럼이 없다 (2026-07-22 확인).
      // 응답을 그대로 받으면 수정하지 않은 카드의 제목까지 빈 값이 된다.
      final container = containerWith(_FakeRepo(synced: true));

      await container
          .read(routineFlowProvider.notifier)
          .updateStep(stepId: 'c1', title: '새 제목', description: '새 설명');

      final steps = container.read(routineFlowProvider).routine!.steps;
      expect(steps[1].title, '우산을 챙겨요', reason: '수정 안 한 카드의 제목은 유지');
    });

    test('서버 반영 실패 시 로컬은 반영되고 실패 이유를 돌려준다', () async {
      final container = containerWith(_FakeRepo(synced: false));

      final failure = await container
          .read(routineFlowProvider.notifier)
          .updateStep(stepId: 'c1', title: '새 제목', description: '새 설명');

      final steps = container.read(routineFlowProvider).routine!.steps;
      // **이유가 화면까지 올라온다.** 전에는 `false` 한 글자로 납작해져
      // 서버가 알려준 문구가 저장소 안에서 사라졌다 (#352).
      expect(failure, isNotNull);
      expect(steps.first.description, '새 설명', reason: '실패해도 화면은 유지');
    });
  });

  group('카드확인 화면 (Figma 262:5124, 2026-07-22 시안)', () {
    Widget wrap(_FakeRepo repo) {
      final router = GoRouter(
        initialLocation: Routes.routineReview,
        routes: [
          GoRoute(
            path: Routes.routineReview,
            builder: (context, state) => const CardReviewScreen(),
          ),
          GoRoute(
            path: Routes.guardian,
            builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(repo),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
    }

    /// 화면을 띄우고 일과를 주입한다.
    /// AuroraBackground가 무한 애니메이션이라 pumpAndSettle은 쓸 수 없다.
    Future<void> pumpReview(WidgetTester tester, _FakeRepo repo) async {
      await tester.pumpWidget(wrap(repo));
      final context = tester.element(find.byType(CardReviewScreen));
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(routineFlowProvider.notifier).state = const RoutineFlowState(
        routine: routine,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('title 없는 예전 카드는 제목칸이 비어 열린다 (제목=설명 방지)', (tester) async {
      // 예전 카드는 title이 없어 displayTitle이 description을 대신 돌려준다.
      // 그 값을 제목칸 초기값으로 쓰면 사용자가 제목을 안 고쳤을 때
      // title=description으로 저장돼 제목·설명이 똑같아진다.
      // 시트는 실제 title로 열려야 하므로, title 없는 카드는 제목칸이 비어야 한다.
      const titleless = Routine(
        id: 'r1',
        status: 'PENDING_REVIEW',
        steps: [
          ActionCard(id: 'c1', description: '현관에서 우산을 챙겨요', stepOrder: 1),
        ],
      );

      await tester.pumpWidget(wrap(_FakeRepo(synced: true)));
      final context = tester.element(find.byType(CardReviewScreen));
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(routineFlowProvider.notifier).state = const RoutineFlowState(
        routine: titleless,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('이 카드 수정'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 제목칸(첫 필드)이 비어 있어야 한다 — description이 새어들지 않았다
      final titleField = tester.widget<TextField>(find.byType(TextField).first);
      expect(
        titleField.controller?.text,
        isEmpty,
        reason: 'title 없는 카드는 제목칸이 비어 열려야 한다',
      );
      // 저장 버튼은 제목이 비어 비활성 — 제목=설명으로 저장될 수 없다
      final saveButton = find.text('완료').last;
      expect(saveButton, findsOneWidget);
    });

    testWidgets('제목을 지우면 저장할 수 없다', (tester) async {
      await pumpReview(tester, _FakeRepo(synced: true));

      await tester.tap(find.text('이 카드 수정'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      await tester.tap(find.text('완료').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('카드 수정'),
        findsOneWidget,
        reason: '빈 제목으로는 저장되지 않고 시트가 남는다',
      );
    });

    testWidgets('서버 반영 실패 시 에러 코드를 보여준다', (tester) async {
      await pumpReview(tester, _FakeRepo(synced: false));

      await tester.tap(find.text('이 카드 수정'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('완료').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('E-STEP'), findsOneWidget);
    });
  });

}

/// 서버 흉내 저장소. [synced]로 서버 반영 성공/실패를 가른다.
///
/// updateStep 응답은 실제 서버처럼 **step title 없이** 돌아온다 —
/// notifier의 제목 복원 로직이 이 조건에서 검증된다.
class _FakeRepo with FakeRewardApi implements RoutineRepository {
  // 카드확인 카드 추가 (#444) — 이 테스트는 쓰지 않는다
  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
  _FakeRepo({required this.synced});

  final bool synced;

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId, {
    required String title,
    required String description,
  }) async {
    final updated = routine.copyWith(
      steps: [
        for (final step in routine.steps)
          step.copyWith(
            // 서버 RoutineStepResponse에는 title이 없다
            title: '',
            description: step.id == stepId ? description : step.description,
          ),
      ],
    );
    return (routine: updated, failure: synced ? null : const AppFailure(fault: NetworkFault.app));
  }

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async =>
      null;

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
    String rewardText = '',
    String rewardPresetKey = '',
    String idempotencyKey = '',
  }) async => const Routine(id: 'r1');

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async =>
      const RoutineQuestion();

  @override
  Future<List<Routine>> getMyRoutines() async => const [];

  @override
  Future<List<Routine>> getTodayRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];
}
