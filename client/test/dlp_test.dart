import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// DLP는 발표의 보안 와우 포인트다.
/// "실제로 마스킹된다"가 데모 성립 조건이므로 동작을 고정한다.
void main() {
  group('LocalDlp 마스킹', () {
    test('학교명을 탐지해 태그로 바꾼다', () {
      const input = '내일 하늘초등학교에 가야 해';
      expect(LocalDlp.mask(input), contains('<학교명>'));
      expect(LocalDlp.mask(input), isNot(contains('하늘초등학교')));
    });

    test('전화번호를 탐지한다', () {
      expect(LocalDlp.mask('연락처는 010-1234-5678이야'), contains('<전화번호>'));
      expect(LocalDlp.mask('01012345678로 연락줘'), contains('<전화번호>'));
    });

    test('이메일을 탐지한다', () {
      expect(LocalDlp.mask('parent@example.com으로 보내줘'), contains('<이메일>'));
    });

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

  group('Routine 모델', () {
    test('승인 전에는 isConfirmed가 false다', () {
      const pending = Routine(id: '1', status: 'PENDING_REVIEW');
      expect(pending.isConfirmed, isFalse);

      const confirmed = Routine(id: '1', status: 'CONFIRMED');
      expect(confirmed.isConfirmed, isTrue);
    });

    test('마스킹 전후가 다르면 hasMaskedContent가 true다', () {
      const masked = Routine(
        id: '1',
        rawInputText: '하늘초등학교 가기',
        sanitizedInputText: '<학교명> 가기',
      );
      expect(masked.hasMaskedContent, isTrue);

      const same = Routine(
        id: '1',
        rawInputText: '병원 가기',
        sanitizedInputText: '병원 가기',
      );
      expect(same.hasMaskedContent, isFalse);
    });

    test('서버 응답을 파싱한다', () {
      final routine = Routine.fromJson({
        'id': 'r1',
        'title': '비 오는 날 학교 가기',
        'rawInputText': '원문',
        'sanitizedInputText': '<학교명>',
        'status': 'PENDING_REVIEW',
        'steps': [
          {'id': 's1', 'stepOrder': 1, 'description': '옷을 입어요'},
        ],
      });

      expect(routine.id, 'r1');
      expect(routine.steps, hasLength(1));
      expect(routine.steps.first.description, '옷을 입어요');
    });

    test('필드가 없어도 죽지 않는다', () {
      final routine = Routine.fromJson({});
      expect(routine.id, '');
      expect(routine.steps, isEmpty);
    });
  });

  group('RoutineQuestion', () {
    test('서버 required 키를 isRequired로 읽는다', () {
      final q = RoutineQuestion.fromJson({
        'required': true,
        'question': '무엇을 챙길까요?',
        'options': ['우산'],
      });
      expect(q.isRequired, isTrue);
      expect(q.canAsk, isTrue);
    });

    test('질문 문구가 없으면 물어볼 수 없다', () {
      final q = RoutineQuestion.fromJson({'required': true});
      expect(q.canAsk, isFalse);
    });

    test('required가 false면 질문 단계를 건너뛴다', () {
      final q = RoutineQuestion.fromJson({
        'required': false,
        'question': '무시되어야 함',
      });
      expect(q.canAsk, isFalse);
    });
  });
}
