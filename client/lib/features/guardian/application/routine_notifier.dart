import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/models/routine.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/routine_repository.dart';

/// 일과 생성 플로우의 단계.
enum RoutineFlowStep {
  input,      // 자연어 입력
  masking,    // DLP 처리 중 (연출)
  maskResult, // 전/후 비교
  question,   // AI 추가 질문
  generating, // 카드 생성 중
  review,     // 카드 검토·승인
  done,       // 승인 완료
}

class RoutineFlowState {
  const RoutineFlowState({
    this.step = RoutineFlowStep.input,
    this.rawInput = '',
    this.maskedInput = '',
    this.detectedTypes = const [],
    this.question,
    this.answers = const [],
    this.routine,
  });

  final RoutineFlowStep step;
  final String rawInput;
  final String maskedInput;

  /// 탐지된 민감정보 **유형**만. 원문은 담지 않는다.
  final List<String> detectedTypes;
  final RoutineQuestion? question;
  final List<String> answers;
  final Routine? routine;

  RoutineFlowState copyWith({
    RoutineFlowStep? step,
    String? rawInput,
    String? maskedInput,
    List<String>? detectedTypes,
    RoutineQuestion? question,
    List<String>? answers,
    Routine? routine,
  }) {
    return RoutineFlowState(
      step: step ?? this.step,
      rawInput: rawInput ?? this.rawInput,
      maskedInput: maskedInput ?? this.maskedInput,
      detectedTypes: detectedTypes ?? this.detectedTypes,
      question: question ?? this.question,
      answers: answers ?? this.answers,
      routine: routine ?? this.routine,
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

  void setRawInput(String value) => state = state.copyWith(rawInput: value);

  /// DLP 처리. 응답이 빨라도 최소 노출 시간을 지킨다 —
  /// 보안 처리를 체감시키기 위한 연출이다 (docs/07-mvp-scope.md 데모 안전 수칙).
  Future<void> runDlp() async {
    state = state.copyWith(step: RoutineFlowStep.masking);

    final started = DateTime.now();
    final masked = LocalDlp.mask(state.rawInput);
    final types = LocalDlp.detectedTypes(state.rawInput);

    final elapsed = DateTime.now().difference(started);
    final remaining = AppConfig.dlpMinDelay - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

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
    final repo = ref.read(routineRepositoryProvider);
    final question = await repo.generateQuestion(state.rawInput);

    state = state.copyWith(step: RoutineFlowStep.question, question: question);
  }

  void toggleAnswer(String answer) {
    final next = List<String>.from(state.answers);
    next.contains(answer) ? next.remove(answer) : next.add(answer);
    state = state.copyWith(answers: next);
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

  Future<void> generateCards() {
    // 진행 중이거나 이미 끝난 생성이 있으면 그것을 그대로 돌려준다.
    //
    // **성공한 뒤에도 가드를 풀지 않는다.** 풀면 로딩 화면이 나중에 다시
    // 만들어졌을 때 또 쏜다 — 16번 사고가 정확히 이 경로였다.
    // 새 일과를 만들 때는 홈에서 [reset]을 부르므로 그때 풀린다.
    return _generating ??= _createRoutine();
  }

  Future<void> _createRoutine() async {
    state = state.copyWith(step: RoutineFlowStep.generating);

    final repo = ref.read(routineRepositoryProvider);
    final goals = ref.read(onboardingProvider).supportGoals;

    try {
      final routine = await repo.createRoutine(
        rawInputText: state.rawInput,
        goals: goals,
        answers: state.answers,
      );

      state = state.copyWith(step: RoutineFlowStep.review, routine: routine);
    } catch (e) {
      // 실패했을 때만 가드를 푼다. 성공과 달리 남길 결과가 없으므로
      // 붙잡아 두면 사용자가 영영 카드를 못 만든다.
      _generating = null;
      rethrow;
    }
  }

  Future<void> updateStep(String stepId, String description) async {
    final routine = state.routine;
    if (routine == null) return;

    final repo = ref.read(routineRepositoryProvider);
    final updated = await repo.updateStep(routine, stepId, description);
    state = state.copyWith(routine: updated);
  }

  /// 승인. 이 시점 이후에만 아동 화면에 노출된다 (docs 원칙 3번).
  Future<void> confirm() async {
    final routine = state.routine;
    if (routine == null) return;

    final repo = ref.read(routineRepositoryProvider);
    final confirmed = await repo.confirm(routine);
    state = state.copyWith(step: RoutineFlowStep.done, routine: confirmed);
  }

  void reset() {
    // 진행 중이던 생성을 놓아준다. 남겨두면 다음 일과 생성이 막힌다.
    _generating = null;
    state = const RoutineFlowState();
  }
}
