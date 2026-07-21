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

  /// AI 추가 질문을 받아온다. 질문이 없으면 카드 생성으로 바로 넘어간다.
  Future<void> askQuestion() async {
    final repo = ref.read(routineRepositoryProvider);
    final question = await repo.generateQuestion(state.rawInput);

    if (!question.canAsk) {
      await generateCards();
      return;
    }
    state = state.copyWith(step: RoutineFlowStep.question, question: question);
  }

  void toggleAnswer(String answer) {
    final next = List<String>.from(state.answers);
    next.contains(answer) ? next.remove(answer) : next.add(answer);
    state = state.copyWith(answers: next);
  }

  Future<void> generateCards() async {
    state = state.copyWith(step: RoutineFlowStep.generating);

    final repo = ref.read(routineRepositoryProvider);
    final goals = ref.read(onboardingProvider).supportGoals;

    final routine = await repo.createRoutine(
      rawInputText: state.rawInput,
      goals: goals,
      answers: state.answers,
    );

    state = state.copyWith(step: RoutineFlowStep.review, routine: routine);
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

  void reset() => state = const RoutineFlowState();
}
