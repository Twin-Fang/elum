import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
      dio.interceptors.add(SafeLogInterceptor());
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
///
/// 인터셉터는 Dio 인스턴스당 하나만 생성되어 모든 요청이 공유한다.
/// 따라서 소요시간 측정값을 인스턴스 필드에 담으면 안 된다 —
/// 두 번째 요청에서 재할당 에러가 나고, 동시 요청끼리 값이 뒤섞인다.
/// 요청별 상태는 반드시 [RequestOptions.extra]에 실어 요청과 함께 흐르게 한다.
@visibleForTesting
class SafeLogInterceptor extends Interceptor {
  /// 요청 시작 시각을 담는 `extra` 키. 다른 인터셉터와 겹치지 않게 접두사를 붙인다.
  static const _startKey = '_elumRequestStart';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = Stopwatch()..start();
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
    AppLogger.networkSuccess(
      method: response.requestOptions.method,
      endpoint: response.requestOptions.path,
      statusCode: response.statusCode ?? 0,
      duration: _elapsedOf(response.requestOptions),
      responseData: response.data,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.networkError(
      method: err.requestOptions.method,
      endpoint: err.requestOptions.path,
      statusCode: err.response?.statusCode ?? 0,
      duration: _elapsedOf(err.requestOptions),
      errorData: err.response?.data,
      errorMessage: err.message,
    );
    handler.next(err);
  }

  /// 요청에 실린 Stopwatch에서 소요시간을 꺼낸다.
  ///
  /// onRequest를 거치지 않고 들어오는 응답·에러가 있다(다른 인터셉터가 요청을
  /// 가로채 resolve/reject한 경우). 그때 값이 없다고 예외를 던지면 로깅 때문에
  /// 실제 통신이 실패하므로, 측정 불가는 0으로 흘려보낸다.
  Duration _elapsedOf(RequestOptions options) {
    final watch = options.extra[_startKey];
    if (watch is! Stopwatch) return Duration.zero;
    watch.stop();
    return watch.elapsed;
  }
}
