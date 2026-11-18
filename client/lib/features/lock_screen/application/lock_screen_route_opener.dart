import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../../core/lock_screen/home_widget_bridge.dart';
import '../../../core/lock_screen/lock_screen_bridge.dart';
import '../../../core/lock_screen/lock_screen_routes.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/router/routes.dart';
import '../../../shared/models/action_card.dart';
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
  return _startRouteOpener(
    source: 'lock screen',
    takePendingRoute: bridge.takePendingRoute,
    openedRoutes: bridge.openedRoutes,
    router: router,
    isElumiDevice: isElumiDevice,
    loadTodayRoutines: loadTodayRoutines,
  );
}

/// 홈 화면 위젯에서 누른 경로 > 앱 화면 (잠금화면과 같은 경로 값, #1465)
/// `check:<일과>:<카드>`(마지막 카드 "다 했어요"): 그 카드를 체크하고 일과 카드 화면을 엶 > 앱의 칭찬 흐름
/// `create`(빠른 만들기): 보호자 기기면 일과 만들기 시작
StreamSubscription<String>? startHomeWidgetRouteOpener({
  required HomeWidgetBridge bridge,
  required GoRouter router,
  required bool Function() isElumiDevice,
  required Future<List<Routine>> Function() loadTodayRoutines,
  required bool Function(Routine routine, ActionCard card) markCardChecked,
  required Future<void> Function() startRoutineCreation,
}) {
  if (!bridge.isSupported) return null;
  return _startRouteOpener(
    source: 'widget',
    takePendingRoute: bridge.takePendingRoute,
    openedRoutes: bridge.openedRoutes,
    router: router,
    isElumiDevice: isElumiDevice,
    loadTodayRoutines: loadTodayRoutines,
    markCardChecked: markCardChecked,
    startRoutineCreation: startRoutineCreation,
  );
}

/// 경로 열기 공통: 막 켠 앱의 남은 경로 1회 > 떠 있는 동안 들어오는 경로
StreamSubscription<String> _startRouteOpener({
  required String source,
  required Future<String?> Function() takePendingRoute,
  required Stream<String> openedRoutes,
  required GoRouter router,
  required bool Function() isElumiDevice,
  required Future<List<Routine>> Function() loadTodayRoutines,
  bool Function(Routine routine, ActionCard card)? markCardChecked,
  Future<void> Function()? startRoutineCreation,
}) {
  void open(String route) {
    AppLogger.info('[$source] open route : $route');
    final check = LockScreenRoutes.checkOf(route);
    if (check != null && markCardChecked != null) {
      router.go(Routes.child);
      unawaited(_checkThenPushRoutineDetail(router, check, loadTodayRoutines, markCardChecked));
      return;
    }
    final routineId = LockScreenRoutes.routineIdOf(route);
    if (routineId != null) {
      router.go(Routes.child);
      unawaited(_pushRoutineDetail(router, routineId, loadTodayRoutines));
      return;
    }
    if (route == LockScreenRoutes.create && !isElumiDevice() && startRoutineCreation != null) {
      // 홈의 [새 일과 만들기] 와 같은 길 (크레딧 확인 > 흐름 초기화 > 입력 화면)
      router.go(Routes.guardian);
      _openWhenHomeReady(router, () => unawaited(startRoutineCreation()));
      return;
    }
    if (route == LockScreenRoutes.home || route == LockScreenRoutes.create) {
      router.go(isElumiDevice() ? Routes.child : Routes.guardian);
    }
  }

  unawaited(
    takePendingRoute().then((route) {
      if (route != null) _openWhenHomeReady(router, () => open(route));
    }),
  );
  return openedRoutes.listen(open);
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

/// 위젯 마지막 카드: 그 카드 체크 > 카드 화면 열기 (못 찾으면 이룸이 홈에 머묾)
Future<void> _checkThenPushRoutineDetail(
  GoRouter router,
  ({String routineId, String cardId}) check,
  Future<List<Routine>> Function() loadTodayRoutines,
  bool Function(Routine routine, ActionCard card) markCardChecked,
) async {
  try {
    final routines = await loadTodayRoutines().timeout(_routineLoadTimeout);
    final routine = routines.where((routine) => routine.id == check.routineId).firstOrNull;
    final card = routine?.steps.where((card) => card.id == check.cardId).firstOrNull;
    if (routine == null || card == null) return;
    markCardChecked(routine, card);
    unawaited(router.push(Routes.childRoutineDetail, extra: routine));
  } catch (error) {
    AppLogger.error('widget', 'check route failed : $error');
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
