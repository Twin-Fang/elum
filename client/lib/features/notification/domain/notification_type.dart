/// 알림 종류: 서버 `NotificationType` 5개와 1:1
enum NotificationType {
  routineCompleted('ROUTINE_COMPLETED'),
  routineSentByCoGuardian('ROUTINE_SENT_BY_CO_GUARDIAN'),
  coGuardianJoined('CO_GUARDIAN_JOINED'),
  creditRefilled('CREDIT_REFILLED'),
  feedbackResolved('FEEDBACK_RESOLVED');

  const NotificationType(this.wire);

  /// 서버가 보내는 문자열 그대로
  final String wire;

  /// 서버 코드 > 종류 (앱이 모르는 새 종류는 null)
  static NotificationType? fromServer(String? code) {
    for (final type in values) {
      if (type.wire == code) return type;
    }
    return null;
  }
}
