
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'app_log_interceptor.dart';
// 비활성 상태지만 되살릴 때 바로 쓰도록 남겨둔다
// ignore: unused_import

/// Dio 인스턴스 생성. 설정값은 전부 [AppConfig]에서 온다 — 하드코딩하지 않는다.
abstract final class DioClient {
  /// [attachLog] 가 true 면 의견 첨부용 기록 인터셉터를 붙인다.
  /// 다른 인터셉터를 더 붙일 호출부는 false 로 받아 **맨 뒤에** 직접 붙인다 —
  /// 앞에 붙으면 인증 갱신 전의 중간 결과와 나중에 붙는 헤더를 못 본다.
  static Dio create({bool attachLog = true}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
      ),
    );

    if (attachLog) dio.interceptors.add(AppLogInterceptor());

    return dio;
  }
}
