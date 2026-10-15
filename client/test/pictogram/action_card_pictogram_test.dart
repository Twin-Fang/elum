import 'package:elum/shared/models/action_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버가 카드마다 주는 `pictogramId` 를 읽는다 (#469, 서버 #247).
void main() {
  Map<String, dynamic> json([Object? pictogramId = 'get_dressed_,_to']) => {
    'id': 's1',
    'description': '옷을 입어요',
    'stepOrder': 1,
    'pictogramId': ?pictogramId,
  };

  test('서버 JSON 키는 pictogramId 다', () {
    expect(ActionCard.fromJson(json()).pictogramId, 'get_dressed_,_to');
  });

  test('E2 카탈로그에 없는 값이면 null 이다 — 없는 자산을 그리려다 깨지지 않게', () {
    expect(ActionCard.fromJson(json('no_such_symbol')).pictogramId, isNull);
    expect(ActionCard.fromJson(json('../../etc/passwd')).pictogramId, isNull);
    expect(ActionCard.fromJson(json('')).pictogramId, isNull);
  });

  test('toJson → fromJson 왕복에서 값이 사라지지 않는다 (캐시)', () {
    final card = ActionCard.fromJson(json('umbrella'));
    expect(ActionCard.fromJson(card.toJson()).pictogramId, 'umbrella');
    expect(card.toJson()['pictogramId'], 'umbrella');
  });

}
