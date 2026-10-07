import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import 'app_locales.dart';
import 'locale_policy.dart';

/// 지금 앱이 쓰는 언어 — 개발자 강제 → 휴대폰 언어 순서로 판정한다.
///
/// `Accept-Language` 를 요청마다 이 함수로 만든다(OS 언어가 바뀌어도 다음 요청부터 따라간다).
/// 휴대폰 언어는 `PlatformDispatcher.instance` 가 아니라 **바인딩의 것**을 읽는다 — 테스트가
/// `localesTestValue` 로 바꿀 수 있는 쪽이다.
Locale effectiveAppLocale({Locale? devOverride}) {
  // 개발자 도구가 꺼진(릴리스) 빌드에서는 어떤 경로로 값이 들어와도 무시한다
  if (AppConfig.showDevTools && devOverride != null) return devOverride;
  return resolveAppLocale(
    WidgetsBinding.instance.platformDispatcher.locales,
    openedAppLocales,
  );
}
