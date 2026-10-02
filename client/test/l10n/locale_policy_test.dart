import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/core/l10n/locale_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 휴대폰 언어 → 앱 언어: 5개 안이면 그것, 밖이면 en. 번체 중국어는 밖이다.
void main() {
  const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  Locale resolve(List<Locale>? phone) => resolveAppLocale(phone, supportedAppLocales);

  group('지원하는 언어', () {
    test('한국어·영어·일본어·스페인어는 지역과 무관하게 그 언어다', () {
      expect(resolve(const [Locale('ko', 'KR')]), const Locale('ko'));
      expect(resolve(const [Locale('en', 'US')]), const Locale('en'));
      expect(resolve(const [Locale('en', 'GB')]), const Locale('en'));
      expect(resolve(const [Locale('ja', 'JP')]), const Locale('ja'));
      expect(resolve(const [Locale('es', 'MX')]), const Locale('es'));
      expect(resolve(const [Locale('es', 'ES')]), const Locale('es'));
    });

    test('중국어 간체는 zh-Hans 로 돌려준다 — 스크립트가 있든 없든', () {
      expect(
        resolve(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN')]),
        zhHans,
      );
      expect(resolve(const [Locale('zh', 'CN')]), zhHans);
      expect(resolve(const [Locale('zh', 'SG')]), zhHans);
      expect(resolve(const [Locale('zh')]), zhHans);
    });
  });

  group('지원하지 않는 언어는 en', () {
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
    test('목록의 앞에서부터 지원하는 첫 언어를 쓴다', () {
      expect(resolve(const [Locale('pt', 'BR'), Locale('ko', 'KR')]), const Locale('ko'));
      expect(resolve(const [Locale('ja', 'JP'), Locale('ko', 'KR')]), const Locale('ja'));
    });

    test('번체 중국어가 1순위여도 다음 지원 언어가 있으면 그것을 쓴다 (결정 D4)', () {
      expect(resolve(const [Locale('zh', 'TW'), Locale('es', 'MX')]), const Locale('es'));
      // 번체만 있으면 스펙대로 en
      expect(resolve(const [Locale('zh', 'TW')]), const Locale('en'));
    });
  });
}
