import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/config/app_config.dart';
import '../../../core/logger/app_logger.dart';
import '../../../shared/models/routine.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/routine_repository.dart';

/// 일과 생성 플로우의 단계.
enum RoutineFlowStep {
  input,      // 자연어 입력
  masking,    // DLP 처리 중 (연출)
  maskResult, // 전/후 비교
  question,   // AI 추가 질문
  reward,     // 보상 정하기 (건너뛸 수 있다)
  generating, // 카드 생성 중
  review,     // 카드 검토·승인
  done,       // 승인 완료
  error,      // 카드 생성 실패 — 재시도 안내 (로컬 가짜 일과를 만들지 않는다)
}

class RoutineFlowState {
  const RoutineFlowState({
    this.step = RoutineFlowStep.input,
    this.rawInput = '',
    this.maskedInput = '',
    this.detectedTypes = const [],
    this.question,
    this.answers = const [],
    this.customOptions = const {},
    this.rewardText = '',
    this.rewardPresetKey = '',
    this.routine,
    this.errorCode,
    this.errorMessage,
    this.errorHint,
  });

  final RoutineFlowStep step;
  final String rawInput;
  final String maskedInput;

  /// 탐지된 민감정보 **유형**만. 원문은 담지 않는다.
  final List<String> detectedTypes;
  final RoutineQuestion? question;
  final List<String> answers;

  /// 보호자가 직접 적어 넣은 선택지. 질문 문구별로 나눠 담는다.
  ///
  /// [answers]에만 넣으면 칩 목록(`item.options`)에는 없는데 선택은 된 상태가 돼
  /// 화면에 보이지 않는다. 어느 질문에 추가했는지도 알아야 그 질문 아래에 그린다.
  final Map<String, List<String>> customOptions;

  /// 보호자가 카드 생성 **전에** 정한 보상 (이슈 #239).
  ///
  /// 비어 있으면 건너뛴 것이다 — 이룸이 화면에 보상을 띄우지 않는다.
  /// **보상은 선택 항목이므로 비었다고 흐름을 막지 않는다.**
  final String rewardText;

  /// 고른 프리셋 키(`SNACK`·`VIDEO`·`PLAY`·`WALK`). 직접 적었으면 `CUSTOM`.
  final String rewardPresetKey;

  final Routine? routine;

  /// 카드 생성 실패 시 화면에 노출할 식별자 (예: E-1001). null이면 정상.
  /// docs 예외처리 규칙 — 사용자에게는 안내 문구, 화면 어딘가엔 추적용 코드.
  final String? errorCode;

  /// 서버가 보낸 사용자용 문구. 있으면 화면이 이것을 그대로 띄운다.
  ///
  /// 주간 한도에 걸린 것과 AI 가 실패한 것은 **사용자가 할 일이 다르다.**
  /// 둘 다 "잠시 후 다시 해주세요"로 뭉개면 한도에 걸린 사람은 될 때까지
  /// 다시 누른다 (#347).
  final String? errorMessage;

  /// 무엇을 하면 되는지 — 네트워크 사정이라 서버가 말해 줄 수 없을 때만 있다
  /// ([AppFailure.hint]). 오프라인인데 `잠시 후 다시 해주세요` 만 띄우면 끊긴 채로
  /// 다시 하기만 누른다 (#352 규칙 · #387 D4).
  final String? errorHint;

  RoutineFlowState copyWith({
    RoutineFlowStep? step,
    String? rawInput,
    String? maskedInput,
    List<String>? detectedTypes,
    RoutineQuestion? question,
    List<String>? answers,
    Map<String, List<String>>? customOptions,
    String? rewardText,
    String? rewardPresetKey,
    Routine? routine,
    String? errorCode,
    String? errorMessage,
    String? errorHint,
  }) {
    return RoutineFlowState(
      step: step ?? this.step,
      rawInput: rawInput ?? this.rawInput,
      maskedInput: maskedInput ?? this.maskedInput,
      detectedTypes: detectedTypes ?? this.detectedTypes,
      question: question ?? this.question,
      answers: answers ?? this.answers,
      customOptions: customOptions ?? this.customOptions,
      rewardText: rewardText ?? this.rewardText,
      rewardPresetKey: rewardPresetKey ?? this.rewardPresetKey,
      routine: routine ?? this.routine,
      // errorCode는 null로 되돌릴 수 있어야 한다(재시도 시 초기화) → ?? 쓰지 않는다.
      errorCode: errorCode,
      errorMessage: errorMessage,
      errorHint: errorHint,
    );
  }
}

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

    final repo = ref.read(routineRepositoryProvider);
    final question = await repo.generateQuestion(state.rawInput);

    state = state.copyWith(step: RoutineFlowStep.question, question: question);
    AppLogger.notifierStateChange('RoutineFlowNotifier', 'question', 'question', {
      'questionCount': question.askable.length,
    });
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
  /// 다시 돌아 [generateCards]를 또 부른다. 실제로 한 번의 일과 생성에
  /// 요청이 16번 나간 적이 있다.
  ///
  /// 위젯이 아니라 여기서 막는 이유 — 위젯은 몇 번이든 다시 만들어지지만
  /// provider는 흐름이 끝날 때까지 살아 있다.
  Future<void>? _generating;

  /// 차단한 중복 호출 수. **0이 아니면 어딘가에서 또 부르고 있다는 신호다.**
  /// 로그로 남겨야 재발을 눈치챌 수 있다 — 조용히 막기만 하면 원인이 묻힌다.
  var _blockedCalls = 0;

  /// 화면에서 뺐지만 서버에는 아직 남아 있는 카드 (이슈 #405).
  ///
  /// [save]가 이것을 서버에 반영한다. **화면이 아니라 여기에 둔다** — 카드확인
  /// 화면은 저장 도중에도 다시 만들어질 수 있고, 목록에서 이미 사라진 카드는
  /// 화면에서 되찾을 방법이 없다.
  ///
  /// 지우는 데 성공한 것은 그때그때 뺀다. 하나가 실패해 다시 눌렀을 때 이미
  /// 없는 카드를 또 지우러 가면 안 된다.
  final _removedStepIds = <String>{};

  Future<void> generateCards() {
    // 진행 중이거나 이미 끝난 생성이 있으면 그것을 그대로 돌려준다.
    //
    // **성공한 뒤에도 가드를 풀지 않는다.** 풀면 로딩 화면이 나중에 다시
    // 만들어졌을 때 또 쏜다 — 16번 사고가 정확히 이 경로였다.
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

  /// 보상을 정한다 (이슈 #239).
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

  /// 카드를 만든 **뒤에** 보상을 고친다 (검토 화면에서 · 이슈 #239).
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
    state = state.copyWith(step: RoutineFlowStep.generating, errorCode: null);

    final repo = ref.read(routineRepositoryProvider);
    final goals = ref.read(onboardingProvider).supportGoals;

    try {
      AppLogger.notifierStateChange('RoutineFlowNotifier', state.step.name, 'generating');
      final routine = await repo.createRoutine(
        rawInputText: state.rawInput,
        goals: goals,
        answers: state.answers,
        // 건너뛰었으면 빈 문자열이다. 서버가 보상 없음으로 저장한다 (이슈 #239).
        rewardText: state.rewardText,
        rewardPresetKey: state.rewardPresetKey,
      );

      AppLogger.notifierStateChange('RoutineFlowNotifier', 'generating', 'review', {
        'cardCount': routine.steps.length,
      });
      state = state.copyWith(step: RoutineFlowStep.review, routine: routine);
      // 이 순간 서버에 임시저장(`PENDING_REVIEW`)으로 남았다. 목록을 다시 받지 않으면
      // 앱을 다시 켜기 전까지 임시저장 화면에 안 보인다 (#387) — 전체 목록이
      // keepAlive 라 한 번 받은 것을 계속 준다.
      ref.refreshRoutines();
    } catch (e) {
      // 로컬 폴백을 제거했으므로 실패를 삼키지 않고 에러 상태로 드러낸다.
      // 화면은 무한 로딩 대신 에러 코드 + 재시도 버튼을 보여준다(docs 예외처리 규칙).
      AppLogger.error('RoutineFlowNotifier', e);
      _generating = null;

      // **서버가 이유를 알려줬으면 그것을 그대로 쓴다.** 주간 한도·일과 개수 한도는
      // 재시도로 풀리지 않는데, 뭉뚱그리면 사용자는 계속 다시 누른다 (#347).
      // 판정은 전역 [AppFailure] 하나가 한다 — 여기서 본문을 다시 파싱하지 않고,
      // 연결 실패·타임아웃도 같은 통로로 들어온다 (#352).
      final failure = AppFailure.of(e);
      state = state.copyWith(
        step: RoutineFlowStep.error,
        errorCode: failure.badgeOr('E-1001'),
        errorMessage: failure.serverMessage,
        errorHint: failure.hint,
      );
    }
  }

  /// 임시저장에서 이어서 만들기 (#349).
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

  /// 로딩 화면이 정한 시간 안에 결과가 오지 않았다 (#276).
  ///
  /// 요청 자체를 취소하지는 않는다 — 이미 나간 AI 요청은 되돌릴 수 없다.
  /// 다만 사용자를 더 붙잡지 않고 에러 코드와 재시도를 보여준다.
  /// 이미 에러거나 결과가 도착했으면 아무것도 하지 않는다.
  void failOnTimeout() {
    if (state.step == RoutineFlowStep.error) return;
    AppLogger.notifierStateChange('RoutineFlowNotifier', state.step.name, 'error');
    state = state.copyWith(step: RoutineFlowStep.error, errorCode: 'E-1002');
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

    // 저장하기가 이 목록을 보고 서버에서 뺀다 (#405). 화면에서만 지우고 끝내면
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
  /// 그 안에 서버가 알려준 이유가 들어 있고, 화면이 그대로 안내한다 (#352).
  ///
  /// **title은 서버에 보내지 않는다.** `RoutineStep`에 title 컬럼이 없다
  /// (2026-07-22 서버 확인, 이슈 #77). 서버 응답에도 title이 없으므로
  /// 그대로 받으면 다른 카드의 로컬 제목까지 지워진다 — 기존 제목을 되살려 합친다.
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
    final result = await repo.updateStep(routine, stepId, description);

    // 서버 응답에는 step title이 없다 — 로컬 제목을 복원하고 수정분만 덮는다
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

  /// 카드확인의 `저장하기` (이슈 #405).
  ///
  /// 하는 일이 **일과의 상태에 따라 다르다.**
  ///
  /// | 어디서 왔나 | 상태 | 하는 일 |
  /// |---|---|---|
  /// | 만들기 흐름 | `PENDING_REVIEW` | 뺀 카드를 지우고 **승인**한다 |
  /// | 홈에서 편집 | 그 밖(`CONFIRMED`·`COMPLETED`) | 뺀 카드만 지운다 |
  ///
  /// 전에는 어느 쪽이든 승인 API 를 불렀다. 서버는 임시저장만 승인할 수 있어서
  /// 이미 저장한 일과를 편집하면 `ROUTINE_INVALID_STATUS` 로 거절했다.
  ///
  /// **지우기가 먼저다.** 승인하는 순간 이룸이 화면에 카드가 나가므로(docs 원칙
  /// 3번), 순서가 바뀌면 뺀 카드가 잠깐이라도 이룸이에게 보인다.
  ///
  /// null 이면 성공. 실패하면 이유가 담겨 오고 **화면은 그대로 둔다** — 홈으로
  /// 보내면 저장된 것처럼 보이는데 이룸이 휴대폰에는 옛 카드가 그대로다.
  Future<AppFailure?> save() async {
    AppLogger.notifierCall('RoutineFlowNotifier', 'save', {
      'removed': _removedStepIds.length,
    });

    final routine = state.routine;
    if (routine == null) return null;

    final repo = ref.read(routineRepositoryProvider);

    // 뺀 카드를 서버에서 지운다. 하나라도 실패하면 승인하지 않는다 —
    // 뺀 카드가 남은 채로 이룸이에게 가면 보호자가 지운 것이 되살아난 셈이다.
    for (final stepId in _removedStepIds.toList()) {
      final failure = await repo.deleteStep(routine.id, stepId);

      // 이미 없는 카드는 빠진 것으로 본다 — 다른 휴대폰에서 먼저 지웠을 때다.
      // 결과가 같으므로 실패로 다루면 보호자가 영영 저장할 수 없다.
      final gone = failure?.server?.code == ServerErrorCode.routineStepNotFound;
      if (failure == null || gone) {
        _removedStepIds.remove(stepId);
        continue;
      }
      return failure;
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

  /// 이미 만든 일과를 검토 화면에 올린다 (이슈 #258 — 홈에서 `수정`).
  ///
  /// 만들기 흐름을 거치지 않고 중간 화면부터 여는 유일한 입구라, 앞 단계에서
  /// 남은 값(원문·질문·답)을 함께 비운다. 남겨두면 이 일과와 상관없는 이전
  /// 입력이 검토 화면에 섞여 보인다.
  void loadExisting(Routine routine) {
    AppLogger.notifierCall('RoutineFlowNotifier', 'loadExisting', {
      'routineId': routine.id,
    });
    // 앞서 다른 일과에서 뺀 카드가 남아 있으면 엉뚱한 카드를 지우러 간다 (#405).
    _removedStepIds.clear();
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
    state = const RoutineFlowState();
  }
}
