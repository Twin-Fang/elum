import 'package:elum/features/child/domain/reward_character.dart';
import 'package:elum/shared/utils/korean_particle.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이름 뒤 조사 (이슈 #196).
///
/// 조사를 `'$name가'` 로 박아 두었더니 받침 있는 이름에서 **`민준가 할 일`** 이 나왔다.
/// 이름은 보호자가 직접 적으므로 어느 쪽도 가정할 수 없다.
void main() {
  group('받침에 따라 조사가 갈린다', () {
    test('받침이 있으면 이 / 을 / 은 / 과', () {
      expect('민준'.subjectParticle, '이'); // 준 → 받침 ㄴ
      expect('서연'.objectParticle, '을');
      expect('지훈'.topicParticle, '은');
      expect('하늘'.withParticle, '과'); // 늘 → 받침 ㄹ
    });

    test('받침이 없으면 가 / 를 / 는 / 와', () {
      expect('루미'.subjectParticle, '가');
      expect('포포'.objectParticle, '를');
      expect('루루'.topicParticle, '는');
      expect('하나'.withParticle, '와');
    });

    test('한글이 아니면 받침 없음으로 본다', () {
      // 영문·숫자 뒤 조사는 발음 기준이라 정답이 없다. 깨지지만 않으면 된다.
      expect('Alex'.subjectParticle, '가');
      expect('7'.subjectParticle, '가');
      expect(''.subjectParticle, '가');
    });

    test('마지막 글자만 본다', () {
      expect('김민준'.subjectParticle, '이');
      expect('김루미'.subjectParticle, '가');
    });
  });

  group('보상 문구에 실제로 적용된다', () {
    test('받침 있는 이름 — 민준이', () {
      expect(RewardCharacter.ruru.messageFor('민준'), startsWith('민준이 '));
    });

    test('받침 없는 이름 — 루미가', () {
      expect(RewardCharacter.ruru.messageFor('루미'), startsWith('루미가 '));
    });

    test('이름이 비면 대체어를 쓰고 조사도 그에 맞춘다', () {
      // `가 할 일을 해내서` 처럼 조사만 남으면 안 된다
      expect(RewardCharacter.ruru.messageFor(''), startsWith('이룸이가 '));
      expect(RewardCharacter.ruru.messageFor('   '), startsWith('이룸이가 '));
    });
  });
}
