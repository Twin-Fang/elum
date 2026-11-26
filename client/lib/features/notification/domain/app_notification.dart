import 'package:flutter/foundation.dart';

import 'notification_type.dart';

/// 알림 목록 한 줄 (서버 `NotificationItemResponse`)
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.count,
    required this.occurredAt,
    required this.isRead,
    this.profileId,
    this.profileName,
    this.targetId,
    this.routineTitle,
    this.title,
    this.body,
    this.route,
    this.feedbackSentAt,
  });

  final String id;
  final NotificationType type;

  /// 지워졌거나 접근할 수 없으면 null
  final String? profileId;
  final String? profileName;
  final String? targetId;
  final String? routineTitle;

  /// 운영자 알림만: 관리자가 쓴 제목, 눌렀을 때 갈 화면 (`home` · `plan` · `myCredit`)
  final String? title;
  final String? route;

  /// 운영자 알림 본문 또는 의견 처리 알림의 보낸 의견 본문 (지워졌으면 null)
  final String? body;

  /// 의견 처리 알림만: 그 의견을 보낸 시각
  final DateTime? feedbackSentAt;

  /// 묶인 건수 (일과 완료 등)
  final int count;
  final DateTime occurredAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        profileId: profileId,
        profileName: profileName,
        targetId: targetId,
        routineTitle: routineTitle,
        title: title,
        body: body,
        route: route,
        feedbackSentAt: feedbackSentAt,
        count: count,
        occurredAt: occurredAt,
        isRead: isRead ?? this.isRead,
      );

  /// 모르는 종류거나 필수값이 깨졌으면 null (그 줄만 버린다)
  static AppNotification? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final rawType = json['type'];
    final type = rawType is String ? NotificationType.fromServer(rawType) : null;
    final occurredAtRaw = json['occurredAt'];
    if (id is! String || id.isEmpty || type == null) return null;
    if (occurredAtRaw is! String) return null;
    final occurredAt = DateTime.tryParse(occurredAtRaw);
    if (occurredAt == null) return null;

    return AppNotification(
      id: id,
      type: type,
      profileId: _readText(json['profileId']),
      profileName: _readText(json['profileName']),
      targetId: _readText(json['targetId']),
      routineTitle: _readText(json['routineTitle']),
      title: _readText(json['title']),
      body: _readText(json['body']),
      route: _readText(json['route']),
      feedbackSentAt: DateTime.tryParse(_readText(json['feedbackSentAt']) ?? ''),
      count: json['count'] is num ? (json['count'] as num).toInt() : 1,
      occurredAt: occurredAt,
      isRead: json['isRead'] == true,
    );
  }

  static String? _readText(Object? raw) => raw is String ? raw : null;
}

/// 알림 목록 한 쪽. [nextCursor] 가 null 이면 마지막 쪽
@immutable
class NotificationPage {
  const NotificationPage({required this.items, this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;

  /// 항목 하나가 깨져도 나머지는 살린다
  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = <AppNotification>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final notification = AppNotification.fromJson(Map<String, dynamic>.from(entry));
        if (notification != null) items.add(notification);
      }
    }
    final cursor = json['nextCursor'];
    return NotificationPage(
      items: List.unmodifiable(items),
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }
}
