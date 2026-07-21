import 'package:freezed_annotation/freezed_annotation.dart';

import 'action_card.dart';

part 'routine.freezed.dart';

/// 일과 — 서버 `RoutineResponse`에 대응한다.
///
/// 출처: server/.../routine/application/dto/response/RoutineResponse.java
///
/// ⚠️ [rawInputText]는 **마스킹 전 원문**이다. 로그에 남기지 않는다 (docs 원칙 5번).
@freezed
abstract class Routine with _$Routine {
  const factory Routine({
    required String id,

    /// AI가 붙인 제목 (예: "비 오는 날 학교 가기")
    @Default('') String title,

    /// 보호자가 입력한 원문 — 마스킹 **전**. 화면 비교용으로만 쓴다.
    @Default('') String rawInputText,

    /// 민감정보를 카테고리 태그로 치환한 텍스트 — 실제 LLM에 전달된 값.
    /// 발표의 "전송 전/후 비교" 장면이 이 필드로 성립한다.
    @Default('') String sanitizedInputText,

    /// 상태 (`PENDING_REVIEW` / `CONFIRMED` 등)
    @Default('') String status,
    @Default(<ActionCard>[]) List<ActionCard> steps,
  }) = _Routine;

  const Routine._();

  /// 보호자가 승인했는가. 승인 전에는 아동 화면에 노출하지 않는다 (docs 원칙 3번).
  bool get isConfirmed => status == 'CONFIRMED';

  /// DLP가 실제로 무언가를 바꿨는가.
  /// 둘이 같으면 탐지된 민감정보가 없다는 뜻이다.
  bool get hasMaskedContent =>
      sanitizedInputText.isNotEmpty && rawInputText != sanitizedInputText;

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      rawInputText: json['rawInputText']?.toString() ?? '',
      sanitizedInputText: json['sanitizedInputText']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      steps: switch (json['steps']) {
        final List<dynamic> list => list
            .whereType<Map<String, dynamic>>()
            .map(ActionCard.fromJson)
            .toList(),
        _ => const <ActionCard>[],
      },
    );
  }
}

/// AI 추가 질문 — 서버 `RoutineQuestionResponse`에 대응.
///
/// 서버는 이 엔드포인트가 **실패해도 항상 200**을 준다.
/// [isRequired]가 false면 질문 단계를 건너뛰고 바로 카드 생성으로 간다.
@freezed
abstract class RoutineQuestion with _$RoutineQuestion {
  const factory RoutineQuestion({
    /// 서버 필드명은 `required`지만 Dart 예약어와 겹쳐 이름을 바꿨다.
    /// JSON 파싱에서 'required' 키를 읽는다.
    @Default(false) bool isRequired,
    String? question,
    @Default(<String>[]) List<String> options,
  }) = _RoutineQuestion;

  const RoutineQuestion._();

  /// 질문을 실제로 보여줄 수 있는 상태인가
  bool get canAsk =>
      isRequired && (question?.trim().isNotEmpty ?? false);

  factory RoutineQuestion.fromJson(Map<String, dynamic> json) {
    return RoutineQuestion(
      isRequired: json['required'] == true,
      question: json['question']?.toString(),
      options: switch (json['options']) {
        final List<dynamic> list => list.map((e) => e.toString()).toList(),
        _ => const <String>[],
      },
    );
  }
}
