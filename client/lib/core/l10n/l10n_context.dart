import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  /// 화면 문구. `MaterialApp` 에 번역 delegate 가 없으면(일부 위젯 테스트) `ko` 번들로 떨어진다.
  ///
  /// 번역 로드가 실패해도 화면이 죽지 않게 하는 안전망이기도 하다 (스펙 4.1 실패 경로).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('ko'));

  /// 앱이 문구에 쓰는 언어. `Localizations.localeOf` 를 쓰지 않는다 — 번역 delegate 가 없는
  /// 테스트의 `MaterialApp` 은 기본 언어가 `en_US` 라서 `ko` 로 도는 기존 테스트가 달라진다.
  Locale get appLocale => Locale(l10n.localeName);
}
