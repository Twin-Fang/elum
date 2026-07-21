import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.routine,
    this.errorCode,
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

  final Routine? routine;

  /// 카드 생성 실패 시 화면에 노출할 식별자 (예: E-1001). null이면 정상.
  /// docs 예외처리 규칙 — 사용자에게는 안내 문구, 화면 어딘가엔 추적용 코드.
  final String? errorCode;

  RoutineFlowState copyWith({
    RoutineFlowStep? step,
    String? rawInput,
    String? maskedInput,
    List<String>? detectedTypes,
    RoutineQuestion? question,
    List<String>? answers,
    Map<String, List<String>>? customOptions,
    Routine? routine,
    String? errorCode,
  }) {
    return RoutineFlowState(
      step: step ?? this.step,
      rawInput: rawInput ?? this.rawInput,
      maskedInput: maskedInput ?? this.maskedInput,
      detectedTypes: detectedTypes ?? this.detectedTypes,
      question: question ?? this.question,
      answers: answers ?? this.answers,
      customOptions: customOptions ?? this.customOptions,
      routine: routine ?? this.routine,
      // errorCode는 null로 되돌릴 수 있어야 한다(재시도 시 초기화) → ?? 쓰지 않는다.
      errorCode: errorCode,
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
      );

      AppLogger.notifierStateChange('RoutineFlowNotifier', 'generating', 'review', {
        'cardCount': routine.steps.length,
      });
      state = state.copyWith(step: RoutineFlowStep.review, routine: routine);
    } catch (e) {
      // 로컬 폴백을 제거했으므로 실패를 삼키지 않고 에러 상태로 드러낸다.
      // 화면은 무한 로딩 대신 에러 코드 + 재시도 버튼을 보여준다(docs 예외처리 규칙).
      AppLogger.error('RoutineFlowNotifier', e);
      _generating = null;
      state = state.copyWith(step: RoutineFlowStep.error, errorCode: 'E-1001');
    }
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

    state = state.copyWith(
      routine: routine.copyWith(
        steps: routine.steps.where((s) => s.id != stepId).toList(),
      ),
    );
  }

  /// 카드 제목·설명 수정 (Figma 262:5124 `이 카드 수정하기`).
  ///
  /// 반환값이 false면 서버 반영에 실패해 로컬에만 저장됐다 — 화면이 안내한다.
  ///
  /// **title은 서버에 보내지 않는다.** `RoutineStep`에 title 컬럼이 없다
  /// (2026-07-22 서버 확인, 이슈 #77). 서버 응답에도 title이 없으므로
  /// 그대로 받으면 다른 카드의 로컬 제목까지 지워진다 — 기존 제목을 되살려 합친다.
  Future<bool> updateStep({
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
    if (routine == null) return true;

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
    return result.synced;
  }

  /// 승인. 이 시점 이후에만 아동 화면에 노출된다 (docs 원칙 3번).
  Future<void> confirm() async {
    AppLogger.notifierCall('RoutineFlowNotifier', 'confirm');
    AppLogger.notifierStateChange('RoutineFlowNotifier', state.step.name, 'done');

    final routine = state.routine;
    if (routine == null) return;

    final repo = ref.read(routineRepositoryProvider);
    final confirmed = await repo.confirm(routine);
    state = state.copyWith(step: RoutineFlowStep.done, routine: confirmed);
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
    state = const RoutineFlowState();
  }
}
