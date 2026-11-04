import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/server_address_policy.dart';
import '../logger/app_logger.dart';

/// 서버가 지정한 API 주소 저장: 주소, 연결 실패한 연속 실행 수 (#831)
/// 앱 저장값([LocalStorage])과 키를 나눠 둔다 (로그아웃·회원삭제의 clearAll 이 지우지 않음 — 같은 DB·같은 JWT 키라 계정과 무관)
class AssignedServerAddressStore {
  AssignedServerAddressStore(this._preferences);

  final SharedPreferences _preferences;

  // 확인을 통과해 저장한 서버 지정 주소 (https://{허용 도메인})
  static const _apiBaseUrlKey = 'server.assignedApiBaseUrl';
  // 저장 주소로 시작해 앱 상태 조회가 연결 오류로 끝난 연속 실행 수
  static const _failedLaunchCountKey = 'server.assignedApiBaseUrlFailedLaunchCount';

  static Future<AssignedServerAddressStore> open() async =>
      AssignedServerAddressStore(await SharedPreferences.getInstance());

  /// 시작 때 한 번 (첫 Dio 생성 전): 저장 주소 > 허용 목록 확인 > [AppConfig] 적용. 못 읽으면 기본 주소
  static Future<void> applySavedApiBaseUrl() async {
    try {
      final store = await open();
      final savedApiBaseUrl = store.savedApiBaseUrl;
      if (savedApiBaseUrl == null) return;
      // 허용 목록이 줄어든 새 버전이면 옛 저장값을 버림
      if (ServerAddressPolicy.toAllowedApiBaseUrl(savedApiBaseUrl) == null) {
        AppLogger.info('[server address] saved address dropped : not allowed host');
        await store.clear();
        return;
      }
      AppConfig.applyAssignedApiBaseUrl(savedApiBaseUrl);
      AppLogger.info('[server address] started on server assigned : $savedApiBaseUrl');
    } catch (error, stackTrace) {
      AppLogger.error('server address', error, stackTrace, {'step': 'applySaved'});
    }
  }

  String? get savedApiBaseUrl {
    final saved = _preferences.getString(_apiBaseUrlKey);
    return saved == null || saved.isEmpty ? null : saved;
  }

  int get failedLaunchCount => _preferences.getInt(_failedLaunchCountKey) ?? 0;

  /// 주소 저장 (실패 횟수 0부터)
  Future<void> save(String apiBaseUrl) async {
    await _preferences.setString(_apiBaseUrlKey, apiBaseUrl);
    await _preferences.remove(_failedLaunchCountKey);
  }

  /// 저장 주소·실패 횟수 지움 (다음 실행부터 기본 주소)
  Future<void> clear() async {
    await _preferences.remove(_apiBaseUrlKey);
    await _preferences.remove(_failedLaunchCountKey);
  }

  /// 연결 실패한 실행 1회 더함 > 더한 뒤 횟수
  Future<int> addFailedLaunch() async {
    final count = failedLaunchCount + 1;
    await _preferences.setInt(_failedLaunchCountKey, count);
    return count;
  }

  Future<void> resetFailedLaunchCount() async {
    if (failedLaunchCount == 0) return;
    await _preferences.remove(_failedLaunchCountKey);
  }
}
