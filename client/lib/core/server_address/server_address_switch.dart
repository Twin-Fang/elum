import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_status/app_status.dart';
import '../config/app_config.dart';
import '../config/server_address_policy.dart';
import '../logger/app_logger.dart';
import 'assigned_server_address_store.dart';

/// 서버 주소 원격 전환: 상태 응답 주소 > 허용 목록 > 새 주소 확인 요청 > 저장 > 다시 띄우기 판단 (#831)
/// 되돌리기 2개: 서버가 null > 저장값 지움, 저장 주소로 시작한 실행이 연속 3회 연결 오류 > 저장값 지움 (둘 다 다음 실행부터)
class ServerAddressSwitch {
  // 새 주소 확인 요청 대기 (연결·응답 각각 5초)
  static const _probeTimeout = Duration(seconds: 5);
  // 저장 주소로 시작해 이 횟수만큼 연속 실행이 연결 오류면 기본 주소로
  static const _maximumFailedLaunchCount = 3;
  static const _appStatusPath = '/api/app/status';

  // 실행(프로세스)마다 첫 상태 조회만 셈 (앞으로 올라올 때마다 세면 한 실행에 3회가 참)
  static bool _hasRecordedLaunchOutcome = false;

  /// 이번 실행 첫 상태 조회 결과 기록 (서버 지정 주소로 시작한 실행만). 던지지 않음
  Future<void> recordLaunchOutcome({required bool isServerUnreachable}) async {
    if (_hasRecordedLaunchOutcome) return;
    _hasRecordedLaunchOutcome = true;
    if (AppConfig.apiBaseUrlSource != ApiBaseUrlSource.serverAssigned) return;
    try {
      final store = await AssignedServerAddressStore.open();
      if (!isServerUnreachable) {
        await store.resetFailedLaunchCount();
        return;
      }
      final failedLaunchCount = await store.addFailedLaunch();
      if (failedLaunchCount < _maximumFailedLaunchCount) {
        AppLogger.info('[server address] assigned server unreachable : launch $failedLaunchCount/$_maximumFailedLaunchCount');
        return;
      }
      await store.clear();
      AppLogger.info('[server address] rolled back : ${AppConfig.apiBaseUrl} unreachable $failedLaunchCount launches -> default from next launch');
    } catch (error, stackTrace) {
      AppLogger.error('server address', error, stackTrace, {'step': 'recordLaunchOutcome'});
    }
  }

  /// 상태 응답의 새 주소 판단 > 지금 바로 다시 띄워야 하면 true. 어느 실패도 던지지 않고 false (지금 주소 유지)
  Future<bool> prepareSwitch(AppStatus status) async {
    try {
      return await _prepareSwitch(status);
    } catch (error, stackTrace) {
      AppLogger.error('server address', error, stackTrace, {'step': 'prepareSwitch'});
      return false;
    }
  }

  Future<bool> _prepareSwitch(AppStatus status) async {
    // 응답에 server 없음·형식 다름 > 무시
    final serverAddress = status.serverAddress;
    if (serverAddress == null) return false;
    // 개발자 도구 지정 주소 사용 중 > 무시 (테스트 서버 응답이 서버 지정 저장값을 바꾸지 않게)
    if (AppConfig.apiBaseUrlSource == ApiBaseUrlSource.devTools) return false;

    // 서버가 비움 > 저장값만 지움 (이번 실행은 지금 주소 그대로)
    final requestedApiBaseUrl = serverAddress.apiBaseUrl;
    if (requestedApiBaseUrl == null) {
      await _clearSavedAddress();
      return false;
    }

    // 허용 목록 밖 > 무시
    final targetApiBaseUrl = ServerAddressPolicy.toAllowedApiBaseUrl(requestedApiBaseUrl);
    if (targetApiBaseUrl == null) {
      AppLogger.info('[server address] ignored : not allowed address $requestedApiBaseUrl');
      return false;
    }
    if (_isSameAddress(targetApiBaseUrl, AppConfig.apiBaseUrl)) return false;

    // 새 주소 확인 (200·파싱 성공, 다른 곳으로 다시 보내지 않음)
    if (!await _isServerReady(targetApiBaseUrl)) return false;

    // 저장 > 적용 (기본 주소와 같으면 저장값을 지워 .env 를 따라감)
    final store = await AssignedServerAddressStore.open();
    if (_isSameAddress(targetApiBaseUrl, AppConfig.defaultApiBaseUrl)) {
      await store.clear();
      AppConfig.applyAssignedApiBaseUrl(null);
    } else {
      await store.save(targetApiBaseUrl);
      AppConfig.applyAssignedApiBaseUrl(targetApiBaseUrl);
    }
    AppLogger.info('[server address] switched : -> $targetApiBaseUrl (restart without logout)');
    return true;
  }

  Future<void> _clearSavedAddress() async {
    final store = await AssignedServerAddressStore.open();
    final savedApiBaseUrl = store.savedApiBaseUrl;
    if (savedApiBaseUrl == null) return;
    await store.clear();
    AppLogger.info('[server address] cleared by server : $savedApiBaseUrl -> default from next launch');
  }

  /// 새 주소 `/api/app/status` 확인: 200 + 파싱 성공 + 또 다른 주소로 보내지 않음
  /// 인증 헤더 없는 별도 Dio (확인 전 주소에 토큰을 보내지 않음)
  Future<bool> _isServerReady(String apiBaseUrl) async {
    final probeDio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: _probeTimeout,
      receiveTimeout: _probeTimeout,
    ));
    try {
      final response = await probeDio.get<Object?>(_appStatusPath);
      final responseBody = response.data;
      if (response.statusCode != 200 || responseBody is! Map<String, dynamic>) {
        AppLogger.info('[server address] probe rejected : $apiBaseUrl status ${response.statusCode}, body not json');
        return false;
      }
      final probedStatus = AppStatus.fromJson(responseBody);
      // 두 서버가 서로를 가리키면 다시 띄우기가 끝없이 반복됨 > 전환 안 함
      final forwardedApiBaseUrl = ServerAddressPolicy.toAllowedApiBaseUrl(
        probedStatus.serverAddress?.apiBaseUrl,
      );
      if (forwardedApiBaseUrl != null && !_isSameAddress(forwardedApiBaseUrl, apiBaseUrl)) {
        AppLogger.info('[server address] probe rejected : $apiBaseUrl points to $forwardedApiBaseUrl');
        return false;
      }
      return true;
    } catch (error) {
      AppLogger.info('[server address] probe failed : $apiBaseUrl keep current address ($error)');
      return false;
    } finally {
      probeDio.close(force: true);
    }
  }

  static bool _isSameAddress(String left, String right) =>
      _normalized(left) == _normalized(right);

  static String _normalized(String apiBaseUrl) =>
      apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '').toLowerCase();
}

final serverAddressSwitchProvider = Provider<ServerAddressSwitch>(
  (ref) => ServerAddressSwitch(),
);
