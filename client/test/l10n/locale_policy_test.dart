import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/core/l10n/locale_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 휴대폰 언어 → 앱 언어: 열린 언어(ko·en)면 그것, 밖이면 en. ARB 가 있어도 열지 않은 언어는 밖이다.
void main() {
  Locale resolve(List<Locale>? phone) => resolveAppLocale(phone, openedAppLocales);

  group('열린 언어', () {
    test('한국어·영어는 지역과 무관하게 그 언어다', () {
      expect(resolve(const [Locale('ko', 'KR')]), const Locale('ko'));
      expect(resolve(const [Locale('en', 'US')]), const Locale('en'));
      expect(resolve(const [Locale('en', 'GB')]), const Locale('en'));
    });

  });

  group('열리지 않은 언어는 en', () {
    test('ARB 만 있고 열지 않은 일본어·스페인어·중국어(간체)는 en 이다', () {
      expect(resolve(const [Locale('ja', 'JP')]), const Locale('en'));
      expect(resolve(const [Locale('es', 'MX')]), const Locale('en'));
      expect(resolve(const [Locale('es', 'ES')]), const Locale('en'));
      expect(resolve(const [Locale('zh', 'CN')]), const Locale('en'));
      expect(resolve(const [Locale('zh')]), const Locale('en'));
    });

    test('목록이 비었거나 null 이면 en 이다 — 앱이 죽지 않는다', () {
      expect(resolve(null), const Locale('en'));
      expect(resolve(const []), const Locale('en'));
    });
  });

}
