import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `app.dart` 의 언어 배선 계약.
///
/// `ElumApp` 은 위젯 테스트로 띄우기 어렵다(라우터·네트워크·플랫폼 채널). 그래서 소스를 읽어
/// 두 가지를 지킨다 — (a) 언어 인자를 `AppL10n.routerArgs` 한 곳에서 받고, (b) `MaterialApp.router`
/// 에 번역·언어 인자를 `app.dart` 가 따로 조립하지 않는다. 누가 인자를 직접 꽂으면 `syncAppL10n`·
/// 글꼴 테마·개발자 도구 게이트가 조용히 빠진다.
void main() {
  final src = File('lib/app.dart').readAsStringSync();

  test('app.dart 는 AppL10n.routerArgs 로 언어 인자를 받는다', () {
    expect(src, contains('AppL10n.routerArgs('));
    expect(src, contains('forcedLocale: ref.watch(devLocaleOverrideProvider)'));
  });

  test('MaterialApp.router 에는 그 결과만 넘기고 직접 조립하지 않는다', () {
    expect(src, contains('localizationsDelegates: l10n.localizationsDelegates'));
    expect(src, contains('builder: l10n.builder'));
    expect(src, contains('locale: l10n.locale'));
    expect(src, contains('onGenerateTitle: l10n.onGenerateTitle'));
    expect(src, contains('localeListResolutionCallback: l10n.localeListResolutionCallback'));
    expect(src, contains('supportedLocales: l10n.supportedLocales'));
    for (final direct in [
      'AppLocalizations.localizationsDelegates',
      'AppL10n.delegates',
      'syncAppL10n(',
      'AppL10n.themed(',
      'AppConfig.showDevTools',
    ]) {
      expect(src, isNot(contains(direct)), reason: 'app.dart 가 $direct 를 직접 쓴다 — routerArgs 안으로');
    }
  });
}
