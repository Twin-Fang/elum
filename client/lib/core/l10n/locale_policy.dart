import 'dart:ui';

/// 번체 중국어 지역 — 간체만 지원하므로 이 지역의 `zh` 는 지원 밖이다.
const _traditionalChineseRegions = {'TW', 'HK', 'MO'};

/// 휴대폰 언어 목록에서 앱이 쓸 언어 하나를 고른다.
///
/// - 목록을 **앞에서부터** 보며 지원하는 첫 언어를 쓴다(OS 의 앱 언어 선택과 같은 순서).
/// - 어느 것도 지원하지 않으면 `en` 이다 (스펙 4.1).
/// - 중국어는 간체(`Hans`, 또는 스크립트 없이 `CN`·`SG`·지역 없음)만 맞는다.
///   번체(`Hant`, `TW`·`HK`·`MO`)는 지원 밖이라 다음 후보로 넘어간다.
///
/// 반환값은 항상 [supported] 의 원소다 — `zh` 는 `zh-Hans` 로 돌려준다.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  final byLanguage = {for (final l in supported) l.languageCode: l};
  for (final p in preferred ?? const <Locale>[]) {
    final hit = byLanguage[p.languageCode];
    if (hit == null) continue;
    if (p.languageCode == 'zh' && _isTraditionalChinese(p)) continue;
    return hit;
  }
  return byLanguage['en'] ?? const Locale('en');
}

bool _isTraditionalChinese(Locale l) {
  if (l.scriptCode == 'Hant') return true;
  if (l.scriptCode == 'Hans') return false;
  return _traditionalChineseRegions.contains(l.countryCode);
}
