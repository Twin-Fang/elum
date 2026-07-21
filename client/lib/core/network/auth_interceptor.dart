import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/local_storage.dart';

/// Authorization 헤더를 붙이고, 토큰 만료(401)를 자동 복구한다.
///
/// 서버 `expiresIn`이 3600000ms(1시간)이므로 **토큰 만료는 반드시 발생한다.**
/// 데모 중에 터지면 치명적이라 여기서 조용히 재발급하고 원요청을 재시도한다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required LocalStorage storage,
    required Dio dio,
    required Future<String?> Function() reauthenticate,
  })  : _storage = storage,
        _dio = dio,
        _reauthenticate = reauthenticate;

  final LocalStorage _storage;
  final Dio _dio;
  final Future<String?> Function() _reauthenticate;

  /// 재시도한 요청임을 표시하는 키. 무한 루프 방지의 핵심이다.
  static const _retriedKey = 'authRetried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 로그인·회원가입은 토큰이 필요 없다. 만료된 토큰을 붙이면 오히려 방해된다.
    if (!options.path.startsWith('/api/auth')) {
      final token = _storage.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    // 재발급 후 재시도한 요청이 또 401이면 그대로 실패시킨다.
    // 여기서 다시 재발급하면 무한 루프가 된다.
    if (!isUnauthorized || alreadyRetried) {
      return handler.next(err);
    }

    final token = await _reauthenticate();
    if (token == null || token.isEmpty) {
      // 재발급도 실패했다. 원래 401을 그대로 돌려줘 호출부가 판단하게 한다.
      debugPrint('[auth] 토큰 재발급 실패 → 원요청을 포기한다');
      return handler.next(err);
    }

    try {
      final retried = await _retry(err.requestOptions, token);
      handler.resolve(retried);
    } catch (e) {
      debugPrint('[auth] 재시도 실패: $e');
      handler.next(err);
    }
  }

  /// 새 토큰으로 원요청을 한 번 더 보낸다.
  Future<Response<dynamic>> _retry(RequestOptions options, String token) {
    return _dio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      cancelToken: options.cancelToken,
      options: Options(
        method: options.method,
        headers: {...options.headers, 'Authorization': 'Bearer $token'},
        responseType: options.responseType,
        contentType: options.contentType,
        // 이 플래그가 있어야 다음 401에서 재발급을 반복하지 않는다
        extra: {...options.extra, _retriedKey: true},
      ),
    );
  }
}
