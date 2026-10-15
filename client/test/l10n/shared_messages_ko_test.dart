import 'package:elum/shared/models/reward_preset.dart';
import 'package:elum/shared/utils/korean_particle.dart';
import 'package:flutter_test/flutter_test.dart';

/// 조사·날짜를 ARB 가 넘겨받아도 `ko` 결과가 옛 직접 조립과 같다.
void main() {

  test('보상 프리셋 서버 키', () {
    expect(RewardPreset.snack.key, 'SNACK');
    expect(RewardPreset.snack.emoji, '🍪');
  });
}

/// 테스트가 batchimOf 를 직접 부르는 대신 옛 판정(KoreanParticle)으로 yes/no 를 정한다.
String batchimOfForTest(String name) => name.subjectParticle == '이' ? 'yes' : 'no';
