import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/features/guardian/domain/local_dlp.dart';

/// DLP는 발표의 보안 와우 포인트다.
/// "실제로 마스킹된다"가 데모 성립 조건이므로 동작을 고정한다.
void main() {
  group('LocalDlp 마스킹', () {



    test('민감정보가 없으면 원문을 그대로 둔다', () {
      const input = '내일 비가 많이 올 예정이야.';
      expect(LocalDlp.mask(input), input);
      expect(LocalDlp.detectedTypes(input), isEmpty);
    });

    test('탐지 결과에 원문 값이 들어가지 않는다', () {
      // 원칙 5번 — 탐지 유형·건수만 남기고 원문은 남기지 않는다
      const input = '하늘초등학교 010-1234-5678';
      final types = LocalDlp.detectedTypes(input);

      expect(types, containsAll(['학교명', '전화번호']));
      for (final type in types) {
        expect(type, isNot(contains('하늘')));
        expect(type, isNot(contains('010')));
      }
    });
  });


  group('RoutineQuestion', () {

    test('질문 문구가 없으면 물어볼 수 없다', () {
      final q = RoutineQuestion.fromJson({'required': true});
      expect(q.canAsk, isFalse);
    });

  });
}
