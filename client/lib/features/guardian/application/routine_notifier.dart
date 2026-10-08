import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/network/server_error_code.dart';
import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';
import '../../credit/data/credit_repository.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/routine_repository.dart';
import '../domain/local_dlp.dart';
import 'routine_flow_state.dart';
import 'routine_providers.dart';

final routineFlowProvider =
    NotifierProvider<RoutineFlowNotifier, RoutineFlowState>(
  RoutineFlowNotifier.new,
);

/// 일과 입력 → DLP → 질문 → 카드 생성 → 승인 흐름을 관리한다.
///
/// 어떤 단계도 예외를 던지지 않는다. repository가 실패를 흡수하므로
/// 화면은 항상 다음 단계로 진행할 수 있다.
class RoutineFlowNotifier extends Notifier<RoutineFlowState> {
  @override
  RoutineFlowState build() => const RoutineFlowState();

  void setRawInput(String value) {
    AppLogger.notifierCall('RoutineFlowNotifier', 'setRawInput', {'input': value});
    state = state.copyWith(rawInput: value);
  }

  /// DLP 처리. 응답이 빨라도 최소 노출 시간을 지킨다 —
  /// 보안 처리를 체감시키기 위한 연출이다 (docs/07-mvp-scope.md 데모 안전 수칙).
  Future<void> runDlp() async {
    AppLogger.notifierCall('RoutineFlowNotifier', 'runDlp');
    AppLogger.notifierStateChange('RoutineFlowNotifier', state.step.name, 'masking');
    state = state.copyWith(step: RoutineFlowStep.masking);

    final started = DateTime.now();
    final masked = LocalDlp.mask(state.rawInput);
    final types = LocalDlp.detectedTypes(state.rawInput);

    final elapsed = DateTime.now().difference(started);
    final remaining = AppConfig.dlpMinDelay - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    AppLogger.notifierStateChange('RoutineFlowNotifier', 'masking', 'maskResult', {
      'detectedTypes': types.join(', '),
    });
    state = state.copyWith(
      step: RoutineFlowStep.maskResult,
      maskedInput: masked,
      detectedTypes: types,
    );
  }

  /// AI 추가 질문을 받아온다.
  ///
  /// **여기서 카드를 생성하지 않는다.** 질문이 없으면 질문 화면이 스스로
  /// 로딩 화면으로 건너뛰고, 카드 생성은 로딩 화면 한 곳에서만 시작한다.
  /// 양쪽에서 생성하면 같은 일과가 두 번 만들어진다.
  Future<void> askQuestion() async {
    AppLogger.notifierCall('RoutineFlowNotifier', 'askQuestion');
    AppLogger.notifierStateChange('RoutineFlowNotifier', state.step.name, 'question');

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
      AppLogger.notifierStateChange('RoutineFlowNotifier', 'question', 'error', {
        'fault': failure.fault.name,
      });
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
      maskedInput: state.maskedInput,
      detectedTypes: state.detectedTypes,
      question: question,
      questionInput: state.rawInput,
      rewardText: state.rewardText,
      rewardPresetKey: state.rewardPresetKey,
      routine: state.routine,
    );
    AppLogger.notifierStateChange('RoutineFlowNotifier', 'question', 'question', {
      'questionCount': question.askable.length,
    });
  }

  /// 질문 받기가 실패한 뒤 다시 한다. 카드를 만들지 않는다 —
  /// 준비 로딩의 `다시 하기`가 카드 생성 재시도로 이어지면 질문을 건너뛴다.
  Future<void> retryQuestion() {
    state = state.copyWith(step: RoutineFlowStep.maskResult);
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

    final existing = state.question?.askable
            .firstWhere(
              (item) => item.question == question,
              orElse: () => const QuestionItem(question: '', options: []),
            )
            .options ??
        const <QuestionOption>[];
    final custom = state.customOptions[question] ?? const <String>[];
    final isDuplicate =
        existing.any((option) => option.label == value) || custom.contains(value);

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

  /// 화면에서 뺐지만 서버에는 아직 남아 있는 카드.
  ///
  /// [save]가 이것을 서버에 반영한다. **화면이 아니라 여기에 둔다** — 카드확인
  /// 화면은 저장 도중에도 다시 만들어질 수 있고, 목록에서 이미 사라진 카드는
  /// 화면에서 되찾을 방법이 없다.
  ///
  /// 지우는 데 성공한 것은 그때그때 뺀다. 하나가 실패해 다시 눌렀을 때 이미
  /// 없는 카드를 또 지우러 가면 안 된다.
  final _removedStepIds = <String>{};

  /// 일과 하나의 최대 카드 수 — 서버 `RoutineService.STEP_MAX_COUNT` 와 같은 값이다.
  ///
  /// 서버는 **자기가 가진 카드**를 센다. 보호자가 화면에서 뺀 카드는 저장하기 전까지 서버에
  /// 남아 있어서, 화면은 9장인데 서버는 10장이라 추가가 거절될 수 있다.
  static const _maxSteps = 10;

  /// 화면에서 카드 순서를 바꿨지만 서버에는 아직 안 보낸 상태.
  ///
  /// 뺀 카드([_removedStepIds])와 같은 이유로 **저장하기가 보낸다.** 서버 순서 API 는
  /// 카드 전체를 요구하는데(개수가 다르면 400) 뺀 카드는 그때까지 서버에 남아 있어서,
  /// 옮길 때마다 보내면 늘 실패한다. 저장하기는 삭제를 먼저 해 개수를 맞춘 뒤 보낸다.
  ///
  /// 순서를 바꿨다 되돌려도 true 로 남을 수 있다 — 한 번 더 보내는 것뿐이라 해가 없다.
  var _orderDirty = false;

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
      debugPrint(
        '[cost] 카드 생성 중복 호출 차단 (누적 $_blockedCalls회) — '
        '이미 ${state.routine != null ? "생성 완료" : "생성 중"}. 서버 요청 안 보냄',
      );
      return running;
    }

    debugPrint('[cost] 카드 생성 시작 → POST /api/routines (AI 호출, 과금 대상)');
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
  Future<AppFailure?> updateRewardOnRoutine(String text, {String presetKey = ''}) async {
    final routine = state.routine;
    if (routine == null) return const AppFailure(fault: NetworkFault.app);

    final trimmed = text.trim();
    final result = await ref.read(routineRepositoryProvider).updateReward(
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

    try {
      AppLogger.notifierStateChange('RoutineFlowNotifier', state.step.name, 'generating');
      final routine = await repo.createRoutine(
        rawInputText: state.rawInput,
        goals: goals,
        answers: state.answers,
        // 건너뛰었으면 빈 문자열이다. 서버가 보상 없음으로 저장한다.
        rewardText: state.rewardText,
        rewardPresetKey: state.rewardPresetKey,
        idempotencyKey: state.idempotencyKey ?? '',
      );

      AppLogger.notifierStateChange('RoutineFlowNotifier', 'generating', 'review', {
        'cardCount': routine.steps.length,
      });
      state = state.copyWith(
        step: RoutineFlowStep.review,
        routine: routine,
        creditUsage: routine.creditUsage,
      );
      // 잔액이 바뀌었다 — 설정 카드·직전 안내가 이전 숫자를 보이지 않게 한다.
      ref.invalidate(creditSummaryProvider);
      // 이 순간 서버에 임시저장(`PENDING_REVIEW`)으로 남았다. 목록을 다시 받지 않으면
      // 앱을 다시 켜기 전까지 임시저장 화면에 안 보인다 — 전체 목록이
      // keepAlive 라 한 번 받은 것을 계속 준다.
      ref.refreshRoutines();
    } catch (e) {
      // 로컬 폴백을 제거했으므로 실패를 삼키지 않고 에러 상태로 드러낸다.
      // 화면은 무한 로딩 대신 에러 코드 + 재시도 버튼을 보여준다(docs 예외처리 규칙).
      AppLogger.error('RoutineFlowNotifier', e);
      _generating = null;

      // **서버가 이유를 알려줬으면 그것을 그대로 쓴다.** 주간 한도·일과 개수 한도는
      // 재시도로 풀리지 않는데, 뭉뚱그리면 사용자는 계속 다시 누른다.
      // 판정은 전역 [AppFailure] 하나가 한다 — 여기서 본문을 다시 파싱하지 않고,
      // 연결 실패·타임아웃도 같은 통로로 들어온다.
      final failure = AppFailure.of(e);
      state = state.copyWith(
        step: RoutineFlowStep.error,
        errorCode: failure.badgeOr('E-1001'),
        errorMessage: failure.serverMessage,
        errorFault: failure.fault,
      );
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
    AppLogger.notifierStateChange('RoutineFlowNotifier', state.step.name, 'review');
    state = RoutineFlowState(step: RoutineFlowStep.review, routine: routine);
  }

  /// 로딩 화면이 정한 시간 안에 결과가 오지 않았다.
  ///
  /// 요청 자체를 취소하지는 않는다 — 이미 나간 AI 요청은 되돌릴 수 없다.
  /// 다만 사용자를 더 붙잡지 않고 에러 코드와 재시도를 보여준다.
  /// 이미 에러거나 결과가 도착했으면 아무것도 하지 않는다.
  void failOnTimeout() {
    if (state.step == RoutineFlowStep.error) return;
    AppLogger.notifierStateChange('RoutineFlowNotifier', state.step.name, 'error');
    state = state.copyWith(step: RoutineFlowStep.error, errorCode: 'E-1002');
  }

  /// 카드확인에서 카드를 직접 추가한다 (시안 1197:6044).
  ///
  /// 서버에 **바로** 넣는다 — 새 카드의 id 는 서버가 준다. 성공하면 새 카드를 화면
  /// 목록 **맨 뒤**에 붙인다. 서버가 돌려준 전체 목록을 그대로 쓰지 않는다: 그 안에는
  /// 보호자가 이미 뺀(저장 전이라 서버에 남은) 카드가 있어 되살아난다.
  ///
  /// null 이면 성공. 실패하면 이유가 담겨 오고 목록은 그대로다.
  Future<AppFailure?> addStep({
    required String title,
    required String description,
  }) async {
    // 제목·설명은 보호자가 쓴 글이라 로그에 남기지 않는다 (docs 원칙 5번)
    AppLogger.notifierCall('RoutineFlowNotifier', 'addStep');

    final routine = state.routine;
    if (routine == null) return const AppFailure(fault: NetworkFault.app);

    final repo = ref.read(routineRepositoryProvider);

    // 서버 카드가 상한이면(화면에서 뺀 카드까지 세어) 뺀 카드를 먼저 지운다. 안 그러면 화면은
    // 9장인데 "카드는 10장까지 만들 수 있습니다" 로 거절돼 보호자가 이유를 알 수 없다.
    // **꽉 찼을 때만** 미리 지운다 — 그 밖에는 나가기 팝업의 "뺀 카드는 저장하기를 눌러야
    // 빠져요" 를 그대로 지킨다. 하나라도 실패하면 추가하지 않는다.
    if (_removedStepIds.isNotEmpty &&
        routine.steps.length + _removedStepIds.length >= _maxSteps) {
      final failure = await _deleteRemovedSteps(repo, routine.id);
      if (failure != null) return failure;
    }

    final result = await repo.addStep(
      routine,
      title: title,
      description: description,
    );
    if (result.failure != null) return result.failure;

    // 응답에서 새로 생긴 카드만 뽑는다. 하나도 없으면 서버가 무엇을 했는지 알 수 없다 —
    // 없는 카드를 만들어 내지 않고 실패로 본다.
    final known = {for (final s in routine.steps) s.id, ..._removedStepIds};
    final added = [
      for (final s in result.routine.steps)
        if (!known.contains(s.id)) s,
    ];
    if (added.isEmpty) return const AppFailure(fault: NetworkFault.app);

    // 서버 응답에는 카드 제목이 없다(RoutineStep 에 title 컬럼이 없다) —
    // 보호자가 쓴 제목을 되살린다.
    final withTitle = [
      for (final s in added) s.title.isEmpty ? s.copyWith(title: title) : s,
    ];
    state = state.copyWith(
      routine: routine.copyWith(steps: [...routine.steps, ...withTitle]),
    );
    return null;
  }

  /// 카드 그림을 사진으로 바꾼 뒤 새 `imagePath` 를 반영한다.
  ///
  /// 서버 응답 전체를 쓰지 않고 **`imagePath` 만** 바꾼다 — 응답에는 카드 제목이 없어
  /// 통째로 덮으면 로컬 제목이 지워진다([updateStep] 과 같은 사정). 그 사이 지워진 카드면
  /// 아무것도 하지 않는다. 목록 캐시도 버려, 홈·이룸이 쪽이 새 열쇠를 받게 한다.
  void applyStepImage(String stepId, String imagePath) {
    final routine = state.routine;
    if (routine == null || !routine.steps.any((s) => s.id == stepId)) return;

    state = state.copyWith(
      routine: routine.copyWith(
        steps: [
          for (final s in routine.steps)
            if (s.id == stepId) s.copyWith(imagePath: imagePath) else s,
        ],
      ),
    );
    ref.refreshRoutines();
  }

  /// 순서 변경 모드에 들어가는 순간의 순서. `✕` 로 나올 때 되돌린다.
  ({List<ActionCard> steps, bool dirty}) snapshotOrder() => (
    steps: List.of(state.routine?.steps ?? const <ActionCard>[]),
    dirty: _orderDirty,
  );

  /// [snapshotOrder] 로 되돌린다.
  void restoreOrder(({List<ActionCard> steps, bool dirty}) snapshot) {
    final routine = state.routine;
    if (routine == null) return;
    _orderDirty = snapshot.dirty;
    state = state.copyWith(routine: routine.copyWith(steps: snapshot.steps));
  }

  /// 카드 한 장을 옮긴다 (시안 1197:5798 길게 눌러 순서 변경).
  ///
  /// [newIndex] 는 `ReorderableListView.onReorder` 가 주는 값 그대로다 — 아래로
  /// 옮길 때 **제거 전** 위치를 주므로 여기서 하나 뺀다. 범위를 벗어나면 무시한다.
  /// 서버는 부르지 않는다. [save] 가 보낸다.
  void moveStep(int oldIndex, int newIndex) {
    final routine = state.routine;
    if (routine == null) return;
    final steps = List.of(routine.steps);
    if (oldIndex < 0 || oldIndex >= steps.length) return;
    if (newIndex < 0 || newIndex > steps.length) return;

    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target == oldIndex) return;

    steps.insert(target, steps.removeAt(oldIndex));
    _orderDirty = true;
    state = state.copyWith(
      routine: routine.copyWith(
        steps: [
          // 번호는 자리다 — 카드와 함께 옮기지 않고 자리대로 다시 매긴다
          for (var i = 0; i < steps.length; i++)
            steps[i].copyWith(stepOrder: i + 1),
        ],
      ),
    );
  }

  /// 카드확인에서 카드를 뺀다 (Figma 364:8305 X 버튼).
  ///
  /// 로컬에서만 지우고 서버 반영은 저장(승인) 시점의 목록으로 정리된다.
  /// **마지막 한 장은 지울 수 없다** — 카드 0장인 일과는 의미가 없다.
  void removeStep(String stepId) {
    AppLogger.notifierCall('RoutineFlowNotifier', 'removeStep', {
      'stepId': stepId,
    });

    final routine = state.routine;
    if (routine == null || routine.steps.length <= 1) return;
    if (!routine.steps.any((s) => s.id == stepId)) return;

    // 저장하기가 이 목록을 보고 서버에서 뺀다. 화면에서만 지우고 끝내면
    // 나가기 팝업의 "저장하기를 눌러야 빠져요" 가 지켜지지 않는다.
    _removedStepIds.add(stepId);

    state = state.copyWith(
      routine: routine.copyWith(
        steps: routine.steps.where((s) => s.id != stepId).toList(),
      ),
    );
  }

  /// 카드 제목·설명 수정 (Figma 262:5124 `이 카드 수정하기`).
  ///
  /// 돌려주는 값이 null 이 아니면 서버 반영에 실패해 로컬에만 저장됐다 —
  /// 그 안에 서버가 알려준 이유가 들어 있고, 화면이 그대로 안내한다.
  ///
  /// 제목·설명을 함께 서버에 보낸다. 응답 제목이 비어 오는 카드는
  /// 로컬 제목을 되살려 합친다.
  Future<AppFailure?> updateStep({
    required String stepId,
    required String title,
    required String description,
  }) async {
    AppLogger.notifierCall('RoutineFlowNotifier', 'updateStep', {
      'stepId': stepId,
      'title': title,
      'description': description,
    });

    final routine = state.routine;
    if (routine == null) return null;

    final repo = ref.read(routineRepositoryProvider);
    final result = await repo.updateStep(
      routine,
      stepId,
      title: title,
      description: description,
    );

    // 응답 제목이 비면 로컬 제목을 복원하고 수정한 카드는 입력값으로 덮는다
    final localTitles = {
      for (final step in routine.steps) step.id: step.title,
    };
    final merged = result.routine.copyWith(
      steps: [
        for (final step in result.routine.steps)
          step.copyWith(
            title: step.id == stepId
                ? title
                : (step.title.isNotEmpty
                    ? step.title
                    : localTitles[step.id] ?? ''),
          ),
      ],
    );

    state = state.copyWith(routine: merged);
    return result.failure;
  }

  /// 화면에서 뺀 카드를 서버에서 지운다. [save] 와 [addStep] 이 함께 쓴다.
  ///
  /// null 이면 전부 지웠다. 하나라도 실패하면 이유를 돌려주고 **멈춘다** — 성공한 것은
  /// 기억에서 지워 다시 부를 때 남은 것만 보낸다.
  Future<AppFailure?> _deleteRemovedSteps(
    RoutineRepository repo,
    String routineId,
  ) async {
    for (final stepId in _removedStepIds.toList()) {
      final failure = await repo.deleteStep(routineId, stepId);

      // 이미 없는 카드는 빠진 것으로 본다 — 다른 휴대폰에서 먼저 지웠을 때다.
      // 결과가 같으므로 실패로 다루면 보호자가 영영 저장할 수 없다.
      final gone = failure?.server?.code == ServerErrorCode.routineStepNotFound;
      if (failure == null || gone) {
        _removedStepIds.remove(stepId);
        continue;
      }
      return failure;
    }
    return null;
  }

  /// 카드확인의 `저장하기`.
  ///
  /// 하는 일이 **일과의 상태에 따라 다르다.**
  ///
  /// | 어디서 왔나 | 상태 | 하는 일 |
  /// |---|---|---|
  /// | 만들기 흐름 | `PENDING_REVIEW` | 뺀 카드를 지우고 **승인**한다 |
  /// | 홈에서 편집 | 그 밖(`CONFIRMED`·`COMPLETED`) | 뺀 카드만 지운다 |
  ///
  /// 서버는 임시저장만 승인할 수 있어, 이미 저장한 일과에 승인 API 를 부르면
  /// `ROUTINE_INVALID_STATUS` 로 거절한다.
  ///
  /// **지우기가 먼저다.** 승인하는 순간 이룸이 화면에 카드가 나가므로(docs 원칙
  /// 3번), 순서가 바뀌면 뺀 카드가 잠깐이라도 이룸이에게 보인다.
  ///
  /// null 이면 성공. 실패하면 이유가 담겨 오고 **화면은 그대로 둔다** — 홈으로
  /// 보내면 저장된 것처럼 보이는데 이룸이 휴대폰에는 이전 카드가 그대로다.
  Future<AppFailure?> save() async {
    AppLogger.notifierCall('RoutineFlowNotifier', 'save', {
      'removed': _removedStepIds.length,
    });

    final routine = state.routine;
    if (routine == null) return null;

    final repo = ref.read(routineRepositoryProvider);

    // 뺀 카드를 서버에서 지운다. 하나라도 실패하면 승인하지 않는다 —
    // 뺀 카드가 남은 채로 이룸이에게 가면 보호자가 지운 것이 되살아난 셈이다.
    final deleteFailure = await _deleteRemovedSteps(repo, routine.id);
    if (deleteFailure != null) return deleteFailure;

    // 바꾼 순서를 보낸다. **삭제 다음이다** — 서버는 카드 전체를 요구해서 뺀 카드가
    // 남아 있으면 개수가 달라 거절한다. **승인 앞이다** — 승인하는 순간 이룸이 화면에
    // 카드가 나가므로 순서가 맞은 채로 나가야 한다.
    if (_orderDirty) {
      final failure = await repo.reorderSteps(routine.id, [
        for (final s in state.routine?.steps ?? routine.steps) s.id,
      ]);
      if (failure != null) return failure;
      _orderDirty = false;
    }

    // 이미 저장한 일과는 여기서 끝이다. 승인 API 는 임시저장만 받는다.
    if (routine.status != 'PENDING_REVIEW') {
      ref.refreshRoutines();
      return null;
    }

    AppLogger.notifierStateChange('RoutineFlowNotifier', state.step.name, 'done');
    try {
      final confirmed = await repo.confirm(routine);
      state = state.copyWith(step: RoutineFlowStep.done, routine: confirmed);
    } catch (e) {
      AppLogger.error('RoutineFlowNotifier', e);
      return AppFailure.of(e);
    }
    ref.refreshRoutines();
    return null;
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
    _removedStepIds.clear();
    _orderDirty = false;
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
    _removedStepIds.clear();
    _orderDirty = false;
    _keyIssuedFor = null;
    state = const RoutineFlowState();
  }
}
