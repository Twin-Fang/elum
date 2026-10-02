import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('지원 언어는 다섯이고 중국어는 간체 표기다', () {
    expect(
      supportedAppLocales.map((l) => l.toLanguageTag()).toList(),
      ['ko', 'en', 'ja', 'zh-Hans', 'es'],
    );
  });

  test('생성된 AppLocalizations 가 지원 언어 다섯을 모두 안다', () {
    expect(
      {for (final l in AppLocalizations.supportedLocales) l.languageCode},
      {for (final l in supportedAppLocales) l.languageCode},
    );
  });
}
