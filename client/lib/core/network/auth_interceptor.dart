import 'package:dio/dio.dart';

import '../logger/app_logger.dart';
import '../storage/token_store.dart';

/// Authorization 헤더를 붙이고, 토큰 만료(401)를 자동 복구한다.
///
/// 액세스 토큰이 1일이므로 **만료는 반드시 발생한다.** 사용자가 그때마다 다시
/// 로그인하지 않도록 여기서 조용히 갱신하고 원요청을 재시도한다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStore tokens,
    required Dio dio,
    required Future<String?> Function() refresh,
  })  : _tokens = tokens,
        _dio = dio,
        _refresh = refresh;

  final TokenStore _tokens;
  final Dio _dio;

  /// 갱신 함수. **호출부가 동시 호출을 하나로 묶어야 한다.**
  /// 서버가 회전 방식이라 같은 리프레시 토큰을 두 번 쓰면 세션이 전부 끊긴다.
  final Future<String?> Function() _refresh;

  /// 재시도한 요청임을 표시하는 키. 무한 루프 방지의 핵심이다.
  static const _retriedKey = 'authRetried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 로그인·갱신 요청에는 토큰이 필요 없다. 만료된 토큰을 붙이면 오히려 방해된다.
    if (!options.path.startsWith('/api/auth')) {
      final token = _tokens.accessToken;
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

    // 갱신 후 재시도한 요청이 또 401이면 그대로 실패시킨다.
    // 여기서 다시 갱신하면 무한 루프가 된다.
    if (!isUnauthorized || alreadyRetried) {
      return handler.next(err);
    }

    final token = await _refresh();
    if (token == null || token.isEmpty) {
      // 갱신도 실패했다. 원래 401을 그대로 돌려줘 호출부가 판단하게 한다.
      // 세션이 끝난 경우 토큰은 이미 지워져 있으므로 라우터가 로그인으로 보낸다.
      AppLogger.error('토큰 갱신', '갱신 실패 → 원요청을 포기한다');
      return handler.next(err);
    }

    try {
      final retried = await _retry(err.requestOptions, token);
      handler.resolve(retried);
    } catch (e) {
      AppLogger.error('요청 재시도', e);
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
        // 이 플래그가 있어야 다음 401에서 갱신을 반복하지 않는다
        extra: {...options.extra, _retriedKey: true},
      ),
    );
  }
}
