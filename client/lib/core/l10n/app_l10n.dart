import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_locales.dart';
import 'l10n_context.dart';
import 'locale_policy.dart';

/// `MaterialApp.router` 에 꽂는 언어 설정 묶음.
///
/// `app.dart` 와 테스트가 **같은 값**을 쓰게 한다 — 앱 전체를 띄우지 않고도 휴대폰 언어 → 앱 언어
/// 판정을 확인할 수 있다.
abstract final class AppL10n {
  /// 번역 + Material·Widgets·Cupertino 기본 문구(날짜 선택기·복사 메뉴 등)
  static const delegates = AppLocalizations.localizationsDelegates;

  static const supportedLocales = supportedAppLocales;

  /// 휴대폰 언어 목록 → 앱 언어. 5개 밖이면 en (스펙 4.1).
  static Locale? resolveLocales(
    List<Locale>? locales,
    Iterable<Locale> supported,
  ) => resolveAppLocale(locales, supported);

  /// 언어별 테마 캐시 — `builder` 는 매 빌드 불리는데 `ColorScheme.fromSeed` 는 비싸다.
  static final _themes = <String, ThemeData>{};

  /// 앱 언어에 맞는 글꼴 테마를 입힌다. **`ko` 는 트리를 그대로 둔다** — 위젯 하나 늘지 않는다.
  ///
  /// `MaterialApp.theme` 은 언어가 정해지기 전에 고정돼 대체 글꼴을 모른다. `builder` 는
  /// `Localizations` 안쪽이라 여기서 정해진 언어를 읽을 수 있다.
  static Widget themed(BuildContext context, Widget child) {
    final locale = context.appLocale;
    if (locale.languageCode == 'ko') return child;
    final theme = _themes.putIfAbsent(
      locale.languageCode,
      () => AppTheme.lightFor(locale),
    );
    return Theme(data: theme, child: child);
  }
}
