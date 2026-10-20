import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../../core/network/profile_header_interceptor.dart';
import '../domain/push_platform.dart';

/// 기기 푸시 토큰 등록·해제 (보호자 단위 API라 이룸이 헤더를 싣지 않고, 실패는 [AppFailure] 로 던짐)
class PushDeviceRepository {
  PushDeviceRepository(this._dio);

  final Dio _dio;

  static final _guardianLevelOptions = Options(
    extra: {ProfileHeaderInterceptor.skipKey: true},
  );

  /// 토큰 등록 (같은 토큰이면 서버가 갱신)
  Future<void> register(String token, PushPlatform platform) =>
      _call('register', () async {
        await _dio.put<void>(
          '/api/push-devices',
          data: {'token': token, 'platform': platform.wire},
          options: _guardianLevelOptions,
        );
      });

  /// 토큰 해제 (경로에 들어가므로 인코딩)
  Future<void> unregister(String token) => _call('unregister', () async {
    await _dio.delete<void>(
      '/api/push-devices/${Uri.encodeComponent(token)}',
      options: _guardianLevelOptions,
    );
  });

  Future<T> _call<T>(String operation, Future<T> Function() body) async {
    try {
      return await logged('PushDeviceRepository', operation, body);
    } catch (e) {
      throw AppFailure.of(e);
    }
  }
}

final pushDeviceRepositoryProvider = Provider<PushDeviceRepository>(
  (ref) => PushDeviceRepository(ref.watch(dioProvider)),
);
