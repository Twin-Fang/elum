/// 잠금화면 > 앱 이동 경로 (네이티브 LockScreenRoutes.kt 와 같은 값)
/// 값 3종: home(지금 역할의 홈), routine:<일과 id>(이룸이 일과 시작), settings_lock_screen
abstract final class LockScreenRoutes {
  static const String home = 'home';
  static const String settings = 'settings_lock_screen';
  static const String _routinePrefix = 'routine:';

  static String routine(String routineId) => '$_routinePrefix$routineId';

  /// `routine:<id>` 이면 id, 아니면 null
  static String? routineIdOf(String route) => route.startsWith(_routinePrefix)
      ? route.substring(_routinePrefix.length)
      : null;
}
