import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../../core/network/profile_header_interceptor.dart';
import '../../notice/data/notice_repository.dart';
import '../domain/app_notification.dart';
import '../domain/notification_settings.dart';
import '../domain/unread_summary.dart';

/// 알림 목록·안 읽음 요약·읽음 처리·알림 설정.
/// 전부 보호자 단위 API라 이룸이 헤더를 싣지 않고, 실패는 [AppFailure] 로 던진다.
class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  /// 한 번에 받는 줄 수 (서버 기본값과 같음)
  static const defaultPageSize = 20;

  // 보호자 단위 API: X-Profile-Id 생략
  static final _guardianLevelOptions =
      Options(extra: {ProfileHeaderInterceptor.skipKey: true});

  /// 알림 한 쪽 (최신순). cursor 는 `|`·`:` 가 있어 queryParameters 로만 넘김
  Future<NotificationPage> fetchPage({String? cursor, int size = defaultPageSize}) =>
      _call('fetchPage', () async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/notifications',
          queryParameters: {'size': size, 'cursor': ?cursor},
          options: _guardianLevelOptions,
        );
        return NotificationPage.fromJson(_bodyOf(res));
      });

  Future<UnreadSummary> fetchUnreadSummary(NoticePlatform platform) =>
      _call('fetchUnreadSummary', () async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/notifications/unread-summary',
          queryParameters: {'platform': platform.wire},
          options: _guardianLevelOptions,
        );
        return UnreadSummary.fromJson(_bodyOf(res));
      });

  Future<void> markRead(String id) => _call('markRead', () async {
        await _dio.post<void>(
          '/api/notifications/${Uri.encodeComponent(id)}/read',
          options: _guardianLevelOptions,
        );
      });

  Future<void> markAllRead() => _call('markAllRead', () async {
        await _dio.post<void>(
          '/api/notifications/read-all',
          options: _guardianLevelOptions,
        );
      });

  Future<NotificationSettings> fetchSettings() =>
      _call('fetchSettings', () async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/notification-settings',
          options: _guardianLevelOptions,
        );
        return NotificationSettings.fromJson(_bodyOf(res));
      });

  /// 여섯 값을 통째로 저장 > 서버가 저장한 값 반환
  Future<NotificationSettings> saveSettings(NotificationSettings settings) =>
      _call('saveSettings', () async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/api/notification-settings',
          data: settings.toJson(),
          options: _guardianLevelOptions,
        );
        return NotificationSettings.fromJson(_bodyOf(res));
      });

  /// 로그 + 모든 실패를 [AppFailure] 로 통일
  Future<T> _call<T>(String operation, Future<T> Function() body) async {
    try {
      return await logged('NotificationRepository', operation, body);
    } catch (e) {
      throw AppFailure.of(e);
    }
  }

  Map<String, dynamic> _bodyOf(Response<Map<String, dynamic>> res) {
    final body = res.data;
    if (body == null) throw const FormatException('empty response');
    return body;
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(dioProvider)),
);
