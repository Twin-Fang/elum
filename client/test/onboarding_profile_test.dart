import 'package:elum/shared/models/character.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  group('SupportGoal 서버 계약', () {
    // 서버 enum(SupportGoal.java)과 값이 어긋나면 카드 생성이 조용히 실패한다.
    test('apiValue가 서버 enum name과 일치한다', () {
      expect(SupportGoal.stepByStep.apiValue, 'STEP_BY_STEP');
      expect(SupportGoal.prepareItems.apiValue, 'PREPARE_ITEMS');
      expect(SupportGoal.prepareNew.apiValue, 'PREPARE_NEW');
      expect(SupportGoal.independent.apiValue, 'INDEPENDENT');
    });

    test('모르는 값이 와도 예외 대신 null을 준다', () {
      expect(SupportGoal.fromApiValue('UNKNOWN_GOAL'), isNull);
      expect(SupportGoal.fromApiValue('PREPARE_ITEMS'), SupportGoal.prepareItems);
    });
  });

  group('CardCharacter 서버 계약', () {
    // 서버 CharacterType(LULU/POPO)과 어긋나면 PATCH /api/member/character가
    // 역직렬화에 실패해 캐릭터 저장이 조용히 실패한다 (이슈 #89).
    test('apiValue가 서버 CharacterType enum name과 일치한다', () {
      expect(CardCharacter.cat.apiValue, 'LULU');
      expect(CardCharacter.fox.apiValue, 'POPO');
    });

    // 순서가 화면 배치다 — 고양이가 왼쪽, 여우가 오른쪽. 뒤집히면 화면이 조용히 바뀐다.
  });
}
