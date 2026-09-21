import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../network/dio_client.dart';
import 'app_status.dart';
import 'app_status_recheck.dart';

/// 앱 상태를 서버에 묻는다 (이슈 #279).
///
/// **실패는 조용히 넘긴다.** 이 요청이 안 되면 그냥 평소처럼 진행한다 —
/// 서버 상태를 확인하지 못했다는 이유로 앱을 막으면, 서버가 죽었을 때
/// 아무도 앱을 열 수 없다.
class AppStatusRepository {
  AppStatusRepository(this._dio);

  final Dio _dio;

  Future<AppStatus> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/app/status');
      final data = res.data;
      if (data == null) return AppStatus.unknown;
      return AppStatus.fromJson(data);
    } catch (e) {
      debugPrint('[app-status] 확인하지 못했다 — 그대로 진행한다: $e');
      return AppStatus.unknown;
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

/// 지금 앱 버전만 필요할 때 (설정 화면 맨 아래 — 이슈 #289).
///
/// [appStatusProvider] 를 쓰지 않는 이유 — 그쪽은 서버에 앱 상태를 물으러 간다.
/// 버전 한 줄을 보여주려고 네트워크를 타면 서버가 느릴 때 설정 화면이 같이 느려진다.
final appVersionProvider = FutureProvider<String>(
  (ref) => AppStatusRepository.currentVersion(),
);

/// 앱이 뜰 때 한 번, 그리고 [appStatusRecheckProvider] 가 올라갈 때마다 다시 묻는다.
/// 화면을 옮길 때마다 묻지는 않는다.
final appStatusProvider = FutureProvider<({AppStatus status, String version})>(
  (ref) async {
    ref.watch(appStatusRecheckProvider);
    final repo = ref.watch(appStatusRepositoryProvider);
    final results = await Future.wait([
      repo.fetch(),
      AppStatusRepository.currentVersion(),
    ]);
    return (status: results[0] as AppStatus, version: results[1] as String);
  },
);
