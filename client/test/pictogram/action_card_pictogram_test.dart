import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
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

  test('E1 없으면(옛 카드) null 이다', () {
    expect(ActionCard.fromJson(json(null)).pictogramId, isNull);
    expect(ActionCard.fromJson({'id': 's1', 'description': 'x', 'pictogramId': null}).pictogramId, isNull);
  });

  test('E2 카탈로그에 없는 값이면 null 이다 — 없는 자산을 그리려다 깨지지 않게', () {
    expect(ActionCard.fromJson(json('no_such_symbol')).pictogramId, isNull);
    expect(ActionCard.fromJson(json('../../etc/passwd')).pictogramId, isNull);
    expect(ActionCard.fromJson(json('')).pictogramId, isNull);
  });

  test('문자열이 아니어도 죽지 않는다', () {
    expect(ActionCard.fromJson(json(123)).pictogramId, isNull);
    expect(ActionCard.fromJson(json(['a'])).pictogramId, isNull);
  });

  test('toJson → fromJson 왕복에서 값이 사라지지 않는다 (캐시)', () {
    final card = ActionCard.fromJson(json('umbrella'));
    expect(ActionCard.fromJson(card.toJson()).pictogramId, 'umbrella');
    expect(card.toJson()['pictogramId'], 'umbrella');
  });

  test('copyWith 로 제목·설명·그림 경로를 바꿔도 값이 남는다', () {
    final card = ActionCard.fromJson(json('umbrella'));
    expect(card.copyWith(title: '바꿈').pictogramId, 'umbrella');
    expect(card.copyWith(imagePath: 'k/x.jpg').pictogramId, 'umbrella');
    expect(card.copyWith(description: '바꿈').pictogramId, 'umbrella');
  });

  test('일과 응답 안의 카드에서도 읽힌다', () {
    final routine = Routine.fromJson({
      'id': 'r1',
      'status': 'PENDING_REVIEW',
      'steps': [json('brush_teeth_,_to'), json(null)],
    });
    expect(routine.steps.map((s) => s.pictogramId), ['brush_teeth_,_to', null]);
  });
}
