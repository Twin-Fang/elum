import 'package:flutter/widgets.dart';

/// 서버가 받는 지역 코드 형식: ISO 3166-1 alpha-2 대문자 두 글자.
final _regionPattern = RegExp(r'^[A-Z]{2}$');

/// 형식이 맞는 지역 코드만 돌려주고 나머지는 `null`.
///
/// 소문자·세 글자를 고쳐 쓰지 않는다 — 잘못 짐작한 국가로 공지가 나가느니 "미상"으로 두는 쪽이 안전하다.
String? normalizeRegionCode(String? raw) =>
    raw != null && _regionPattern.hasMatch(raw) ? raw : null;

/// 휴대폰(시스템 로케일)의 지역 코드. 없거나 비정상이면 `null`.
///
/// 개발자 언어 강제(`devLocaleOverrideProvider`)는 **언어만** 바꾸는 시험 장치라 지역에는 쓰지 않는다.
/// 강제 값을 섞으면 언어를 시험하다가 공지 대상 국가까지 바뀐다.
/// 테스트가 `localesTestValue` 로 바꿀 수 있도록 `PlatformDispatcher.instance` 가 아니라 바인딩의 것을 읽는다
/// (`locale_policy.dart` 와 같은 이유).
String? systemRegionCode() {
  try {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    if (locales.isEmpty) return null;
    return normalizeRegionCode(locales.first.countryCode);
  } catch (e) {
    // 지역을 못 읽어도 요청은 나가야 한다 — 헤더만 빠진다. 원인은 개발자가 볼 수 있게 남긴다.
    debugPrint('[지역] 시스템 지역 코드를 읽지 못해 헤더를 생략해요: $e');
    return null;
  }
}
