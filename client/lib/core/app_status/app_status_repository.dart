import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../dev/dev_simulation.dart';
import '../server_address/server_address_switch.dart';
import 'app_status.dart';
import 'app_status_recheck.dart';
import '../../app/dio_provider.dart';

/// 앱 상태 조회 결과: 상태, 서버에 닿지 못했나 (서버 지정 주소 되돌리기 판단, #831)
typedef AppStatusFetchResult = ({AppStatus status, bool isServerUnreachable});

/// 앱 상태 판정 재료: 상태, 지금 앱 버전, 새 서버로 바로 다시 띄워야 하나 (#831)
typedef AppStatusCheck = ({AppStatus status, String version, bool isServerSwitchReady});

// 서버 앞단(프록시)이 뒤 서버에 못 닿을 때 주는 코드 3개: 502, 503, 504 (앱 상태는 점검 중에도 200)
const _gatewayFailureStatusCodes = {502, 503, 504};

/// 서버에 닿지 못한 실패인가: 연결 실패·연결 대기 초과·응답 대기 초과·게이트웨이 실패
bool isServerUnreachableError(Object error) {
  if (error is! DioException) return false;
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout => true,
    DioExceptionType.badResponse =>
      _gatewayFailureStatusCodes.contains(error.response?.statusCode),
    _ => false,
  };
}

/// 앱 상태를 서버에 묻는다.
///
/// **실패는 조용히 넘긴다.** 이 요청이 안 되면 그냥 평소처럼 진행한다 —
/// 서버 상태를 확인하지 못했다는 이유로 앱을 막으면, 서버가 죽었을 때
/// 아무도 앱을 열 수 없다.
class AppStatusRepository {
  AppStatusRepository(this._dio);

  final Dio _dio;

  Future<AppStatusFetchResult> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/app/status');
      final data = res.data;
      if (data == null) return (status: AppStatus.unknown, isServerUnreachable: false);
      return (status: AppStatus.fromJson(data), isServerUnreachable: false);
    } catch (e) {
      debugPrint('[app-status] 확인하지 못했다 — 그대로 진행한다: $e');
      return (status: AppStatus.unknown, isServerUnreachable: isServerUnreachableError(e));
    }
  }

  /// 지금 앱 버전. 읽지 못하면 빈 문자열이고, 그러면 어떤 비교도 하지 않는다.
  static Future<String> currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      debugPrint('[app-status] 버전을 읽지 못했다: $e');
      return '';
    }
  }
}

final appStatusRepositoryProvider = Provider<AppStatusRepository>(
  (ref) => AppStatusRepository(ref.watch(dioProvider)),
);

/// 지금 앱 버전만 필요할 때 (설정 화면 맨 아래).
///
/// [appStatusProvider] 를 쓰지 않는 이유 — 그쪽은 서버에 앱 상태를 물으러 간다.
/// 버전 한 줄을 보여주려고 네트워크를 타면 서버가 느릴 때 설정 화면이 같이 느려진다.
final appVersionProvider = FutureProvider<String>(
  (ref) => AppStatusRepository.currentVersion(),
);

/// 앱이 뜰 때 한 번, 그리고 [appStatusRecheckProvider] 가 올라갈 때마다 다시 묻는다.
/// 화면을 옮길 때마다 묻지는 않는다.
final appStatusProvider = FutureProvider<AppStatusCheck>(
  (ref) async {
    ref.watch(appStatusRecheckProvider);
    // 개발자 도구 앱 상태 흉내 (서버에 묻지 않음)
    final simulated = DevSimulation.simulatedAppStatus();
    if (simulated != null) {
      return (
        status: simulated,
        version: await AppStatusRepository.currentVersion(),
        isServerSwitchReady: false,
      );
    }
    final repo = ref.watch(appStatusRepositoryProvider);
    final results = await Future.wait<Object>([
      repo.fetch(),
      AppStatusRepository.currentVersion(),
    ]);
    final fetched = results[0] as AppStatusFetchResult;
    // 서버 주소 확인을 점검·업데이트 판정보다 먼저 (점검 중인 옛 서버에서도 새 주소로 넘어감)
    final serverAddressSwitch = ref.read(serverAddressSwitchProvider);
    await serverAddressSwitch.recordLaunchOutcome(
      isServerUnreachable: fetched.isServerUnreachable,
    );
    final isServerSwitchReady = await serverAddressSwitch.prepareSwitch(fetched.status);
    return (
      status: fetched.status,
      version: results[1] as String,
      isServerSwitchReady: isServerSwitchReady,
    );
  },
);
