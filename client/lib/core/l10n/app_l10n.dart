import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import 'app_locales.dart';
import 'current_l10n.dart';
import 'l10n_context.dart';
import 'locale_policy.dart';

/// `MaterialApp(.router)` 가 받는 언어 관련 인자 전부 — [AppL10n.routerArgs] 의 결과.
class AppL10nArgs {
  const AppL10nArgs({
    required this.locale,
    required this.supportedLocales,
    required this.localizationsDelegates,
    required this.localeListResolutionCallback,
    required this.onGenerateTitle,
    required this.builder,
  });

  final Locale? locale;
  final Iterable<Locale> supportedLocales;
  final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates;
  final LocaleListResolutionCallback localeListResolutionCallback;
  final GenerateAppTitle onGenerateTitle;
  final TransitionBuilder builder;
}

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

  /// 언어 관련 `MaterialApp` 인자 전부를 한 곳에서 만든다. `app.dart` 와 테스트가 이것 하나만
  /// 쓰므로, 여기서 빠진 배선(`syncAppL10n`·글꼴 테마 등)은 테스트에서 바로 드러난다.
  ///
  /// - [forcedLocale]: 개발자 도구의 강제 언어. [devToolsEnabled](기본: 빌드 설정)가 꺼지면 무시한다.
  /// - [inner]: 언어 배선 안쪽에 둘 앱 고유 래퍼(동기화 트리거·오버레이 등).
  static AppL10nArgs routerArgs({
    required Locale? forcedLocale,
    required TransitionBuilder inner,
    bool? devToolsEnabled,
  }) {
    final enabled = devToolsEnabled ?? AppConfig.showDevTools;
    return AppL10nArgs(
      locale: enabled ? forcedLocale : null,
      supportedLocales: supportedLocales,
      localizationsDelegates: delegates,
      localeListResolutionCallback: resolveLocales,
      // 앱 이름은 운영체제 앱 전환 화면에 보인다 — 언어마다 다를 수 있어 ARB 에서 읽는다
      onGenerateTitle: (context) => context.l10n.appTitle,
      builder: (context, child) {
        // context 가 없는 층(도메인 getter·저장소 대체 문구)이 쓰는 문구를 지금 언어에 맞춘다.
        // builder 의 context 는 Localizations 안쪽이라 여기서만 정해진 언어를 읽을 수 있다.
        syncAppL10n(context);
        return themed(context, inner(context, child));
      },
    );
  }
}
