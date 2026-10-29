import 'package:shared_preferences/shared_preferences.dart';

import '../logger/app_logger.dart';
import 'app_config.dart';

/// 개발자 도구 수집 스위치 공통: 켤 수 있는 빌드 판정, 저장값 읽기·저장 (크래시 #659, 분석 #650)
/// 운영 빌드(개발자 도구 없음)는 저장값과 무관하게 항상 꺼짐
class DeveloperCollectionOptIn {
  const DeveloperCollectionOptIn({
    required this.storageKey,
    required this.logCategory,
  });

  /// SharedPreferences 키 (기본 꺼짐)
  /// `dev.` 접두사라 로그아웃·회원삭제(LocalStorage.clearAll)가 지우지 않음
  final String storageKey;

  /// 실패 로그 분류: `crash report`, `analytics`
  final String logCategory;

  /// 수집을 켤 수 있는 빌드인가 (개발자 도구 빌드만, 운영 빌드는 false)
  static bool get canEnable => AppConfig.showDevTools;

  /// 저장한 스위치 값. 운영 빌드·읽기 실패는 false
  Future<bool> readIsOptedIn() async {
    if (!canEnable) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(storageKey) ?? false;
    } catch (error, stack) {
      AppLogger.error(logCategory, error, stack, {'step': 'readOptIn'});
      return false;
    }
  }

  /// 스위치 값 저장 (다음 실행에도 유지). 실패는 로그만, 이번 실행 반영은 부르는 쪽이 함
  Future<void> saveIsOptedIn(bool isOptedIn) async {
    if (!canEnable) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(storageKey, isOptedIn);
    } catch (error, stack) {
      AppLogger.error(logCategory, error, stack, {'step': 'saveOptIn'});
    }
  }
}
