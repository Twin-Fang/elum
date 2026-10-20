import 'package:wakelock_plus/wakelock_plus.dart';

import '../logger/app_logger.dart';

/// 기기 화면 켜 두기: 켜기, 풀기 (#869)
/// 이룸이가 카드를 보고 행동하러 다녀오는 사이 화면이 꺼지지 않게 함. 실패해도 앱은 그대로 동작
class ScreenAwake {
  const ScreenAwake._();

  /// 자동 꺼짐 막기 (화면을 나갈 때 [release] 짝으로 부름)
  static Future<void> keepOn() => _setEnabled(true);

  /// 기기 설정대로 꺼지게 되돌림
  static Future<void> release() => _setEnabled(false);

  static Future<void> _setEnabled(bool isEnabled) async {
    try {
      await WakelockPlus.toggle(enable: isEnabled);
    } catch (e) {
      // 플러그인 미지원·테스트 환경 — 켜 두기만 못 할 뿐 화면은 계속 씀
      AppLogger.error('screen awake toggle', e);
    }
  }
}
