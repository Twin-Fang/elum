import 'package:elum/shared/models/reward_character.dart';
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


  });

  group('보상 문구에 실제로 적용된다', () {


    test('이름이 비면 대체어를 쓰고 조사도 그에 맞춘다', () {
      // `가 할 일을 해내서` 처럼 조사만 남으면 안 된다
      expect(RewardCharacter.ruru.messageFor(''), startsWith('이룸이가 '));
      expect(RewardCharacter.ruru.messageFor('   '), startsWith('이룸이가 '));
    });
  });
}
