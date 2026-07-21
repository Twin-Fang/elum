import 'package:freezed_annotation/freezed_annotation.dart';

part 'action_card.freezed.dart';

/// AI가 생성한 행동 카드 한 장 — 서버의 `RoutineStep`에 대응한다.
///
/// 원칙: **한 카드에는 하나의 행동만 담는다** (docs 원칙 4번).
///
/// ⚠️ 필드명은 서버 엔티티를 따른다.
/// 출처: server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/entity/RoutineStep.java
/// 서버가 바뀌면 이 파일을 먼저 맞춘다.
///
/// json_serializable은 riverpod 3.x의 analyzer 제약과 충돌해 쓰지 않는다.
/// 필드가 적어 수동 파싱으로 충분하며, 서버 응답이 어떻게 오든 죽지 않는 게 더 중요하다.
@freezed
abstract class ActionCard with _$ActionCard {
  const factory ActionCard({
    required String id,

    /// 아동에게 보여줄 짧은 문장 (TTS로도 읽힌다). 서버 `description`.
    required String description,

    /// 카드 제목 — Figma가 제목과 설명을 나눠 보여준다(`옷을 입어요` /
    /// `학교에 갈 옷을 차례대로 입어요`).
    ///
    /// **서버는 아직 주지 않는다.** `RoutineStepResponse`에 제목이 없어
    /// 로컬 카드에서만 채워진다. 비어 있으면 화면이 [description]을 대신 쓴다.
    @Default('') String title,

    /// 수행 순서. 서버 `stepOrder`.
    @Default(0) int stepOrder,

    /// 카드 이미지 경로. 서버 `imagePath`.
    String? imagePath,

    /// 수행 완료 여부. 서버 `completed`.
    @Default(false) bool completed,
  }) = _ActionCard;

  const ActionCard._();

  /// 화면에 띄울 제목. 서버가 제목을 안 주면 설명을 대신 쓴다.
  String get displayTitle => title.isNotEmpty ? title : description;

  /// 서버 응답 파싱. 필드가 비거나 타입이 달라도 예외를 던지지 않는다 —
  /// 카드 한 장 때문에 데모 전체가 멈추면 안 된다.
  factory ActionCard.fromJson(Map<String, dynamic> json) {
    return ActionCard(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      // 서버가 아직 주지 않는다. 주기 시작하면 그대로 읽힌다.
      title: json['title']?.toString() ?? '',
      stepOrder: switch (json['stepOrder']) {
        final int v => v,
        final String v => int.tryParse(v) ?? 0,
        _ => 0,
      },
      imagePath: json['imagePath']?.toString(),
      completed: json['completed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'title': title,
        'stepOrder': stepOrder,
        'imagePath': imagePath,
        'completed': completed,
      };
}
