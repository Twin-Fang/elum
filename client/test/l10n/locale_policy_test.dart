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

    test('열린 언어는 ARB 가 있는 지원 언어의 부분집합이다', () {
      final supported = supportedAppLocales.map((l) => l.languageCode).toSet();
      expect(openedAppLocales.every((l) => supported.contains(l.languageCode)), isTrue);
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

    test('번체 중국어는 en 이다', () {
      expect(
        resolve(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')]),
        const Locale('en'),
      );
      expect(resolve(const [Locale('zh', 'TW')]), const Locale('en'));
      expect(resolve(const [Locale('zh', 'HK')]), const Locale('en'));
      expect(resolve(const [Locale('zh', 'MO')]), const Locale('en'));
    });

    test('프랑스어·아랍어 같은 지원 밖 언어는 en 이다', () {
      expect(resolve(const [Locale('fr', 'FR')]), const Locale('en'));
      expect(resolve(const [Locale('ar', 'EG')]), const Locale('en'));
    });

    test('목록이 비었거나 null 이면 en 이다 — 앱이 죽지 않는다', () {
      expect(resolve(null), const Locale('en'));
      expect(resolve(const []), const Locale('en'));
    });
  });

  group('여러 언어를 쓰는 휴대폰', () {
    test('목록의 앞에서부터 열린 첫 언어를 쓴다', () {
      expect(resolve(const [Locale('pt', 'BR'), Locale('ko', 'KR')]), const Locale('ko'));
      expect(resolve(const [Locale('ja', 'JP'), Locale('ko', 'KR')]), const Locale('ko'));
    });

    test('번체 중국어가 1순위여도 다음에 열린 언어가 있으면 그것을 쓴다', () {
      expect(resolve(const [Locale('zh', 'TW'), Locale('ko', 'KR')]), const Locale('ko'));
      // 번체만 있으면 en
      expect(resolve(const [Locale('zh', 'TW')]), const Locale('en'));
    });
  });
}
