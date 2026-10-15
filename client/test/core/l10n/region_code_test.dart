import 'package:elum/core/l10n/region_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// 지역 코드는 두 글자 대문자만 통과시킨다. 그 밖은 "없음"이라 헤더를 안 보낸다.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(binding.platformDispatcher.clearLocalesTestValue);

  group('normalizeRegionCode', () {

    test('소문자·세 글자·숫자·공백 섞임은 null — 고쳐 쓰지 않는다', () {
      expect(normalizeRegionCode('us'), isNull);
      expect(normalizeRegionCode('Us'), isNull);
      expect(normalizeRegionCode('USA'), isNull);
      expect(normalizeRegionCode('U'), isNull);
      expect(normalizeRegionCode('U1'), isNull);
      expect(normalizeRegionCode(' US'), isNull);
    });
  });

}
