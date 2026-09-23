import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/dio_client.dart';
import '../domain/app_notice.dart';

/// 공지를 받을 플랫폼. 값은 서버 `NoticePlatform` enum 과 같다 (#370).
enum NoticePlatform {
  ios('IOS'),
  android('ANDROID');

  const NoticePlatform(this.wire);

  final String wire;

  /// `dart:io` 의 Platform 대신 [defaultTargetPlatform] 으로 가린다 —
  /// 테스트에서 바꿔 볼 수 있어야 스토어별 공지가 섞이지 않는지 확인할 수 있다.
  static NoticePlatform get current =>
      defaultTargetPlatform == TargetPlatform.iOS ? ios : android;
}

/// 관리자가 올린 공지를 받는다 (이슈 #371 · 명세 3-1).
///
/// **못 받으면 빈 목록이다(N1).** 공지는 부가 기능이라 앱을 막지 않고 에러 화면도
/// 띄우지 않는다 — 앱 상태 조회(#279)와 같은 판단이다. 서버가 아직 공지 API 를
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
      final res = await _dio.get<Object?>(
        '/api/app/notices',
        queryParameters: {'platform': platform.wire},
      );
      return NoticeFeed.fromJson(res.data, baseUrl: _dio.options.baseUrl);
    } catch (e, st) {
      AppLogger.error('notice', e, st, {
        'step': 'fetch',
        'code': AppFailure.of(e).badgeOr(failureCode),
      });
      return NoticeFeed.empty;
    }
  }
}

final noticeRepositoryProvider = Provider<NoticeRepository>(
  (ref) => NoticeRepository(ref.watch(dioProvider)),
);
