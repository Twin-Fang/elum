import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../app_status/app_status.dart';
import '../config/app_config.dart';

/// 앱 상태 흉내 4개: 끔, 업데이트 권유, 강제 업데이트, 점검
enum DevAppStatusSimulation {
  off('끔 (서버 값)'),
  suggestUpdate('업데이트 권유'),
  forceUpdate('강제 업데이트'),
  maintenance('점검 중');

  const DevAppStatusSimulation(this.label);

  final String label;
}

/// 요청 실패 흉내 4개: 끔, 네트워크 끊김, 응답 지연, 서버 오류 500
enum DevNetworkFault {
  off('끔'),
  offline('네트워크 끊김'),
  timeout('응답 지연 (타임아웃)'),
  serverError('서버 오류 500');

  const DevNetworkFault(this.label);

  final String label;
}

/// 이 기기에서만 켜는 흉내 상태 (개발자 도구 빌드만)
/// 메모리 정적 값: 앱 트리를 다시 만들어도 남고, 앱을 끄면 사라짐
abstract final class DevSimulation {
  static final appStatus = ValueNotifier(DevAppStatusSimulation.off);
  static final networkFault = ValueNotifier(DevNetworkFault.off);

  // 흉내 버전: 어떤 실제 버전보다 높음
  static const _unreachableVersion = '999.0.0';

  /// 켜진 앱 상태 흉내의 값. 꺼졌거나 개발자 도구가 없는 빌드면 null
  static AppStatus? simulatedAppStatus() {
    if (!AppConfig.showDevTools) return null;
    return switch (appStatus.value) {
      DevAppStatusSimulation.off => null,
      DevAppStatusSimulation.suggestUpdate => const AppStatus(latestVersion: _unreachableVersion),
      DevAppStatusSimulation.forceUpdate => const AppStatus(minVersion: _unreachableVersion),
      DevAppStatusSimulation.maintenance => const AppStatus(maintenance: true),
    };
  }

  /// 업데이트 권유 흉내 중인가 (권유 판정이 스토어 확인을 건너뜀)
  static bool get isSuggestingUpdate =>
      AppConfig.showDevTools && appStatus.value == DevAppStatusSimulation.suggestUpdate;

  /// 켜져 있는 흉내 요약 (디버깅 버튼 아래 표시). 없으면 빈 목록
  static List<String> activeLabels() => [
    if (appStatus.value != DevAppStatusSimulation.off) appStatus.value.label,
    if (networkFault.value != DevNetworkFault.off) networkFault.value.label,
  ];
}

/// 요청 실패 흉내: 켜져 있으면 요청을 보내지 않고 고른 실패로 끝냄
/// 인터셉터 맨 앞에 붙임 > 뒤의 실패 해석·기록 인터셉터가 진짜 실패처럼 처리
class DevFaultInterceptor extends Interceptor {
  // 응답 지연 흉내에서 실패하기까지 기다리는 시간
  static const _timeoutDelay = Duration(seconds: 3);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final fault = DevSimulation.networkFault.value;
    if (fault == DevNetworkFault.off) return handler.next(options);

    if (fault == DevNetworkFault.timeout) await Future<void>.delayed(_timeoutDelay);
    // callFollowingErrorInterceptor: 실패 해석(AppFailure)·기록이 그대로 돌게
    handler.reject(_faultError(fault, options), true);
  }

  static DioException _faultError(DevNetworkFault fault, RequestOptions options) =>
      switch (fault) {
        DevNetworkFault.offline || DevNetworkFault.off => DioException.connectionError(
          requestOptions: options,
          reason: 'dev simulation: offline',
        ),
        DevNetworkFault.timeout => DioException.receiveTimeout(
          timeout: _timeoutDelay,
          requestOptions: options,
        ),
        DevNetworkFault.serverError => DioException.badResponse(
          statusCode: 500,
          requestOptions: options,
          response: Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 500,
            data: const {
              'errorCode': 'INTERNAL_SERVER_ERROR',
              'errorMessage': '개발자 도구 서버 오류 흉내',
            },
          ),
        ),
      };
}
