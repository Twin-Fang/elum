import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:elum/features/guardian/presentation/widgets/card_edit_sheet.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

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
    test('진행률 필드를 읽는다', () {
      final parsed = Routine.fromJson(const {
        'id': 'r1',
        'title': '오늘 일과',
        'status': 'CONFIRMED',
        'completedStepCount': 2,
        'totalStepCount': 5,
        'progressPercent': 40,
      });

      expect(parsed.completedStepCount, 2);
      expect(parsed.totalStepCount, 5);
      expect(parsed.progressPercent, 40);
    });

    test('진행률이 문자열로 와도 죽지 않는다', () {
      final parsed = Routine.fromJson(const {
        'id': 'r1',
        'progressPercent': '40',
        'totalStepCount': '이상한값',
      });

      expect(parsed.progressPercent, 40);
      expect(parsed.totalStepCount, 0);
    });

    test('COMPLETED 일과도 아이 화면에 보인다', () {
      // /today가 CONFIRMED와 COMPLETED를 함께 준다 —
      // isConfirmed만 걸면 다 끝낸 일과가 목록에서 사라진다
      const done = Routine(id: 'r2', status: 'COMPLETED');
      const pending = Routine(id: 'r3', status: 'PENDING_REVIEW');

      expect(done.isVisibleToChild, isTrue);
      expect(pending.isVisibleToChild, isFalse, reason: '미승인은 아동에게 노출 금지');
    });
  });

  group('RoutineFlowNotifier.updateStep — 제목·설명 수정 (이슈 #77)', () {
    ProviderContainer containerWith(_FakeRepo repo) {
      final container = ProviderContainer(
        overrides: [
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      container.read(routineFlowProvider.notifier).state =
          const RoutineFlowState(routine: routine);
      return container;
    }

    test('제목과 설명이 함께 바뀐다', () async {
      final container = containerWith(_FakeRepo(synced: true));

      final synced = await container
          .read(routineFlowProvider.notifier)
          .updateStep(stepId: 'c1', title: '새 제목', description: '새 설명');

      final steps = container.read(routineFlowProvider).routine!.steps;
      expect(synced, isTrue);
      expect(steps.first.title, '새 제목');
      expect(steps.first.description, '새 설명');
    });

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

    test('서버 반영 실패 시 로컬은 반영되고 false를 돌려준다', () async {
      final container = containerWith(_FakeRepo(synced: false));

      final synced = await container
          .read(routineFlowProvider.notifier)
          .updateStep(stepId: 'c1', title: '새 제목', description: '새 설명');

      final steps = container.read(routineFlowProvider).routine!.steps;
      expect(synced, isFalse);
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
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(repo),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
    }

    /// 화면을 띄우고 일과를 주입한다.
    /// AuroraBackground가 무한 애니메이션이라 pumpAndSettle은 쓸 수 없다.
    Future<void> pumpReview(WidgetTester tester, _FakeRepo repo) async {
      await tester.pumpWidget(wrap(repo));
      final context = tester.element(find.byType(CardReviewScreen));
      ProviderScope.containerOf(context, listen: false)
          .read(routineFlowProvider.notifier)
          .state = const RoutineFlowState(routine: routine);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('수정 칩이 있고 삭제 X는 에셋으로 그린다', (tester) async {
      await pumpReview(tester, _FakeRepo(synced: true));

      expect(find.text('이 카드 수정하기'), findsOneWidget);
      // 흐린 원 + X는 코드로 그리지 않는다 — Figma 393:4010 에셋
      expect(svgWithAsset(AppAssets.iconCardDelete), findsWidgets);
      // 이전 시안의 이미지 위 버튼은 사라졌다
      expect(find.text('완료'), findsNothing);
    });

    testWidgets('배경에 블러 글로우가 없다 (이슈 #79)', (tester) async {
      // Figma 262:5124의 프레임 배경은 단색 #F7F2EF 하나뿐이다.
      // 글로우는 입력 화면 시안(238:1728)의 것으로, 공통 스캐폴드를 타고
      // 여기까지 새어 나왔었다.
      await pumpReview(tester, _FakeRepo(synced: true));

      expect(find.byType(AuroraBackground), findsNothing);
    });

    testWidgets('카드가 없어도 글로우가 없다 (이슈 #79)', (tester) async {
      // 빈 상태도 같은 시안을 따른다 — 여기만 배경이 달라지면 눈에 띈다
      await tester.pumpWidget(wrap(_FakeRepo(synced: true)));
      await tester.pump();

      expect(find.byType(AuroraBackground), findsNothing);
    });

    testWidgets('칩을 누르면 수정 시트가 뜨고 저장하면 카드가 바뀐다', (tester) async {
      await pumpReview(tester, _FakeRepo(synced: true));

      await tester.tap(find.text('이 카드 수정하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('카드 수정하기'), findsOneWidget);

      // 첫 필드가 제목, 둘째가 설명
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '가방을 싸요');
      await tester.enterText(fields.last, '책과 준비물을 가방에 넣어요');
      await tester.tap(find.text('저장하기').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('카드 수정하기'), findsNothing, reason: '저장하면 시트가 닫힌다');
      expect(find.text('가방을 싸요'), findsOneWidget);
      expect(find.text('책과 준비물을 가방에 넣어요'), findsOneWidget);
    });

    testWidgets('제목을 지우면 저장할 수 없다', (tester) async {
      await pumpReview(tester, _FakeRepo(synced: true));

      await tester.tap(find.text('이 카드 수정하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      await tester.tap(find.text('저장하기').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('카드 수정하기'), findsOneWidget,
          reason: '빈 제목으로는 저장되지 않고 시트가 남는다');
    });

    testWidgets('서버 반영 실패 시 에러 코드를 보여준다', (tester) async {
      await pumpReview(tester, _FakeRepo(synced: false));

      await tester.tap(find.text('이 카드 수정하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('저장하기').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('E-STEP'), findsOneWidget);
    });
  });

  group('아이 일과 상세 상단바 (Figma 309:3548, 2026-07-22 시안)', () {
    Widget wrapDetail() {
      return ProviderScope(
        overrides: [testStorageOverride(onboardingCompleted: true)],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: const ChildRoutineDetailScreen(routine: routine),
          ),
        ),
      );
    }

    testWidgets('일과 제목이 상단에 뜨고 캐릭터 배지는 없다', (tester) async {
      await tester.pumpWidget(wrapDetail());
      await tester.pump();

      expect(find.text('비 오는 날 학교에 가요'), findsOneWidget);
      // ignore: deprecated_member_use_from_same_package
      expect(svgWithAsset(AppAssets.characterBadgeRuru), findsNothing);
    });
  });
}

/// 서버 흉내 저장소. [synced]로 서버 반영 성공/실패를 가른다.
///
/// updateStep 응답은 실제 서버처럼 **step title 없이** 돌아온다 —
/// notifier의 제목 복원 로직이 이 조건에서 검증된다.
class _FakeRepo implements RoutineRepository {
  _FakeRepo({required this.synced});

  final bool synced;

  @override
  Future<({Routine routine, bool synced})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async {
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
    return (routine: updated, synced: synced);
  }

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
  }) async =>
      const Routine(id: 'r1');

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
