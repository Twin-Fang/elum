import 'package:elum/shared/models/support_goal.dart';
import 'package:flutter_test/flutter_test.dart';


/// 온보딩 문구를 ARB 로 옮겨도 API·`ko` 문구가 같고, 서버로 가는 값(apiValue)은 그대로다.
void main() {

  group('enum — 라벨은 ARB, 서버 값은 그대로', () {
    test('도움 목표 — 서버로 가는 supportGoals 값', () {
      expect(SupportGoal.values.map((g) => g.apiValue), [
        'STEP_BY_STEP',
        'PREPARE_ITEMS',
        'PREPARE_NEW',
        'INDEPENDENT',
      ]);
      expect(SupportGoal.fromApiValue('INDEPENDENT'), SupportGoal.independent);
      expect(SupportGoal.fromApiValue('혼자 끝까지 해내는 경험을 만들어요'), isNull);
    });

  });

}
