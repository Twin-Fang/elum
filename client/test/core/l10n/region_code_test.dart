import 'package:elum/core/l10n/region_code.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 지역 코드는 두 글자 대문자만 통과시킨다 (마스터 C1-2). 그 밖은 "없음"이라 헤더를 안 보낸다.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(binding.platformDispatcher.clearLocalesTestValue);

  group('normalizeRegionCode', () {
    test('두 글자 대문자는 그대로', () {
      expect(normalizeRegionCode('US'), 'US');
      expect(normalizeRegionCode('KR'), 'KR');
    });

    test('null·빈 값은 null', () {
      expect(normalizeRegionCode(null), isNull);
      expect(normalizeRegionCode(''), isNull);
    });

    test('소문자·세 글자·숫자·공백 섞임은 null — 고쳐 쓰지 않는다', () {
      expect(normalizeRegionCode('us'), isNull);
      expect(normalizeRegionCode('Us'), isNull);
      expect(normalizeRegionCode('USA'), isNull);
      expect(normalizeRegionCode('U'), isNull);
      expect(normalizeRegionCode('U1'), isNull);
      expect(normalizeRegionCode(' US'), isNull);
    });
  });

  group('systemRegionCode — 시스템 로케일의 countryCode', () {
    test('en_US → US, ko_KR → KR', () {
      binding.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      expect(systemRegionCode(), 'US');
      binding.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')];
      expect(systemRegionCode(), 'KR');
    });

    test('지역이 없는 로케일(ja)은 null', () {
      binding.platformDispatcher.localesTestValue = const [Locale('ja')];
      expect(systemRegionCode(), isNull);
    });

    test('로케일 목록이 비어도 죽지 않고 null', () {
      binding.platformDispatcher.localesTestValue = const <Locale>[];
      expect(systemRegionCode(), isNull);
    });

    test('첫 로케일의 지역을 쓴다 — 두 번째 이후 언어의 지역이 아니다', () {
      binding.platformDispatcher.localesTestValue = const [
        Locale('es'),
        Locale('en', 'US'),
      ];
      expect(systemRegionCode(), isNull);
    });
  });
}
