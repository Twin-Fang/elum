import 'package:elum/shared/models/routine.dart';
import 'package:elum/shared/models/routine_example_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutineExampleCategory', () {
    test('서버 코드와 왕복한다 — 어긋나면 예시 생성 요청이 400 으로 거절된다', () {
      for (final category in RoutineExampleCategory.values) {
        expect(
          RoutineExampleCategory.fromApiValue(category.apiValue),
          category,
        );
      }
      expect(RoutineExampleCategory.values.map((c) => c.apiValue), [
        'MORNING_EVENING',
        'SCHOOL_STUDY',
        'HOUSE_SELF',
        'OUTSIDE',
      ]);
    });

    test('모르는 값·null 은 null — 저장값이 깨져도 앱이 죽지 않는다', () {
      expect(RoutineExampleCategory.fromApiValue('FOO'), isNull);
      expect(RoutineExampleCategory.fromApiValue(null), isNull);
    });
  });

  group('Routine.isExample', () {
    test('서버가 true 를 주면 예시다', () {
      expect(Routine.fromJson({'isExample': true}).isExample, isTrue);
    });

    test('없거나 bool 이 아니면 예시가 아니다 — 옛 응답에 배지가 붙지 않게', () {
      expect(Routine.fromJson(const {}).isExample, isFalse);
      expect(Routine.fromJson({'isExample': 'yes'}).isExample, isFalse);
    });

    test('캐시 왕복 후에도 유지된다 — 오프라인 홈에서 배지가 사라지지 않게', () {
      final routine = Routine.fromJson({'id': 'r1', 'isExample': true});
      expect(Routine.fromJson(routine.toJson()).isExample, isTrue);
    });
  });
}
