import 'dart:ui';

/// 앱이 화면 문구를 지원하는 언어 다섯 (스펙 4.1, 마스터 C4).
///
/// 중국어는 간체(`Hans`)만 지원한다. 번체는 범위 밖이라 [resolveAppLocale] 이 en 으로 돌린다.
const supportedAppLocales = <Locale>[
  Locale('ko'),
  Locale('en'),
  Locale('ja'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  Locale('es'),
];
