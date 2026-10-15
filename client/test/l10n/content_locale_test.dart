import 'package:elum/core/l10n/content_locale.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  group('normalizeContentLanguage', () {
    test('다섯 코드만 통과하고 나머지는 ko', () {
      for (final code in ['ko', 'en', 'ja', 'zh', 'es']) {
        expect(normalizeContentLanguage(code), code);
      }
      expect(normalizeContentLanguage('fr'), 'ko');
      expect(normalizeContentLanguage(''), 'ko');
      expect(normalizeContentLanguage(null), 'ko');
      expect(normalizeContentLanguage(3), 'ko');
    });
  });


}
