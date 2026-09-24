import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_dio.dart';
import 'helpers/test_storage.dart';

/// 추가 질문을 받아 오는 길 (#393 S1 · S2).
///
/// - **S1** 오프라인이면 입력과 무관한 대체 질문(`비 오는 날 준비물`)이 떴다.
///   이제 연결 안내와 다시 하기를 띄우고(#352 규칙), 서버가 응답은 했는데 실패면
///   질문 없이 카드 만들기로 넘어간다. 어느 쪽이든 **입력과 무관한 질문은 없다.**
/// - **S2** 보상으로 되돌아갔다 오면 전에 고른 답이 새 질문 옆에 남았다. 입력이
///   같으면 같은 질문을 다시 쓰고 답도 남기며, 바뀌었으면 새로 받고 답을 비운다.
const _rain = {
  'required': true,
  'questions': [
    {
      'question': '비 오는 날 챙길 것이 있나요?',
      'options': [
        {'emoji': '☂️', 'label': '우산'},
      ],
    },
  ],
};

const _swim = {
  'required': true,
  'questions': [
    {
      'question': '수영장에 가져갈 것이 있나요?',
      'options': [
        {'emoji': '🩱', 'label': '수영복'},
      ],
    },
  ],
};

/// 경로별 응답을 테스트 도중에 바꿀 수 있는 Dio (비행기 모드를 켰다 끄기).
({Dio dio, FakeAdapter adapter, Map<String, Object?> routes}) _dio(
  Object? questions,
) {
  final routes = <String, Object?>{'POST /api/routines/questions': questions};
  final adapter = FakeAdapter(routes);
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
    ..httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter, routes: routes);
}

int _questionCalls(FakeAdapter a) =>
    a.calls.where((c) => c == 'POST /api/routines/questions').length;

void main() {
  group('저장소 — 실패해도 입력과 무관한 질문을 만들지 않는다 (S1)', () {
    test('서버에 닿지 못하면 연결 실패를 알린다 — 대체 질문을 주지 않는다', () async {
      final repo = RoutineRepositoryImpl(dio: _dio(const FakeOffline()).dio);

      await expectLater(
        repo.generateQuestion('수영장 가기'),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.fault,
            'fault',
            NetworkFault.offline,
          ),
        ),
      );
    });

    test('서버가 실패를 돌려주면 질문 없이 넘어간다', () async {
      final repo = RoutineRepositoryImpl(
        dio: _dio(
          const FakeHttpError(502, errorCode: 'ROUTINE_AI_GENERATION_FAILED'),
        ).dio,
      );

      final question = await repo.generateQuestion('수영장 가기');

      expect(question.askable, isEmpty);
    });
  });

  // 크레딧이 막으면 질문 없이 넘겨도 카드 만들기에서 똑같이 막힌다 (#407).
  // 질문을 건너뛰고 생성 로딩까지 끌고 가지 않고 질문 단계에서 멈춘다.
  group('저장소 — 크레딧이 막으면 질문 단계에서 멈춘다 (#407)', () {
    for (final (status, code) in [
      (403, 'AI_CREDIT_INSUFFICIENT'),
      (403, 'AI_CREDIT_ACCOUNT_FROZEN'),
      (409, 'AI_CREDIT_JOB_IN_PROGRESS'),
    ]) {
      test('$code 는 질문 없이 넘기지 않고 실패를 던진다', () async {
        final repo = RoutineRepositoryImpl(
          dio: _dio(FakeHttpError(status, errorCode: code)).dio,
        );

        await expectLater(
          repo.generateQuestion('수영장 가기'),
          throwsA(
            isA<AppFailure>().having((f) => f.badgeOr('E-1003'), 'badge', code),
          ),
        );
      });
    }

    test('장부 오류(UNAVAILABLE)는 잠시 뒤 풀린다 — 지금처럼 질문 없이 넘어간다', () async {
      final repo = RoutineRepositoryImpl(
        dio: _dio(
          const FakeHttpError(503, errorCode: 'AI_CREDIT_UNAVAILABLE'),
        ).dio,
      );

      final question = await repo.generateQuestion('수영장 가기');

      expect(question.askable, isEmpty);
    });
  });

  group('흐름 — 답은 그 질문을 만든 입력에 딸린다 (S2)', () {
    late ProviderContainer container;
    late ({Dio dio, FakeAdapter adapter, Map<String, Object?> routes}) net;

    RoutineFlowNotifier notifier() =>
        container.read(routineFlowProvider.notifier);
    RoutineFlowState state() => container.read(routineFlowProvider);

    setUp(() {
      net = _dio(_rain);
      container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(net.dio),
          testStorageOverride(onboardingCompleted: true),
        ],
      );
      addTearDown(container.dispose);
    });

    test('입력이 같으면 같은 질문을 다시 쓰고 고른 답을 남긴다 — 다시 묻지 않는다', () async {
      notifier().setRawInput('비 오는 날 등교');
      await notifier().askQuestion();
      notifier().toggleAnswer('우산');
      notifier().addCustomOption('비 오는 날 챙길 것이 있나요?', '장화');

      // 보상으로 되돌아갔다가 다시 다음 → 준비 로딩이 또 묻는다
      await notifier().askQuestion();

      expect(state().answers, ['우산', '장화']);
      expect(state().customOptions['비 오는 날 챙길 것이 있나요?'], ['장화']);
      expect(state().question?.askable.single.question, '비 오는 날 챙길 것이 있나요?');
      // 같은 입력으로 AI 를 또 부르지 않는다 — 한 번이 곧 비용이다
      expect(_questionCalls(net.adapter), 1);
    });

    test('입력을 바꿨으면 새 질문을 받고 옛 답을 비운다', () async {
      notifier().setRawInput('비 오는 날 등교');
      await notifier().askQuestion();
      notifier().toggleAnswer('우산');
      notifier().addCustomOption('비 오는 날 챙길 것이 있나요?', '장화');

      net.routes['POST /api/routines/questions'] = _swim;
      notifier().setRawInput('수영장 가기');
      await notifier().askQuestion();

      expect(state().question?.askable.single.question, '수영장에 가져갈 것이 있나요?');
      expect(state().answers, isEmpty);
      expect(state().customOptions, isEmpty);
      expect(_questionCalls(net.adapter), 2);
    });

    test('입력을 고쳤다가 원래대로 돌려 놓으면 같은 입력이다 — 답을 남긴다', () async {
      notifier().setRawInput('비 오는 날 등교');
      await notifier().askQuestion();
      notifier().toggleAnswer('우산');

      notifier().setRawInput('비 오는 날 등교하');
      notifier().setRawInput('비 오는 날 등교');
      await notifier().askQuestion();

      expect(state().answers, ['우산']);
      expect(_questionCalls(net.adapter), 1);
    });

    test('S1 오프라인이면 흐름이 오류로 서고 연결 안내를 담는다', () async {
      net.routes['POST /api/routines/questions'] = const FakeOffline();
      notifier().setRawInput('수영장 가기');
      await notifier().askQuestion();

      expect(state().step, RoutineFlowStep.error);
      expect(state().question, isNull);
      expect(state().errorCode, 'E-NET-OFFLINE');
      expect(state().errorHint, '인터넷 연결을 확인해주세요');
    });

    test('S1 오프라인으로 실패한 뒤 다시 묻는다 — 실패는 캐시하지 않는다', () async {
      net.routes['POST /api/routines/questions'] = const FakeOffline();
      notifier().setRawInput('수영장 가기');
      await notifier().askQuestion();

      net.routes['POST /api/routines/questions'] = _swim;
      await notifier().retryQuestion();

      expect(state().step, RoutineFlowStep.question);
      expect(state().errorCode, isNull);
      expect(state().question?.askable.single.question, '수영장에 가져갈 것이 있나요?');
    });
  });

  group('준비 로딩 — 오프라인 (S1)', () {
    Future<Map<String, Object?>> pumpPrepare(WidgetTester tester) async {
      final net = _dio(const FakeOffline());
      final router = GoRouter(
        initialLocation: '/loading',
        routes: [
          GoRoute(
            path: '/loading',
            builder: (context, state) =>
                const RoutineLoadingScreen(kind: RoutineLoadingKind.prepare),
          ),
          GoRoute(
            path: Routes.routineQuestion,
            builder: (context, state) => const Scaffold(body: Text('추가 질문')),
          ),
          GoRoute(
            path: Routes.routineGenerating,
            builder: (context, state) => const Scaffold(body: Text('카드 생성 로딩')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(net.dio),
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
      return net.routes;
    }

    testWidgets('입력과 무관한 질문 대신 연결 안내와 다시 하기를 띄운다', (tester) async {
      await pumpPrepare(tester);

      expect(find.text('추가 질문'), findsNothing, reason: '입력과 무관한 질문을 보여주면 안 된다');
      expect(find.text('카드 생성 로딩'), findsNothing, reason: '오프라인이면 만들기도 실패한다');
      expect(find.text('질문을 준비하지 못했어요'), findsOneWidget);
      expect(find.text('인터넷 연결을 확인해주세요'), findsOneWidget);
      expect(find.text('E-NET-OFFLINE'), findsOneWidget);
      expect(find.text('다시 하기'), findsOneWidget);
    });

    testWidgets('다시 하기는 카드를 만들지 않고 질문을 다시 받는다', (tester) async {
      final routes = await pumpPrepare(tester);
      routes['POST /api/routines/questions'] = _swim;

      await tester.tap(find.text('다시 하기'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('추가 질문'), findsOneWidget);
    });
  });
}
