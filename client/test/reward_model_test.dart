import 'package:elum/shared/models/reward_preset.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 보상(강화물) 데이터 계층 — 이슈 #148·#151
///
/// 2026-09-13 서울 ABA연구소 자문의 핵심이 보상이었다. 여기서 지키려는 것은 하나다:
/// **보상을 정하지 않은 보호자에게 보상 UI가 뜨면 안 된다.**
void main() {
  group('RewardPreset — 서버 키와의 대응', () {
    test('서버가 쓰는 키 5종이 그대로 있다', () {
      // 서버 RewardPreset enum과 1:1이어야 한다. 하나라도 어긋나면 저장이 조용히 실패한다.
      expect(
        RewardPreset.values.map((p) => p.key),
        containsAll(<String>['SNACK', 'VIDEO', 'PLAY', 'WALK', 'CUSTOM']),
      );
    });

    test('모르는 키·null·빈 값은 null이다 — 화면이 죽으면 안 된다', () {
      // 서버에 프리셋이 추가됐는데 앱이 아직 모르는 상황이 실제로 생긴다.
      expect(RewardPreset.fromKey('GAME'), isNull);
      expect(RewardPreset.fromKey(null), isNull);
      expect(RewardPreset.fromKey('  '), isNull);
    });

  });

  group('Routine — 보상이 없을 때', () {
  });

  group('Routine — 보상이 있을 때', () {
    test('직접 입력한 보상은 글자만 보여준다 — 별을 지어 붙이지 않는다 (#275)', () {
      const routine = Routine(id: 'r1', rewardText: '할머니 집 가기');
      expect(routine.hasReward, isTrue);
      // contains로 두면 앞에 ⭐가 붙어도 통과한다. 실제로 그래서 못 잡았다.
      expect(routine.rewardDisplay, '할머니 집 가기');
    });

  });

  group('RecentReward — 재사용 칩', () {
    test('서버 응답을 그대로 읽는다', () {
      final reward = RecentReward.fromJson({
        'rewardText': '유튜브 10분',
        'rewardPresetKey': 'VIDEO',
      });
      expect(reward.rewardText, '유튜브 10분');
      expect(reward.emoji, RewardPreset.video.emoji);
    });

  });
}
