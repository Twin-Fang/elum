import 'package:flutter/widgets.dart';

import 'app_logger.dart';

/// 앱 생명주기 변화를 첨부 기록에 남긴다.
class AppLogLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final label = switch (state) {
      AppLifecycleState.resumed => 'resumed',
      AppLifecycleState.paused => 'paused',
      AppLifecycleState.inactive => 'inactive',
      AppLifecycleState.detached => 'detached',
      AppLifecycleState.hidden => 'hidden',
    };
    AppLogger.lifecycle(label);
  }
}
