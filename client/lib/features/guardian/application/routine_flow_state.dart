import '../../../core/network/app_failure.dart';
import '../../../shared/models/credit_usage.dart';
import '../../../shared/models/routine.dart';

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
    this.questionInput = '',
    this.answers = const [],
    this.customOptions = const {},
    this.rewardText = '',
    this.rewardPresetKey = '',
    this.routine,
    this.errorCode,
    this.errorMessage,
    this.errorFault,
    this.idempotencyKey,
    this.creditUsage,
  });

  final RoutineFlowStep step;
  final String rawInput;
  final String maskedInput;

  /// 탐지된 민감정보 **유형**만. 원문은 담지 않는다.
  final List<String> detectedTypes;
  final RoutineQuestion? question;

  /// [question] 을 받아 올 때 보낸 입력. [answers] 는 이 입력에 딸린다.
  ///
  /// 보상으로 되돌아갔다 오면 준비 로딩이 다시 묻는다. 입력이 그대로면 같은 질문을
  /// 다시 쓰고 답도 남기고, 바뀌었으면 새로 받고 답을 비운다 — 안 그러면 수영장
  /// 질문 옆에 우산이 골라진 채 남는다.
  final String questionInput;
  final List<String> answers;

  /// 보호자가 직접 적어 넣은 선택지. 질문 문구별로 나눠 담는다.
  ///
  /// [answers]에만 넣으면 칩 목록(`item.options`)에는 없는데 선택은 된 상태가 돼
  /// 화면에 보이지 않는다. 어느 질문에 추가했는지도 알아야 그 질문 아래에 그린다.
  final Map<String, List<String>> customOptions;

  /// 보호자가 카드 생성 **전에** 정한 보상.
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
  /// 다시 누른다.
  final String? errorMessage;

  /// 실패의 네트워크 사정. 문구가 아니라 **원인**을 담는다 — 문구를 담으면 앱 언어가
  /// 바뀐 뒤에도 이전 언어로 남는다. [errorHint] 가 읽을 때 현재 언어로 푼다.
  final NetworkFault? errorFault;

  /// 무엇을 하면 되는지 — 네트워크 사정이라 서버가 말해 줄 수 없을 때만 있다
  /// ([AppFailure.hint]). 오프라인인데 `잠시 후 다시 해주세요` 만 띄우면 끊긴 채로
  /// 다시 하기만 누른다. 화면의 `build` 안에서 읽는다.
  String? get errorHint {
    final fault = errorFault;
    return fault == null ? null : AppFailure(fault: fault).hint;
  }

  /// 카드 생성 요청의 멱등 키. 같은 요청의 재시도는 이 키를 다시 쓴다.
  final String? idempotencyKey;

  /// 이번 생성이 쓴 크레딧. 카드 확인 머리 아래 한 줄로 보인다. 크레딧이 꺼져 있거나
  /// 이미 만든 일과를 연 경우 null 이다.
  final CreditUsage? creditUsage;

  RoutineFlowState copyWith({
    RoutineFlowStep? step,
    String? rawInput,
    String? maskedInput,
    List<String>? detectedTypes,
    RoutineQuestion? question,
    String? questionInput,
    List<String>? answers,
    Map<String, List<String>>? customOptions,
    String? rewardText,
    String? rewardPresetKey,
    Routine? routine,
    String? errorCode,
    String? errorMessage,
    NetworkFault? errorFault,
    String? idempotencyKey,
    CreditUsage? creditUsage,
  }) {
    return RoutineFlowState(
      step: step ?? this.step,
      rawInput: rawInput ?? this.rawInput,
      maskedInput: maskedInput ?? this.maskedInput,
      detectedTypes: detectedTypes ?? this.detectedTypes,
      question: question ?? this.question,
      questionInput: questionInput ?? this.questionInput,
      answers: answers ?? this.answers,
      customOptions: customOptions ?? this.customOptions,
      rewardText: rewardText ?? this.rewardText,
      rewardPresetKey: rewardPresetKey ?? this.rewardPresetKey,
      routine: routine ?? this.routine,
      // errorCode는 null로 되돌릴 수 있어야 한다(재시도 시 초기화) → ?? 쓰지 않는다.
      errorCode: errorCode,
      errorMessage: errorMessage,
      errorFault: errorFault,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      creditUsage: creditUsage ?? this.creditUsage,
    );
  }
}
