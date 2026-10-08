import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logger/app_logger.dart';
import 'app_destination.dart';
import 'routes.dart';

/// 뒤로가기·돌아가기는 이것을 쓴다. 인자 없는 `context.pop()` 은 `test/no_raw_pop_test.dart` 가 막는다.
///
/// `go` 로 열린 화면은 아래에 돌아갈 화면이 없고, 그때 go_router 의 pop 은 예외를 던져 버튼이 먹통이 된다.
extension PopOrHome on BuildContext {
  /// 돌아갈 화면이 있으면 pop, 없으면 지금 상태의 홈([homeFor])으로 간다.
  void popOrHome() {
    final router = GoRouter.of(this);
    if (router.canPop()) {
      router.pop();
      return;
    }

    String home;
    try {
      home = homeFor(ProviderScope.containerOf(this, listen: false));
    } catch (e) {
      // 상태를 못 읽으면 어떤 상태로도 열리는 로그인 화면으로
      AppLogger.error('뒤로가기 홈 판단', e);
      home = Routes.login;
    }

    final matches = router.routerDelegate.currentConfiguration.matches;
    final here = matches.isEmpty ? null : matches.last.matchedLocation;
    if (here == home) return;
    debugPrint('[화면] 돌아갈 곳이 없어 홈으로: $here → $home');
    router.go(home);
  }
}
