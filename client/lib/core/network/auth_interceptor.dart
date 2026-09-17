import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
    VoidCallback? onSessionExpired,
  })  : _tokens = tokens,
        _dio = dio,
        _refresh = refresh,
        _onSessionExpired = onSessionExpired;

  final TokenStore _tokens;
  final Dio _dio;

  /// 갱신 함수. **호출부가 동시 호출을 하나로 묶어야 한다.**
  /// 서버가 회전 방식이라 같은 리프레시 토큰을 두 번 쓰면 세션이 전부 끊긴다.
  final Future<String?> Function() _refresh;

  /// 갱신까지 실패했을 때 알린다. 세션이 끝났다는 뜻이다.
  ///
  /// 라우터 가드만으로는 부족하다 — 가드는 **화면을 옮길 때** 평가되므로,
  /// 이미 홈에 머무는 중이면 다시 불리지 않는다. 그래서 서버 요청이 전부 401로
  /// 실패하는데도 화면은 정상처럼 남아 있었다 (이슈 #175).
  final VoidCallback? _onSessionExpired;

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
      // 갱신도 실패했다 — 세션이 끝난 것이다.
      //
      // 원래 401은 그대로 돌려줘 호출부가 각자 판단하게 두되, **세션이 끝났다는
      // 사실은 따로 알린다.** 이것을 알리지 않으면 화면은 캐시로 계속 그려져
      // 로그인이 풀린 줄 모른 채 쓰게 된다 (이슈 #175).
      AppLogger.error('토큰 갱신', '갱신 실패 → 세션 종료');
      await _tokens.clear();
      _onSessionExpired?.call();
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
