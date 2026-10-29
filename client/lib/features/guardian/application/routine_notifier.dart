import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../shared/models/routine.dart';
import '../../credit/data/credit_repository.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import 'routine_flow_state.dart';
import 'routine_providers.dart';
import 'routine_step_editing.dart';

final routineFlowProvider =
    NotifierProvider<RoutineFlowNotifier, RoutineFlowState>(
      RoutineFlowNotifier.new,
    );

/// 일과 입력 → 질문 → 카드 생성 → 승인 흐름을 관리한다.
///
/// 어떤 단계도 예외를 던지지 않는다. repository가 실패를 흡수하므로
/// 화면은 항상 다음 단계로 진행할 수 있다.
class RoutineFlowNotifier extends Notifier<RoutineFlowState>
    with RoutineStepEditing {
  @override
  RoutineFlowState build() => const RoutineFlowState();

  void setRawInput(String value) {
    // 입력마다 불려 원문 대신 글자 수만 (docs 원칙 5번)
    AppLogger.notifierCall('RoutineFlowNotifier', 'setRawInput', {
      'inputLength': value.length,
    });
    state = state.copyWith(rawInput: value);
  }

  /// AI 추가 질문을 받아온다.
  ///
  /// **여기서 카드를 생성하지 않는다.** 질문이 없으면 질문 화면이 스스로
  /// 로딩 화면으로 건너뛰고, 카드 생성은 로딩 화면 한 곳에서만 시작한다.
  /// 양쪽에서 생성하면 같은 일과가 두 번 만들어진다.
  Future<void> askQuestion() async {
    AppLogger.notifierCall('RoutineFlowNotifier', 'askQuestion');
    AppLogger.notifierStateChange(
      'RoutineFlowNotifier',
      state.step.name,
      'question',
    );

    // 같은 입력으로 이미 받은 질문이 있으면 그것을 다시 쓴다. 보상으로
    // 되돌아갔다 오면 여기가 또 불린다 — 다시 부르면 AI 비용이 한 번 더 들고, 질문이
    // 달라져 앞서 고른 답이 엉뚱한 질문 옆에 남는다. 서버 질문은 입력만 보고 만든다.
    final cached = state.question;
    if (cached != null && state.questionInput == state.rawInput) {
      state = state.copyWith(step: RoutineFlowStep.question);
      return;
    }

    final repo = ref.read(routineRepositoryProvider);
    final RoutineQuestion question;
    try {
      question = await repo.generateQuestion(state.rawInput);
    } catch (e) {
      // 서버에 닿지 못했다. 입력과 무관한 질문을 띄우지 않고 연결 안내와
      // 다시 하기를 띄운다 — 다음 단계(카드 만들기)도 같은 이유로 실패한다.
      final failure = AppFailure.of(e);
      AppLogger.notifierStateChange(
        'RoutineFlowNotifier',
        'question',
        'error',
        {'fault': failure.fault.name},
      );
      state = state.copyWith(
        step: RoutineFlowStep.error,
        errorCode: failure.badgeOr('E-1003'),
        errorMessage: failure.serverMessage,
        errorFault: failure.fault,
      );
      return;
    }

    // 새 질문이므로 이전 질문에 고른 답과 직접 적은 선택지를 비운다.
    state = RoutineFlowState(
      step: RoutineFlowStep.question,
      rawInput: state.rawInput,
      question: question,
      questionInput: state.rawInput,
      rewardText: state.rewardText,
      rewardPresetKey: state.rewardPresetKey,
      routine: state.routine,
    );
    AppLogger.notifierStateChange(
      'RoutineFlowNotifier',
      'question',
      'question',
      {'questionCount': question.askable.length},
    );
  }

  /// 질문 받기가 실패한 뒤 다시 한다. 카드를 만들지 않는다 —
  /// 준비 로딩의 `다시 하기`가 카드 생성 재시도로 이어지면 질문을 건너뛴다.
  Future<void> retryQuestion() {
    state = state.copyWith(step: RoutineFlowStep.input);
    return askQuestion();
  }

  void toggleAnswer(String answer) {
    final next = List<String>.from(state.answers);
    next.contains(answer) ? next.remove(answer) : next.add(answer);
    state = state.copyWith(answers: next);
  }

  /// 보호자가 직접 적은 선택지를 [question]에 추가하고 곧바로 선택한다.
  ///
  /// 쓰자마자 또 눌러야 하면 번거로우므로 추가와 선택을 함께 한다.
  /// 빈 값은 무시하고, 이미 있는 값이면 칩을 새로 만들지 않고 선택만 한다 —
  /// 같은 이름의 칩이 둘 생기면 어느 쪽이 선택됐는지 알 수 없다.
  void addCustomOption(String question, String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return;

    final existing =
        state.question?.askable
            .firstWhere(
              (item) => item.question == question,
              orElse: () => const QuestionItem(question: '', options: []),
            )
            .options ??
        const <QuestionOption>[];
    final custom = state.customOptions[question] ?? const <String>[];
    final isDuplicate =
        existing.any((option) => option.label == value) ||
        custom.contains(value);

    final nextCustom = Map<String, List<String>>.from(state.customOptions);
    if (!isDuplicate) {
      nextCustom[question] = [...custom, value];
    }

    // 중복이어도 선택은 해준다 — 사용자는 그 항목을 원한다는 뜻이다
    final nextAnswers = List<String>.from(state.answers);
    if (!nextAnswers.contains(value)) nextAnswers.add(value);

    state = state.copyWith(customOptions: nextCustom, answers: nextAnswers);
  }

  /// 직접 추가한 선택지를 지운다. 선택도 함께 풀어야 답에 유령이 남지 않는다.
  void removeCustomOption(String question, String value) {
    final custom = state.customOptions[question];
    if (custom == null) return;

    final nextCustom = Map<String, List<String>>.from(state.customOptions)
      ..[question] = custom.where((o) => o != value).toList();

    state = state.copyWith(
      customOptions: nextCustom,
      answers: state.answers.where((a) => a != value).toList(),
    );
  }

  /// 진행 중인 카드 생성. 중복 호출을 막는 유일한 지점이다.
  ///
  /// **`POST /api/routines`는 AI 호출이라 한 번이 곧 비용이다.**
  /// 로딩 화면이 재생성되면(토큰 만료 리다이렉트, 화면 복귀 등) `initState`가
  /// 다시 돌아 [generateCards]를 또 부른다.
  ///
  /// 위젯이 아니라 여기서 막는 이유 — 위젯은 몇 번이든 다시 만들어지지만
  /// provider는 흐름이 끝날 때까지 살아 있다.
  Future<void>? _generating;

  /// 차단한 중복 호출 수. **0이 아니면 어딘가에서 또 부르고 있다는 신호다.**
  /// 로그로 남겨야 재발을 눈치챌 수 있다 — 조용히 막기만 하면 원인이 묻힌다.
  var _blockedCalls = 0;

  /// [RoutineFlowState.idempotencyKey]를 발급할 때의 요청 내용.
  ///
  /// 내용이 같으면 재시도라 같은 키, 다르면(되돌아가 입력·답·보상을 고쳤다) 새 요청이라
  /// 새 키다. 고친 요청에 이전 키를 실으면 서버는 이전 요청으로 보고 이전 일과를 준다.
  String? _keyIssuedFor;

  Future<void> generateCards() {
    // 진행 중이거나 이미 끝난 생성이 있으면 그것을 그대로 돌려준다.
    //
    // **성공한 뒤에도 가드를 풀지 않는다.** 풀면 로딩 화면이 나중에 다시
    // 만들어졌을 때 또 쏜다.
    // 새 일과를 만들 때는 홈에서 [reset]을 부르므로 그때 풀린다.
    final running = _generating;
    if (running != null) {
      _blockedCalls++;
      AppLogger.info(
        '[cost] duplicate card generation blocked (total $_blockedCalls) : '
        '${state.routine != null ? 'already generated' : 'in progress'}, no server request',
      );
      return running;
    }

    AppLogger.info(
      '[cost] card generation started : POST /api/routines (AI call, billed)',
    );
    return _generating = _createRoutine();
  }

  /// 카드 생성 실패 후 다시 시도한다. **로컬 가짜 일과를 만들지 않으므로**,
  /// 실패하면 오직 이 경로로 AI(`POST /api/routines`)를 다시 호출해야 한다.
  ///
  /// 가드([_generating])를 먼저 풀어야 재요청이 나간다 — 안 풀면 이전 실패한
  /// Future를 그대로 돌려줘 재시도가 무시된다.
  Future<void> retryGenerate() {
    _generating = null;
    return generateCards();
  }

  /// 보상을 정한다.
  ///
  /// [text]가 비면 **건너뛴 것**으로 본다 — 프리셋 키도 함께 비운다.
  /// 키만 남으면 이룸이 화면이 문구 없는 이모지를 띄운다.
  void setReward(String text, {String presetKey = ''}) {
    final trimmed = text.trim();
    state = state.copyWith(
      rewardText: trimmed,
      rewardPresetKey: trimmed.isEmpty ? '' : presetKey,
    );
  }

  /// 카드를 만든 **뒤에** 보상을 고친다 (검토 화면에서).
  ///
  /// 생성 전 [setReward]와 다르다 — 이미 일과가 서버에 있으므로 API를 탄다.
  /// 저장에 실패해도 로컬에는 반영한다. **보상은 선택 항목이라 실패가 흐름을
  /// 막지 않는다** — 실패 이유를 돌려주고 화면이 스낵바로 알린다.
  ///
  /// null 이면 성공이다.
  Future<AppFailure?> updateRewardOnRoutine(
    String text, {
    String presetKey = '',
  }) async {
    final routine = state.routine;
    if (routine == null) return const AppFailure(fault: NetworkFault.app);

    final trimmed = text.trim();
    final result = await ref
        .read(routineRepositoryProvider)
        .updateReward(
          routine,
          rewardText: trimmed,
          rewardPresetKey: trimmed.isEmpty ? '' : presetKey,
        );
    state = state.copyWith(
      routine: result.routine,
      rewardText: trimmed,
      rewardPresetKey: trimmed.isEmpty ? '' : presetKey,
    );
    return result.failure;
  }

  /// 이름 바꾸기가 서버에 저장된 뒤 흐름의 일과 제목만 바꾼다 (고치던 카드·순서는 그대로)
  void applyRenamedTitle(String title) {
    final routine = state.routine;
    if (routine == null) return;
    state = state.copyWith(routine: routine.copyWith(title: title));
  }

  /// 보상 없이 넘어간다. 정했던 것을 지운다 — 되돌아와 건너뛰면 그 뜻이다.
  void skipReward() => setReward('');

  Future<void> _createRoutine() async {
    // 재시도로 다시 들어올 수 있으므로 이전 에러 코드를 지운다.
    state = state.copyWith(
      step: RoutineFlowStep.generating,
      errorCode: null,
      idempotencyKey: _keyForThisRequest(),
    );

    final repo = ref.read(routineRepositoryProvider);
    final goals = ref.read(onboardingProvider).supportGoals;
    AppAnalytics.logRoutineGenerationStarted();

    try {
      AppLogger.notifierStateChange(
        'RoutineFlowNotifier',
        state.step.name,
        'generating',
      );
      final routine = await repo.createRoutine(
        rawInputText: state.rawInput,
        goals: goals,
        answers: state.answers,
        // 건너뛰었으면 빈 문자열이다. 서버가 보상 없음으로 저장한다.
        rewardText: state.rewardText,
        rewardPresetKey: state.rewardPresetKey,
        idempotencyKey: state.idempotencyKey ?? '',
      );

      AppLogger.notifierStateChange(
        'RoutineFlowNotifier',
        'generating',
        'review',
        {'cardCount': routine.steps.length},
      );
      state = state.copyWith(
        step: RoutineFlowStep.review,
        routine: routine,
        creditUsage: routine.creditUsage,
      );
      AppAnalytics.logRoutineGenerationCompleted(cardCount: routine.steps.length);
      // 잔액이 바뀌었다 — 설정 카드·직전 안내가 이전 숫자를 보이지 않게 한다.
      ref.invalidate(creditSummaryProvider);
      // 이 순간 서버에 임시저장(`PENDING_REVIEW`)으로 남았다. 목록을 다시 받지 않으면
      // 앱을 다시 켜기 전까지 임시저장 화면에 안 보인다 — 전체 목록이
      // keepAlive 라 한 번 받은 것을 계속 준다.
      ref.refreshRoutines();
    } catch (e) {
      // 실패를 삼키지 않고 에러 상태로 드러낸다 (로컬 폴백 없음).
      // 화면은 무한 로딩 대신 에러 코드 + 재시도 버튼을 보여준다(docs 예외처리 규칙).
      AppLogger.error('RoutineFlowNotifier', e);
      _generating = null;

      // **서버가 이유를 알려줬으면 그것을 그대로 쓴다.** 주간 한도·일과 개수 한도는
      // 재시도로 풀리지 않는데, 뭉뚱그리면 사용자는 계속 다시 누른다.
      // 판정은 전역 [AppFailure] 하나가 한다 — 여기서 본문을 다시 파싱하지 않고,
      // 연결 실패·타임아웃도 같은 통로로 들어온다.
      final failure = AppFailure.of(e);
      final errorCode = failure.badgeOr('E-1001');
      state = state.copyWith(
        step: RoutineFlowStep.error,
        errorCode: errorCode,
        errorMessage: failure.serverMessage,
        errorFault: failure.fault,
      );
      AppAnalytics.logRoutineGenerationFailed(errorCode: errorCode);
      // 실패해도 예약이 풀렸거나(반환) 부족이 드러났다 — 다음에 볼 숫자를 새로 받는다.
      ref.invalidate(creditSummaryProvider);
    }
  }

  /// 이번 요청의 멱등 키. 같은 요청이면 전에 발급한 키를, 아니면 새 키를 준다.
  String _keyForThisRequest() {
    final fingerprint = [
      state.rawInput,
      ...state.answers,
      state.rewardText,
      state.rewardPresetKey,
    ].join('\u0000');
    final existing = state.idempotencyKey;
    if (existing != null && _keyIssuedFor == fingerprint) return existing;
    _keyIssuedFor = fingerprint;
    return newIdempotencyKey();
  }

  /// 임시저장에서 이어서 만들기.
  ///
  /// 목록이 이미 [Routine]을 들고 있으므로 다시 받아오지 않는다. 카드확인 화면은
  /// 이 상태만 있으면 그대로 선다.
  ///
  /// **이전 흐름을 지우고 시작한다.** 만들다 만 다른 입력이 남아 있으면 이어서
  /// 만든 일과에 그 값이 섞인다.
  void resumeDraft(Routine routine) {
    AppLogger.notifierStateChange(
      'RoutineFlowNotifier',
      state.step.name,
      'review',
    );
    state = RoutineFlowState(step: RoutineFlowStep.review, routine: routine);
  }

  /// 로딩 화면이 정한 시간 안에 결과가 오지 않았다.
  ///
  /// 요청 자체를 취소하지는 않는다 — 이미 나간 AI 요청은 되돌릴 수 없다.
  /// 다만 사용자를 더 붙잡지 않고 에러 코드와 재시도를 보여준다.
  /// 이미 에러거나 결과가 도착했으면 아무것도 하지 않는다.
  void failOnTimeout() {
    if (state.step == RoutineFlowStep.error) return;
    AppLogger.notifierStateChange(
      'RoutineFlowNotifier',
      state.step.name,
      'error',
    );
    const timeoutErrorCode = 'E-1002';
    state = state.copyWith(step: RoutineFlowStep.error, errorCode: timeoutErrorCode);
    AppAnalytics.logRoutineGenerationFailed(errorCode: timeoutErrorCode);
  }

  /// 이미 만든 일과를 검토 화면에 올린다 (홈에서 `수정`).
  ///
  /// 만들기 흐름을 거치지 않고 중간 화면부터 여는 유일한 입구라, 앞 단계에서
  /// 남은 값(원문·질문·답)을 함께 비운다. 남겨두면 이 일과와 상관없는 이전
  /// 입력이 검토 화면에 섞여 보인다.
  void loadExisting(Routine routine) {
    AppLogger.notifierCall('RoutineFlowNotifier', 'loadExisting', {
      'routineId': routine.id,
    });
    // 앞서 다른 일과에서 뺀 카드가 남아 있으면 엉뚱한 카드를 지우러 간다.
    clearPendingStepChanges();
    state = RoutineFlowState(
      step: RoutineFlowStep.review,
      routine: routine,
      rewardText: routine.rewardText,
      rewardPresetKey: routine.rewardPresetKey,
    );
  }

  void reset() {
    AppLogger.notifierCall('RoutineFlowNotifier', 'reset');
    if (_blockedCalls > 0) {
      AppLogger.notifierCall('RoutineFlowNotifier', 'reset', {
        'blockedCalls': _blockedCalls,
      });
    }
    _generating = null;
    _blockedCalls = 0;
    clearPendingStepChanges();
    _keyIssuedFor = null;
    state = const RoutineFlowState();
  }
}
