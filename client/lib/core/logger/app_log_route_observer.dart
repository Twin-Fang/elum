import 'package:flutter/widgets.dart';

import 'app_logger.dart';

/// 화면 이동을 첨부 기록에 남기는 관찰자. GoRouter 의 observers 에 붙인다.
class AppLogRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record('push', route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record('pop', route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _record('replace', newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record('remove', route);

  /// 이름이 없는 라우트(다이얼로그·시트)도 종류는 남긴다. 기록 실패가 이동을 막으면 안 된다.
  void _record(String action, Route<dynamic>? route) {
    if (route == null) return;
    try {
      final name = route.settings.name;
      final label = (name == null || name.isEmpty) ? route.runtimeType.toString() : name;
      AppLogger.screen('이동 $action $label');
    } catch (_) {}
  }
}
