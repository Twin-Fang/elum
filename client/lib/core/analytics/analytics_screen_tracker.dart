import 'package:go_router/go_router.dart';

import 'app_analytics.dart';

/// 화면 추적 한 곳 (#650): 라우터 위치가 바뀔 때마다 맨 위 화면의 경로 패턴 > screen_view
///
/// NavigatorObserver 대신 라우터 위치를 보는 이유: 보호자 하단 바 칸 전환(StatefulShellRoute)은
/// 루트 네비게이터에 push 가 없어 관찰자가 못 봄. 다이얼로그·시트는 화면이 아니라 세지 않음
/// 경로 패턴(`/guardian/talk/posts/:postId`)만 보냄: 실제 id·쿼리(초대 코드 등)는 빠짐
class AnalyticsScreenTracker {
  AnalyticsScreenTracker._(this._router);

  final GoRouter _router;

  // 직전에 보낸 경로 패턴 (같은 화면에서 쿼리만 바뀐 알림은 다시 세지 않음)
  String? _lastRoutePattern;

  /// 라우터에 붙인다. 라우터마다 한 번 (createRouter)
  static void attachTo(GoRouter router) {
    final tracker = AnalyticsScreenTracker._(router);
    router.routerDelegate.addListener(tracker._onRouteChanged);
  }

  // 추적 실패가 화면 이동을 막지 않음 (빈 설정·오류 화면이면 건너뜀)
  void _onRouteChanged() {
    if (!AppAnalytics.isEnabled) return;
    try {
      if (_router.routerDelegate.currentConfiguration.isEmpty) return;
      final routePattern = _router.state.fullPath;
      if (routePattern == null || routePattern.isEmpty) return;
      if (routePattern == _lastRoutePattern) return;
      _lastRoutePattern = routePattern;
      AppAnalytics.logScreenView(routePattern);
    } catch (_) {}
  }
}
