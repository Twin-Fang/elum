import 'dart:async';

import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/credit_fixtures.dart';
import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 크레딧이 생성 흐름을 막는 자리 (#407 스펙 §5) — 홈 시작 전 · 생성 실패 화면.
void main() {
  useFigmaViewport();

  group('홈 — 일과 만들기 전에 막는다', () {
    Future<GoRouter> pumpHomeOnly(
      WidgetTester tester,
      CreditRepository credit,
    ) async {
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
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            testStorageOverride(onboardingCompleted: true),
            routineRepositoryProvider.overrideWithValue(_HomeRepo()),
            memberProvider.overrideWith((ref) async => null),
            creditRepositoryProvider.overrideWithValue(credit),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) =>
                MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    Future<void> pumpHome(WidgetTester tester, CreditRepository credit) async {
      await pumpHomeOnly(tester, credit);
      await tester.tap(find.text('새로운 일과 만들기'));
      await tester.pumpAndSettle();
    }

    testWidgets('다 썼으면 팝업을 띄우고 들어가지 않는다', (tester) async {
      await pumpHome(
        tester,
        _FakeCredit(CreditSummary.fromJson(creditJson(available: 0))),
      );

      expect(find.text('이번 주 크레딧을 모두 사용했어요'), findsOneWidget);
      expect(find.text('9월 28일(월) 0시부터 다시 만들 수 있어요'), findsOneWidget);
      expect(find.text('일과 입력'), findsNothing);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('이번 주 크레딧을 모두 사용했어요'), findsNothing);
      expect(find.text('일과 입력'), findsNothing);
    });

    testWidgets('남아 있으면 바로 들어간다', (tester) async {
      await pumpHome(tester, _FakeCredit(CreditSummary.fromJson(creditJson())));

      expect(find.text('일과 입력'), findsOneWidget);
    });

    testWidgets('꺼져 있으면 막지 않는다', (tester) async {
      await pumpHome(tester, _FakeCredit(const CreditSummary.disabled()));

      expect(find.text('일과 입력'), findsOneWidget);
    });

    testWidgets('조회에 실패하면 막지 않는다 — 판정은 서버가 한다', (tester) async {
      await pumpHome(tester, _FakeCredit(null));

      expect(find.text('일과 입력'), findsOneWidget);
      expect(find.text('이번 주 크레딧을 모두 사용했어요'), findsNothing);
   
    });

    // 조회를 기다리는 동안 한 번 더 누르면 입력 화면이 두 번 쌓였다.
    testWidgets('조회 중에 두 번 누르면 한 번만 들어간다', (tester) async {
      final credit = _SlowCredit();
      final router = await pumpHomeOnly(tester, credit);

      await tester.tap(find.text('새로운 일과 만들기'));
      await tester.pump();
      await tester.tap(find.text('새로운 일과 만들기'));
      await tester.pump();
      credit.complete(CreditSummary.fromJson(creditJson()));
      await tester.pumpAndSettle();

      expect(credit.calls, 1, reason: '두 번째 누름은 조회도 하지 않는다');
      expect(find.text('일과 입력'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('일과 입력'), findsNothing, reason: '쌓인 입력 화면은 하나뿐이다');
      expect(find.text('새로운 일과 만들기'), findsOneWidget);
    });

    testWidgets('조회가 3초를 넘기면 기다리지 않고 들여보낸다 — 판정은 서버가 한다', (tester) async {
      final credit = _SlowCredit();
      await pumpHomeOnly(tester, credit);

      await tester.tap(find.text('새로운 일과 만들기'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('일과 입력'), findsNothing, reason: '3초 안에는 조회를 기다린다');

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('일과 입력'), findsOneWidget);

      // 뒤늦게 온 응답이 막힘 팝업을 띄우지 않는다.
      credit.complete(CreditSummary.fromJson(creditJson(available: 0)));
      await tester.pumpAndSettle();
      expect(find.text('이번 주 크레딧을 모두 사용했어요'), findsNothing);
    });
  });

  group('생성 실패 화면 — 크레딧 오류면 다시 하기 대신 홈으로', () {
    Future<void> pumpError(WidgetTester tester, String code) async {
      final router = GoRouter(
        initialLocation: '/loading',
        routes: [
          GoRoute(
            path: '/loading',
            builder: (context, state) =>
                const RoutineLoadingScreen(kind: RoutineLoadingKind.generate),
          ),
          GoRoute(
            path: Routes.guardian,
            builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fakeDioOverride({
              'POST /api/routines': FakeHttpError(
                403,
                errorCode: code,
                errorMessage: '서버가 준 문구',
              ),
            }),
            testStorageOverride(onboardingCompleted: true),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) =>
                MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 450));
    }

    for (final code in [
      'AI_CREDIT_INSUFFICIENT',
      'AI_CREDIT_JOB_IN_PROGRESS',
      'AI_CREDIT_ACCOUNT_FROZEN',
    ]) {
      testWidgets('$code — 다시 하기를 숨기고 홈으로를 둔다', (tester) async {
        await pumpError(tester, code);

        expect(find.text('카드를 만들지 못했어요'), findsOneWidget);
        expect(find.text('서버가 준 문구'), findsOneWidget);
        expect(find.text(code), findsOneWidget, reason: '추적 코드는 그대로 보인다');
        expect(find.text('다시 하기'), findsNothing);

        await tester.tap(find.text('홈으로'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        expect(find.text('보호자 홈'), findsOneWidget);
      });
    }

    testWidgets('장부 오류(UNAVAILABLE)는 잠시 뒤 다시 하면 된다 — 다시 하기', (tester) async {
      await pumpError(tester, 'AI_CREDIT_UNAVAILABLE');

      expect(find.text('다시 하기'), findsOneWidget);
      expect(find.text('홈으로'), findsNothing);
    });
  });

  // 질문 요청에서 크레딧이 막혔는데 질문 없이 넘기면 생성 로딩까지 가서야 막힌다.
  // 준비 로딩에서 바로 멈추고 같은 오류 화면을 띄운다.
  group('준비 로딩 — 질문 요청이 크레딧으로 막히면 거기서 멈춘다', () {
    testWidgets('AI_CREDIT_INSUFFICIENT — 생성 로딩으로 넘기지 않고 홈으로를 둔다', (tester) async {
      final router = GoRouter(
        initialLocation: '/loading',
        routes: [
          GoRoute(
            path: '/loading',
            builder: (context, state) =>
                const RoutineLoadingScreen(kind: RoutineLoadingKind.prepare),
          ),
          GoRoute(
            path: Routes.routineGenerating,
            builder: (context, state) => const Scaffold(body: Text('카드 생성 로딩')),
          ),
          GoRoute(
            path: Routes.routineQuestion,
            builder: (context, state) => const Scaffold(body: Text('추가 질문')),
          ),
          GoRoute(
            path: Routes.guardian,
            builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fakeDioOverride({
              'POST /api/routines/questions': const FakeHttpError(
                403,
                errorCode: 'AI_CREDIT_INSUFFICIENT',
                errorMessage: '서버가 준 문구',
              ),
            }),
            testStorageOverride(onboardingCompleted: true),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) =>
                MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('카드 생성 로딩'), findsNothing);
      expect(find.text('질문을 준비하지 못했어요'), findsOneWidget);
      expect(find.text('서버가 준 문구'), findsOneWidget);
      expect(find.text('AI_CREDIT_INSUFFICIENT'), findsOneWidget);
      expect(find.text('다시 하기'), findsNothing);

      await tester.tap(find.text('홈으로'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('보호자 홈'), findsOneWidget);
    });
  });
}

/// 조회가 끝나는 때를 테스트가 정한다.
class _SlowCredit extends CreditRepository {
  _SlowCredit() : super(Dio());

  final _done = Completer<CreditSummary>();
  var calls = 0;

  void complete(CreditSummary summary) => _done.complete(summary);

  @override
  Future<CreditSummary> getMine() {
    calls++;
    return _done.future;
  }
}

/// [summary] 가 null 이면 조회에 실패한다.
class _FakeCredit extends CreditRepository {
  _FakeCredit(this.summary) : super(Dio());

  final CreditSummary? summary;

  @override
  Future<CreditSummary> getMine() async {
    final s = summary;
    if (s == null) throw const AppFailure(fault: NetworkFault.offline);
    return s;
  }
}

class _HomeRepo with FakeRewardApi implements RoutineRepository {
  @override
  Future<List<Routine>> getMyRoutines() async => const [];
  @override
  Future<List<Routine>> getTodayRoutines() async => const [];
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
  Future<AppFailure?> deleteStep(String routineId, String stepId) async => null;
  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async => (routine: routine, failure: null);
}
