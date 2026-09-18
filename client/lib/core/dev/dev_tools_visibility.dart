import 'package:flutter/foundation.dart';

/// 디버깅 버튼을 이번 실행 동안만 숨긴다 (이슈 #219).
///
/// 버튼이 화면 오른쪽 아래를 가려 그 아래 있는 것을 못 볼 때가 있다.
/// 숨길 수 있어야 하되, **숨긴 채로 잊히면 안 된다.**
///
/// ## 저장소에 쓰지 않는다 — 그게 핵심이다
///
/// `SharedPreferences`에 두면 앱을 다시 켜도 숨겨진 채 남아, 다음 사람이
/// "개발자 도구가 없다"고 헤맨다. **메모리에만** 두면 프로세스가 죽을 때 초기화된다.
///
/// 그래서 되살리는 방법이 하나로 정해진다 —
/// **작업관리자에서 앱을 완전히 종료했다가 다시 켠다.**
/// (홈으로 나가기만 하면 프로세스가 살아 있어 계속 숨겨져 있다.)
///
/// 정식 출시 전 제거 대상 (이슈 #13).
abstract final class DevToolsVisibility {
  /// 숨김 여부. 화면이 이 값을 듣고 바로 반응한다.
  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);

  static void hide() => hidden.value = true;

  @visibleForTesting
  static void reset() => hidden.value = false;
}
