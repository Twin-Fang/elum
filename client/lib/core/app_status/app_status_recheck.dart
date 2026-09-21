import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 상태를 다시 물어야 할 때 올리는 신호 (이슈 #279 QA).
///
/// 전에는 앱이 **시작할 때 한 번만** 상태를 물었다. 점검을 켜기 전에 앱을 연 사람은
/// 다시 켤 때까지 점검 사실을 몰랐고, 서버도 막지 않아 데이터를 계속 바꿨다.
/// 이제 두 가지 경우에 다시 묻는다.
///
/// - 서버가 점검 중이라며 요청을 거절했을 때 ([MaintenanceInterceptor])
/// - 앱이 다시 앞으로 올라왔을 때 (`AppStatusGate`)
class AppStatusRecheck extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final appStatusRecheckProvider =
    NotifierProvider<AppStatusRecheck, int>(AppStatusRecheck.new);

/// 서버가 점검 중이라 막은 응답인지.
///
/// 503 이라고 다 점검은 아니다 — 서버 재기동·게이트웨이 장애도 503을 준다. 그때 점검
/// 화면을 띄우면 거짓말이 되므로 서버가 붙인 코드까지 본다.
bool isMaintenanceRejection(DioException e) {
  final response = e.response;
  if (response?.statusCode != 503) return false;
  final data = response?.data;
  return data is Map && data['errorCode'] == 'MAINTENANCE_MODE';
}

/// 점검 거절을 받으면 앱 상태를 다시 묻게 한다. 오류 자체는 그대로 흘려보낸다 —
/// 요청한 화면은 제 오류 처리를 하고, 그 위를 점검 화면이 덮는다.
class MaintenanceInterceptor extends Interceptor {
  MaintenanceInterceptor({required this.onMaintenance});

  final void Function() onMaintenance;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isMaintenanceRejection(err)) onMaintenance();
    handler.next(err);
  }
}
