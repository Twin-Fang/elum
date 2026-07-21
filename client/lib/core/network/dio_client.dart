import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/onboarding/application/onboarding_notifier.dart';
import '../config/app_config.dart';
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

/// 로깅 인터셉터.
///
/// ⚠️ **요청 본문(보호자 입력 원문)은 절대 찍지 않는다.** (docs 원칙 5번)
/// 원문은 감사 로그에도 남기지 않는 것이 서비스 원칙이므로, 개발 로그도 예외가 아니다.
/// 경로·상태코드·소요시간만 남긴다.
class _SafeLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[api] → ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[api] ← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[api] ✗ ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.path}',
    );
    handler.next(err);
  }
}
