import 'package:flutter/foundation.dart';

/// 알림 설정: 푸시 여부 8개 (알림 목록은 설정과 무관하게 항상 쌓임)
/// JSON 키는 서버 `NotificationSettingResponse` 그대로, 저장 행이 없으면 모두 켜짐
@immutable
class NotificationSettings {
  const NotificationSettings({
    required this.isAllEnabled,
    required this.isRoutineCompletedEnabled,
    required this.isRoutineSentEnabled,
    required this.isCoGuardianJoinedEnabled,
    required this.isCreditRefilledEnabled,
    required this.isFeedbackResolvedEnabled,
    required this.isTalkCommentedEnabled,
    required this.isTalkImportedEnabled,
  });

  /// 전체 푸시: false 면 종류별 값과 무관하게 푸시 없음
  final bool isAllEnabled;
  final bool isRoutineCompletedEnabled;
  final bool isRoutineSentEnabled;
  final bool isCoGuardianJoinedEnabled;
  final bool isCreditRefilledEnabled;
  final bool isFeedbackResolvedEnabled;
  final bool isTalkCommentedEnabled;
  final bool isTalkImportedEnabled;

  static const allOn = NotificationSettings(
    isAllEnabled: true,
    isRoutineCompletedEnabled: true,
    isRoutineSentEnabled: true,
    isCoGuardianJoinedEnabled: true,
    isCreditRefilledEnabled: true,
    isFeedbackResolvedEnabled: true,
    isTalkCommentedEnabled: true,
    isTalkImportedEnabled: true,
  );

  NotificationSettings copyWith({
    bool? isAllEnabled,
    bool? isRoutineCompletedEnabled,
    bool? isRoutineSentEnabled,
    bool? isCoGuardianJoinedEnabled,
    bool? isCreditRefilledEnabled,
    bool? isFeedbackResolvedEnabled,
    bool? isTalkCommentedEnabled,
    bool? isTalkImportedEnabled,
  }) =>
      NotificationSettings(
        isAllEnabled: isAllEnabled ?? this.isAllEnabled,
        isRoutineCompletedEnabled:
            isRoutineCompletedEnabled ?? this.isRoutineCompletedEnabled,
        isRoutineSentEnabled: isRoutineSentEnabled ?? this.isRoutineSentEnabled,
        isCoGuardianJoinedEnabled:
            isCoGuardianJoinedEnabled ?? this.isCoGuardianJoinedEnabled,
        isCreditRefilledEnabled:
            isCreditRefilledEnabled ?? this.isCreditRefilledEnabled,
        isFeedbackResolvedEnabled:
            isFeedbackResolvedEnabled ?? this.isFeedbackResolvedEnabled,
        isTalkCommentedEnabled:
            isTalkCommentedEnabled ?? this.isTalkCommentedEnabled,
        isTalkImportedEnabled:
            isTalkImportedEnabled ?? this.isTalkImportedEnabled,
      );

  /// 빠진 키는 켜짐으로 읽는다 (서버 기본값과 같음)
  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        isAllEnabled: json['allEnabled'] != false,
        isRoutineCompletedEnabled: json['routineCompleted'] != false,
        isRoutineSentEnabled: json['routineSent'] != false,
        isCoGuardianJoinedEnabled: json['coGuardianJoined'] != false,
        isCreditRefilledEnabled: json['creditRefilled'] != false,
        isFeedbackResolvedEnabled: json['feedbackResolved'] != false,
        isTalkCommentedEnabled: json['talkCommented'] != false,
        isTalkImportedEnabled: json['talkImported'] != false,
      );

  Map<String, dynamic> toJson() => {
        'allEnabled': isAllEnabled,
        'routineCompleted': isRoutineCompletedEnabled,
        'routineSent': isRoutineSentEnabled,
        'coGuardianJoined': isCoGuardianJoinedEnabled,
        'creditRefilled': isCreditRefilledEnabled,
        'feedbackResolved': isFeedbackResolvedEnabled,
        'talkCommented': isTalkCommentedEnabled,
        'talkImported': isTalkImportedEnabled,
      };

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.isAllEnabled == isAllEnabled &&
      other.isRoutineCompletedEnabled == isRoutineCompletedEnabled &&
      other.isRoutineSentEnabled == isRoutineSentEnabled &&
      other.isCoGuardianJoinedEnabled == isCoGuardianJoinedEnabled &&
      other.isCreditRefilledEnabled == isCreditRefilledEnabled &&
      other.isFeedbackResolvedEnabled == isFeedbackResolvedEnabled &&
      other.isTalkCommentedEnabled == isTalkCommentedEnabled &&
      other.isTalkImportedEnabled == isTalkImportedEnabled;

  @override
  int get hashCode => Object.hash(
        isAllEnabled,
        isRoutineCompletedEnabled,
        isRoutineSentEnabled,
        isCoGuardianJoinedEnabled,
        isCreditRefilledEnabled,
        isFeedbackResolvedEnabled,
        isTalkCommentedEnabled,
        isTalkImportedEnabled,
      );
}
