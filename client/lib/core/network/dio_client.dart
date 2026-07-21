import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/onboarding/application/onboarding_notifier.dart';
import '../config/app_config.dart';
import '../logger/app_logger.dart';
import 'auth_interceptor.dart';

/// Dio 인스턴스 생성. 설정값은 전부 [AppConfig]에서 온다 — 하드코딩하지 않는다.
abstract final class DioClient {
  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
      ),
    );

    if (AppConfig.enableNetworkLog) {
      dio.interceptors.add(_SafeLogInterceptor());
    }

    return dio;
  }
}

/// 앱 전역에서 쓰는 Dio.
///
/// 인증 인터셉터가 붙어 있어 Authorization 헤더와 토큰 재발급이 자동 처리된다.
/// repository는 이 provider를 통해서만 Dio를 받는다 — 각자 `DioClient.create()`를
/// 부르면 인터셉터 없는 인스턴스가 생겨 401이 그대로 터진다.
final dioProvider = Provider<Dio>((ref) {
  final dio = DioClient.create();
  final storage = ref.watch(localStorageProvider);

  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      dio: dio,
      // AuthRepository가 이 Dio를 다시 참조하면 순환이 생긴다.
      // 재발급은 인터셉터 없는 별도 인스턴스로 보낸다.
      reauthenticate: () => AuthRepository(
        dio: DioClient.create(),
        storage: storage,
      ).reauthenticate(),
    ),
  );

  return dio;
});

/// 로깅 인터셉터. 모든 API 요청/응답을 자동으로 로깅한다.
class _SafeLogInterceptor extends Interceptor {
  late final Stopwatch _timer;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _timer = Stopwatch()..start();
    AppLogger.networkRequest(
      method: options.method,
      endpoint: options.path,
      params: options.data is Map ? options.data : null,
      headers: options.headers.cast<String, String>(),
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _timer.stop();
    AppLogger.networkSuccess(
      method: response.requestOptions.method,
      endpoint: response.requestOptions.path,
      statusCode: response.statusCode ?? 0,
      duration: _timer.elapsed,
      responseData: response.data,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _timer.stop();
    AppLogger.networkError(
      method: err.requestOptions.method,
      endpoint: err.requestOptions.path,
      statusCode: err.response?.statusCode ?? 0,
      duration: _timer.elapsed,
      errorData: err.response?.data,
      errorMessage: err.message,
    );
    handler.next(err);
  }
}
