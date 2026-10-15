import 'package:flutter_test/flutter_test.dart';
import 'package:elum/features/member/data/member_repository.dart';

/// Pro 요금제에서 광고가 꺼지는지. 서버 `entitlements.adsRemoved` 가 기준이다.
void main() {
  test('서버 응답의 adsRemoved 를 읽는다', () {
    final pro = Member.fromJson({
      'entitlements': {'plan': 'PRO', 'adsRemoved': true},
    });
    final free = Member.fromJson({
      'entitlements': {'plan': 'FREE', 'adsRemoved': false},
    });
    expect(pro.adsRemoved, isTrue);
    expect(free.adsRemoved, isFalse);
  });

  test('entitlements 가 없거나 모양이 달라도 광고 표시(false)로 읽는다', () {
    expect(Member.fromJson({}).adsRemoved, isFalse);
    expect(Member.fromJson({'entitlements': 'x'}).adsRemoved, isFalse);
    expect(Member.fromJson({'entitlements': {'adsRemoved': 'true'}}).adsRemoved,
        isFalse);
  });

}
