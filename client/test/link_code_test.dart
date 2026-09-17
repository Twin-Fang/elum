import 'package:elum/features/link/domain/link_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// 연결 암호 다루기 (이슈 #205 · 명세 §5-0).
///
/// 서버와 **같은 집합**을 알고 있어야 한다. 더 넓게 받으면 서버가 404를 돌려주고,
/// 좁게 받으면 맞는 암호를 우리가 먼저 막는다.
void main() {
  test('서버와 같은 30자 — 헷갈리는 글자는 없다', () {
    expect(LinkCode.alphabet.length, 30);
    for (final banned in '0O1ILU'.split('')) {
      expect(LinkCode.alphabet, isNot(contains(banned)),
          reason: '$banned 는 불러줄 때 헷갈려 서버가 만들지 않는다');
    }
  });

  group('화면 표시', () {
    test('3-3으로 끊어 보여준다 — 여섯을 붙이면 불러주다 자리를 놓친다', () {
      expect(LinkCode.grouped('A7K3M9'), 'A7K 3M9');
    });

    test('여섯 자가 아니면 손대지 않는다', () {
      expect(LinkCode.grouped('A7K'), 'A7K');
    });
  });

  group('입력 정규화', () {
    test('소문자로 쳐도 된다', () {
      expect(LinkCode.normalize('a7k3m9'), 'A7K3M9');
    });

    test('화면에 보이는 대로 띄어 써도 된다', () {
      expect(LinkCode.normalize('a7k 3m9'), 'A7K3M9');
      expect(LinkCode.normalize('A7K-3M9'), 'A7K3M9');
    });
  });

  group('보내기 전 거르기', () {
    test('맞는 모양', () {
      expect(LinkCode.hasValidShape('A7K3M9'), isTrue);
    });

    test('길이가 다르면 보내지 않는다', () {
      expect(LinkCode.hasValidShape('A7K3M'), isFalse);
      expect(LinkCode.hasValidShape('A7K3M99'), isFalse);
    });

    test('만들 수 없는 글자면 보내지 않는다 — 시도 횟수만 축낸다', () {
      expect(LinkCode.hasValidShape('A0K3M9'), isFalse);
      expect(LinkCode.hasValidShape('AIK3M9'), isFalse);
    });
  });
}
