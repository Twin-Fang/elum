
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_log_connectivity.dart';
import 'app_log_lifecycle_observer.dart';
import 'app_logger.dart';

/// 문제 추적용 기록(처리 못 한 오류·생명주기·연결 상태)의 설치 진입점.
///
/// 화면 이동은 라우터가 [AppLogRouteObserver] 를 observers 에 붙여 남긴다.
abstract final class AppDiagnostics {
  static bool _installed = false;

  /// `WidgetsFlutterBinding.ensureInitialized()` 뒤에 한 번 부른다. 두 번째부터는 무시한다.
  static void install() {
    if (_installed) return;
    _installed = true;

    // 기존 핸들러를 보존하며 체인한다 — 기록만 더하고 동작은 바꾸지 않는다.
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      _recordUnhandled('Flutter 프레임워크', details.exception, details.stack);
      if (previousFlutter != null) {
        previousFlutter(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _recordUnhandled('처리되지 않은 예외', error, stack);
      // 기존 핸들러가 없으면 false 로 넘겨 플랫폼 기본 처리(콘솔 출력)를 그대로 둔다.
      return previousPlatform?.call(error, stack) ?? false;
    };

    WidgetsBinding.instance.addObserver(AppLogLifecycleObserver());
    AppLogConnectivity.install();
  }

  /// 오류 종류·메시지·스택 상위 12줄을 남긴다. 기록 실패가 오류 처리를 막지 않게 삼킨다.
  static void _recordUnhandled(String category, Object error, StackTrace? stack) {
    try {
      AppLogger.error(category, '${error.runtimeType}: $error', stack);
    } catch (_) {}
  }
}
