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

/// 지금 실제로 여는 언어. 휴대폰 언어 판정은 이 목록에서만 고른다.
///
/// 언어를 더 열 때는 그 언어 ARB 번역을 채운 뒤 여기에 한 줄 더한다.
/// [supportedAppLocales] 의 부분집합이다 — ARB 가 있어야 열 수 있다.
const openedAppLocales = <Locale>[
  Locale('ko'),
  Locale('en'),
];
