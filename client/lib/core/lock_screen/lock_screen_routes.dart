/// 잠금화면 > 앱 이동 경로 (네이티브 LockScreenRoutes.kt 와 같은 값)
/// 값 4종: home(지금 역할의 홈), routine:<일과 id>(이룸이 일과 시작), check:<일과 id>:<카드 id>(위젯 마지막 카드 체크 > 칭찬), settings_lock_screen
abstract final class LockScreenRoutes {
  static const String home = 'home';
  static const String settings = 'settings_lock_screen';
  static const String _routinePrefix = 'routine:';

  static String routine(String routineId) => '$_routinePrefix$routineId';
  static const String _checkPrefix = 'check:';

  /// 위젯 마지막 카드 "다 했어요" > 앱이 체크하고 그 일과 카드 화면을 엶 (#1465 2단계)
  static String check(String routineId, String cardId) => '$_checkPrefix$routineId:$cardId';

  /// `check:<일과 id>:<카드 id>` 이면 두 id, 아니면 null (카드 id 에 ':' 가 없다는 전제: 서버 UUID)
  static ({String routineId, String cardId})? checkOf(String route) {
    if (!route.startsWith(_checkPrefix)) return null;
    final rest = route.substring(_checkPrefix.length);
    final separator = rest.indexOf(':');
    if (separator <= 0 || separator == rest.length - 1) return null;
    return (routineId: rest.substring(0, separator), cardId: rest.substring(separator + 1));
  }

  /// `routine:<id>` 이면 id, 아니면 null
  static String? routineIdOf(String route) => route.startsWith(_routinePrefix)
      ? route.substring(_routinePrefix.length)
      : null;
}
