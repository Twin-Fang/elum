import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/presentation/question_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';

import 'helpers/test_storage.dart';

/// Figma `보호자_새로운 일과 만들기_추가질문`(262:4766 / 262:4854) 정합 테스트.
///
/// 두 프레임의 차이는 선택 여부다 — 아무것도 고르지 않으면 CTA가 없고,
/// 하나라도 고르면 `카드 만들기`가 나타난다.
void main() {
  /// 서버가 주는 다중 질문 (실측 응답 형태)
  const twoQuestions = RoutineQuestion(
    isRequired: true,
    questions: [
      QuestionItem(
        question: '꼭 챙겨야 하는 준비물이 있나요?',
        options: ['우산', '우비', '장화'],
      ),
      QuestionItem(
        question: '평소와 다르게 준비해야 하는 점이 있나요?',
        options: ['시간 변경', '장소 변경'],
      ),
    ],
  );

  Widget wrap(RoutineQuestion question) {
    final router = GoRouter(
      initialLocation: Routes.routineQuestion,
      routes: [
        GoRoute(
          path: Routes.routineQuestion,
          builder: (context, state) => const QuestionScreen(),
        ),
        // 질문 다음은 카드 생성 로딩(262:4703)이다
        GoRoute(
          path: Routes.routineGenerating,
          builder: (context, state) => const Scaffold(body: Text('로딩 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        // 테스트 전용 setter를 만들지 않고 저장소를 갈아끼운다
        routineRepositoryProvider.overrideWithValue(_FakeRepo(question)),
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

  /// 배경이 무한 반복하므로 pumpAndSettle을 쓸 수 없다
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// 질문을 받아온 상태로 화면을 띄운다
  Future<ProviderContainer> pumpWith(
    WidgetTester tester,
    RoutineQuestion question,
  ) async {
    await tester.pumpWidget(wrap(question));
    await settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuestionScreen)),
    );
    // 입력 화면이 하는 일을 그대로 한다
    await container.read(routineFlowProvider.notifier).askQuestion();
    await settle(tester);
    return container;
  }

  group('추가질문 화면', () {
    testWidgets('배경 글로우는 그대로 있다 (이슈 #79 회귀 방지)', (tester) async {
      // 카드확인 화면만 글로우를 껐다. 공통 스캐폴드를 고쳤으므로
      // 나머지 화면이 함께 꺼지지 않았는지 여기서 잡는다.
      await pumpWith(tester, twoQuestions);

      expect(find.byType(AuroraBackground), findsOneWidget);
    });

    testWidgets('질문 여러 개를 모두 보여준다', (tester) async {
      // 서버가 도움 목표마다 하나씩 준다. Figma는 하나만 그렸지만 2개 이상 온다.
      await pumpWith(tester, twoQuestions);

      expect(find.text('꼭 챙겨야 하는 준비물이 있나요?'), findsOneWidget);
      expect(find.text('평소와 다르게 준비해야 하는 점이 있나요?'), findsOneWidget);
    });

    testWidgets('선택지를 모두 보여준다', (tester) async {
      await pumpWith(tester, twoQuestions);

      for (final option in ['우산', '우비', '장화', '시간 변경', '장소 변경']) {
        expect(find.text(option), findsOneWidget);
      }
    });

    testWidgets('고르기 전에는 CTA가 없다 (262:4766)', (tester) async {
      await pumpWith(tester, twoQuestions);

      expect(find.byType(ElumButton), findsNothing);
    });

    testWidgets('하나라도 고르면 CTA가 나타난다 (262:4854)', (tester) async {
      await pumpWith(tester, twoQuestions);

      await tester.tap(find.text('우산'));
      await settle(tester);

      expect(find.text('카드 만들기'), findsOneWidget);
    });

    testWidgets('여러 질문에 걸쳐 답을 고를 수 있다', (tester) async {
      final container = await pumpWith(tester, twoQuestions);

      await tester.tap(find.text('우산'));
      await settle(tester);
      await tester.tap(find.text('시간 변경'));
      await settle(tester);

      final answers = container.read(routineFlowProvider).answers;
      expect(answers, containsAll(['우산', '시간 변경']));
    });

    testWidgets('다시 누르면 선택이 풀린다', (tester) async {
      final container = await pumpWith(tester, twoQuestions);

      await tester.tap(find.text('우산'));
      await settle(tester);
      await tester.tap(find.text('우산'));
      await settle(tester);

      expect(container.read(routineFlowProvider).answers, isEmpty);
      // 선택이 없으면 CTA도 사라진다
      expect(find.byType(ElumButton), findsNothing);
    });

    testWidgets('CTA를 누르면 로딩 화면으로 간다', (tester) async {
      await pumpWith(tester, twoQuestions);

      await tester.tap(find.text('우산'));
      await settle(tester);
      await tester.tap(find.text('카드 만들기'));
      await settle(tester);

      expect(find.text('로딩 화면'), findsOneWidget);
    });

    testWidgets('질문이 없으면 로딩 화면으로 건너뛴다', (tester) async {
      // 도움 목표를 고르지 않으면 서버가 빈 배열을 준다(실측 확인).
      // 빈 화면을 보여주면 안 된다.
      await pumpWith(
        tester,
        const RoutineQuestion(isRequired: false),
      );
      // 이동은 첫 프레임이 끝난 뒤 일어난다
      await settle(tester);

      expect(find.text('로딩 화면'), findsOneWidget);
    });
  });

  /// Figma `보호자_새로운 일과 만들기_키보드`(262:3074)의 입력 필드(262:4089).
  ///
  /// 선택지에 없는 준비물을 보호자가 직접 적는다. 서버 선택지는 AI가 만든 것이라
  /// 실제 상황(병원 진료카드 등)을 다 담지 못한다.
  group('직접 입력하기', () {
    testWidgets('질문마다 + 직접 입력하기 칩이 있다', (tester) async {
      await pumpWith(tester, twoQuestions);

      // 질문이 2개면 칩도 2개 — 어느 질문에 추가하는지 구분돼야 한다
      expect(find.text('+ 직접 입력하기'), findsNWidgets(2));
    });

    testWidgets('누르면 입력 필드가 열린다', (tester) async {
      await pumpWith(tester, twoQuestions);

      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('+ 직접 입력하기').first);
      await settle(tester);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('입력하고 확정하면 칩으로 추가되고 선택된다', (tester) async {
      final container = await pumpWith(tester, twoQuestions);

      await tester.tap(find.text('+ 직접 입력하기').first);
      await settle(tester);
      await tester.enterText(find.byType(TextField), '진료카드');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      // 칩으로 보이고
      expect(find.text('진료카드'), findsOneWidget);
      // 바로 선택돼 CTA가 뜬다 — 쓰자마자 또 눌러야 하면 번거롭다
      expect(container.read(routineFlowProvider).answers, contains('진료카드'));
      expect(find.text('카드 만들기'), findsOneWidget);
    });

    testWidgets('빈 값은 추가되지 않는다', (tester) async {
      final container = await pumpWith(tester, twoQuestions);

      await tester.tap(find.text('+ 직접 입력하기').first);
      await settle(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(container.read(routineFlowProvider).answers, isEmpty);
    });

    testWidgets('이미 있는 선택지를 적으면 칩을 새로 만들지 않고 그것을 선택한다', (tester) async {
      final container = await pumpWith(tester, twoQuestions);

      await tester.tap(find.text('+ 직접 입력하기').first);
      await settle(tester);
      await tester.enterText(find.byType(TextField), '우산');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      // 칩이 두 개가 되면 안 된다
      expect(find.text('우산'), findsOneWidget);
      expect(container.read(routineFlowProvider).answers, contains('우산'));
    });

    testWidgets('추가한 칩은 X로 지운다 — 답에서도 빠진다', (tester) async {
      final container = await pumpWith(tester, twoQuestions);

      await tester.tap(find.text('+ 직접 입력하기').first);
      await settle(tester);
      await tester.enterText(find.byType(TextField), '진료카드');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('remove-진료카드')));
      await settle(tester);

      expect(find.text('진료카드'), findsNothing);
      expect(container.read(routineFlowProvider).answers, isNot(contains('진료카드')));
    });

    testWidgets('서버 선택지에는 X가 없다 — 지울 수 있는 건 내가 쓴 것뿐', (tester) async {
      await pumpWith(tester, twoQuestions);

      expect(find.byKey(const ValueKey('remove-우산')), findsNothing);
    });

    testWidgets('추가한 칩은 다시 눌러 선택을 풀 수 있다', (tester) async {
      final container = await pumpWith(tester, twoQuestions);

      await tester.tap(find.text('+ 직접 입력하기').first);
      await settle(tester);
      await tester.enterText(find.byType(TextField), '진료카드');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      await tester.tap(find.text('진료카드'));
      await settle(tester);

      // 칩은 남아 있고 선택만 풀린다
      expect(find.text('진료카드'), findsOneWidget);
      expect(container.read(routineFlowProvider).answers, isEmpty);
    });
  });

  group('RoutineQuestion 파싱 (서버 계약)', () {
    test('서버 응답 형태를 그대로 파싱한다', () {
      // 실측 응답: {"required":true,"questions":[{question, options}]}
      final parsed = RoutineQuestion.fromJson(const {
        'required': true,
        'questions': [
          {
            'question': '꼭 챙겨야 하는 준비물이 있나요?',
            'options': ['우산', '우비'],
          },
        ],
      });

      expect(parsed.isRequired, isTrue);
      expect(parsed.questions.length, 1);
      expect(parsed.questions.first.options, ['우산', '우비']);
      expect(parsed.canAsk, isTrue);
    });

    test('질문이 비면 물어볼 수 없다', () {
      final parsed = RoutineQuestion.fromJson(const {
        'required': false,
        'questions': <dynamic>[],
      });

      expect(parsed.canAsk, isFalse);
    });

    test('required가 true여도 질문이 비면 물어볼 수 없다', () {
      final parsed = RoutineQuestion.fromJson(const {
        'required': true,
        'questions': <dynamic>[],
      });

      expect(parsed.canAsk, isFalse);
    });

    test('형식이 달라도 죽지 않는다', () {
      // 카드 한 장 때문에 데모가 멈추면 안 된다
      expect(
        () => RoutineQuestion.fromJson(const {'questions': 'not-a-list'}),
        returnsNormally,
      );
    });
  });
}

/// 정해진 질문만 돌려주는 저장소. 실서버를 타지 않는다.
class _FakeRepo implements RoutineRepository {
  _FakeRepo(this.question);

  final RoutineQuestion question;

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async =>
      question;

  @override
  Future<List<Routine>> getMyRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async =>
      RoutineSuggestion.fallback;

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
  }) async =>
      const Routine(id: 'test');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<({Routine routine, bool synced})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async =>
      (routine: routine, synced: true);

  @override
  Future<List<Routine>> getTodayRoutines() async => const [];
}
