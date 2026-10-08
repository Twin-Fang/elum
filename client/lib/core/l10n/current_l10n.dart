import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

AppLocalizations _current = lookupAppLocalizations(const Locale('ko'));

/// `context` 가 없는 층(도메인 getter·저장소의 대체 문구·`AppFailure.hint`)이 쓰는 문구 통로.
///
/// 앱이 마지막으로 정한 언어의 문구다. `MaterialApp.builder` 가 매 빌드마다 맞춘다
/// ([syncAppL10n]). 위젯 코드는 이것을 쓰지 말고 `context.l10n` 을 쓴다 — `context.l10n`
/// 만 언어가 바뀔 때 위젯을 다시 그리게 한다.
///
/// **이 값을 읽는 getter 는 `context.l10n` 을 읽는 위젯의 build 안에서만 부른다.** 그래야
/// 언어가 바뀔 때 같이 다시 그려져 이전 언어 문구가 남지 않는다.
AppLocalizations get appL10n => _current;

/// 현재 위젯 트리의 번역을 전역 통로에 맞춘다. 번역 delegate 가 없으면(일부 테스트) 건드리지 않는다.
void syncAppL10n(BuildContext context) {
  final found = Localizations.of<AppLocalizations>(context, AppLocalizations);
  if (found != null) _current = found;
}

/// 테스트가 통로를 직접 정하거나 `ko` 로 되돌린다.
@visibleForTesting
void setAppL10nForTest([AppLocalizations? value]) {
  _current = value ?? lookupAppLocalizations(const Locale('ko'));
}
