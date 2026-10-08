import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'app_logger.dart';

/// 연결 종류가 바뀔 때마다 첨부 기록에 남긴다.
///
/// 플러그인이 없거나 실패해도 앱 시작을 막지 않는다 — 기록은 보조 수단이다.
class AppLogConnectivity {
  AppLogConnectivity._();

  static StreamSubscription<List<ConnectivityResult>>? _sub;

  static void install() {
    if (_sub != null) return;
    try {
      final connectivity = Connectivity();
      // 시작 시점의 연결 상태도 한 줄 남긴다
      connectivity.checkConnectivity().then(_record).catchError((Object _) {});
      _sub = connectivity.onConnectivityChanged.listen(
        _record,
        onError: (Object _) {},
      );
    } catch (_) {}
  }

  static void _record(List<ConnectivityResult> results) {
    final names = results.isEmpty ? 'none' : results.map((r) => r.name).join(',');
    AppLogger.network('연결 상태 $names');
  }
}
