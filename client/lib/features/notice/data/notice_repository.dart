import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../../core/network/profile_header_interceptor.dart';
import '../../../shared/models/notice_platform.dart';
import '../domain/app_notice.dart';
import '../../../app/dio_provider.dart';

/// 관리자가 올린 공지를 받는다 (명세 3-1).
///
/// **못 받으면 빈 목록이다(N1).** 공지는 부가 기능이라 앱을 막지 않고 에러 화면도
/// 띄우지 않는다 — 앱 상태 조회와 같은 판단이다. 서버가 아직 공지 API 를
/// 배포하지 않아 404 가 와도 보호자 홈은 평소처럼 떠야 한다.
///
/// 대신 **로그는 남긴다.** 조용히 삼키면 서버가 공지를 안 주는 건지, 앱이 못 받는
/// 건지 가릴 수 없다.
class NoticeRepository {
  NoticeRepository(this._dio);

  final Dio _dio;

  /// 로그에서 찾을 자리 코드. 화면에는 나가지 않는다 — 공지 실패는 사용자 몫이 아니다.
  static const failureCode = 'E-NOTICE';

  Future<NoticeFeed> fetch(NoticePlatform platform) async {
    try {
      return await logged('NoticeRepository', 'fetch', () async {
        final res = await _dio.get<Object?>(
          '/api/app/notices',
          queryParameters: {'platform': platform.wire},
        );
        return NoticeFeed.fromJson(res.data, baseUrl: _dio.options.baseUrl);
      });
    } catch (e, st) {
      AppLogger.error('notice', e, st, {
        'step': 'fetch',
        'code': AppFailure.of(e).badgeOr(failureCode),
      });
      return NoticeFeed.empty;
    }
  }

  /// 한 번에 받는 공지 수 (서버 기본값과 같음)
  static const historyPageSize = 20;

  /// 공지 탭 목록 한 쪽 (최근 90일, 게시 끝난 공지 포함). 부가 기능 [fetch] 와 달리 실패를 던짐
  Future<NoticeHistoryPage> fetchHistory(
    NoticePlatform platform, {
    String? cursor,
  }) async {
    try {
      return await logged('NoticeRepository', 'fetchHistory', () async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/notices/history',
          queryParameters: {
            'platform': platform.wire,
            'size': historyPageSize,
            'cursor': ?cursor,
          },
          options: Options(extra: {ProfileHeaderInterceptor.skipKey: true}),
        );
        final body = response.data;
        if (body == null) throw const FormatException('empty response');
        return NoticeHistoryPage.fromJson(body, baseUrl: _dio.options.baseUrl);
      });
    } catch (e) {
      throw AppFailure.of(e);
    }
  }

  /// 공지 탭을 열었다고 서버에 기록 (안 읽은 공지 표시 지움)
  Future<void> markSeen() async {
    try {
      await logged('NoticeRepository', 'markSeen', () async {
        await _dio.post<void>(
          '/api/notices/seen',
          options: Options(extra: {ProfileHeaderInterceptor.skipKey: true}),
        );
      });
    } catch (e) {
      throw AppFailure.of(e);
    }
  }
}

final noticeRepositoryProvider = Provider<NoticeRepository>(
  (ref) => NoticeRepository(ref.watch(dioProvider)),
);
