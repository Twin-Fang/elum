import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// 개발자 도구의 언어 강제 값. null 이면 휴대폰 언어를 따른다.
///
/// QA·시연이 휴대폰 언어를 바꾸지 않고 다른 언어 화면을 보게 한다 (스펙 4.1 ④).
/// **메모리에만 둔다**(결정 D7) — 앱을 다시 켜면 휴대폰 언어로 돌아가, 강제가 남은 줄
/// 모르고 지나치는 일이 없다.
class DevLocaleOverrideNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  /// 릴리스 빌드(개발자 도구 꺼짐)에서는 어떤 경로로 불려도 무시한다.
  void set(Locale? locale) {
    state = AppConfig.showDevTools ? locale : null;
  }
}

final devLocaleOverrideProvider =
    NotifierProvider<DevLocaleOverrideNotifier, Locale?>(
      DevLocaleOverrideNotifier.new,
    );
