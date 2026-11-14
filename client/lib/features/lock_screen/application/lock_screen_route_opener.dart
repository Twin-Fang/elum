import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../../core/lock_screen/lock_screen_bridge.dart';
import '../../../core/lock_screen/lock_screen_routes.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/router/routes.dart';
import '../../../shared/models/routine.dart';

/// 잠금화면·알림에서 연 경로 > 앱 화면 (앱 시작 때 1회 + 떠 있는 동안 계속)
/// home: 지금 역할의 홈 · `routine:{id}`: 이룸이 홈 > 그 일과 카드 (못 찾으면 홈) · 그 밖: 무시
StreamSubscription<String>? startLockScreenRouteOpener({
  required LockScreenBridge bridge,
  required GoRouter router,
  required bool Function() isElumiDevice,
  required Future<List<Routine>> Function() loadTodayRoutines,
}) {
  if (!bridge.isLockScreenSupported) return null;
  void open(String route) {
    AppLogger.info('[lock screen] open route : $route');
    final routineId = LockScreenRoutes.routineIdOf(route);
    if (routineId != null) {
      router.go(Routes.child);
      unawaited(_pushRoutineDetail(router, routineId, loadTodayRoutines));
      return;
    }
    if (route == LockScreenRoutes.home) {
      router.go(isElumiDevice() ? Routes.child : Routes.guardian);
    }
  }

  unawaited(
    bridge.takePendingRoute().then((route) {
      if (route != null) _openWhenHomeReady(router, () => open(route));
    }),
  );
  return bridge.openedRoutes.listen(open);
}

/// 오늘 일과에서 찾아 카드 화면 열기 (못 받거나 없으면 이룸이 홈에 머묾)
Future<void> _pushRoutineDetail(
  GoRouter router,
  String routineId,
  Future<List<Routine>> Function() loadTodayRoutines,
) async {
  try {
    final routines = await loadTodayRoutines().timeout(_routineLoadTimeout);
    final routine = routines
        .where((routine) => routine.id == routineId)
        .firstOrNull;
    if (routine == null) return;
    unawaited(router.push(Routes.childRoutineDetail, extra: routine));
  } catch (error) {
    AppLogger.error('lock screen', 'routine open failed : $error');
  }
}

// 오늘 일과를 기다리는 최대 시간 (넘으면 이룸이 홈에 머묾)
const _routineLoadTimeout = Duration(seconds: 8);

/// 앱을 막 켠 경우: 시작 화면이 홈(보호자·이룸이)으로 옮긴 뒤에 열기 (시작 화면의 이동에 덮이지 않게)
void _openWhenHomeReady(GoRouter router, void Function() open) {
  bool isOnHomeArea() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    return path.startsWith(Routes.child) || path.startsWith(Routes.guardian);
  }

  if (isOnHomeArea()) {
    open();
    return;
  }
  late final void Function() waitForHome;
  waitForHome = () {
    if (!isOnHomeArea()) return;
    router.routerDelegate.removeListener(waitForHome);
    open();
  };
  router.routerDelegate.addListener(waitForHome);
}
