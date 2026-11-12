import 'package:flutter/foundation.dart';

/// 받은 푸시 한 건: 서버가 보낸 data 문자열 맵(type, notificationId, profileId, targetId)과 표시 문구
/// 서버는 값이 없는 키를 아예 보내지 않음
@immutable
class PushMessage {
  const PushMessage({required this.data, this.title, this.body});

  final Map<String, String> data;
  final String? title;
  final String? body;

  /// 서버 알림 기록 id (읽음 처리용, 없으면 null)
  String? get notificationId => data['notificationId'];

  /// 자동·운영자 알림 발송 id data 키 (서버 PushMessageFactory 와 같은 값, #1275)
  static const dispatchIdKey = 'dispatchId';

  /// 발송 id (눌러 열었음 기록용, 자동·운영자 알림만 있음)
  String? get dispatchId => data[dispatchIdKey];
}
