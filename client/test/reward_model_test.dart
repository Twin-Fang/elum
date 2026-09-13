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

    test('대소문자가 달라도 알아본다', () {
      expect(RewardPreset.fromKey('snack'), RewardPreset.snack);
      expect(RewardPreset.fromKey(' Video '), RewardPreset.video);
    });

    test('모르는 키여도 그림은 준다 — 빈 자리를 남기지 않는다', () {
      expect(RewardPreset.emojiOf('GAME'), RewardPreset.custom.emoji);
      expect(RewardPreset.emojiOf(null), RewardPreset.custom.emoji);
    });

    test('보호자가 고르는 목록에 CUSTOM은 없다 — 별도 버튼이다', () {
      expect(RewardPreset.selectable, isNot(contains(RewardPreset.custom)));
      expect(RewardPreset.selectable, hasLength(4));
    });
  });

  group('Routine — 보상이 없을 때', () {
    test('기본값은 보상 없음이다', () {
      const routine = Routine(id: 'r1');
      expect(routine.hasReward, isFalse);
      expect(routine.rewardDisplay, isEmpty);
    });

    test('공백만 적힌 보상은 보상이 아니다', () {
      const routine = Routine(id: 'r1', rewardText: '   ');
      expect(
        routine.hasReward,
        isFalse,
        reason: '공백을 보상으로 치면 아동 화면에 빈 보상 바가 뜬다',
      );
    });

    test('서버가 보상 필드를 안 줘도 파싱이 죽지 않는다', () {
      final routine = Routine.fromJson({'id': 'r1', 'title': '학교 갈 준비'});
      expect(routine.hasReward, isFalse);
      expect(routine.rewardText, isEmpty);
      expect(routine.rewardPresetKey, isEmpty);
    });

    test('서버가 null을 줘도 빈 문자열로 받는다', () {
      final routine = Routine.fromJson({
        'id': 'r1',
        'rewardText': null,
        'rewardPresetKey': null,
      });
      expect(routine.hasReward, isFalse);
    });
  });

  group('Routine — 보상이 있을 때', () {
    test('프리셋 그림과 문구를 함께 보여준다', () {
      const routine = Routine(
        id: 'r1',
        rewardText: '젤리 먹기',
        rewardPresetKey: 'SNACK',
      );
      expect(routine.hasReward, isTrue);
      expect(routine.rewardDisplay, '${RewardPreset.snack.emoji} 젤리 먹기');
    });

    test('직접 입력이라 프리셋이 없어도 문구는 나온다', () {
      const routine = Routine(id: 'r1', rewardText: '할머니 집 가기');
      expect(routine.hasReward, isTrue);
      expect(routine.rewardDisplay, contains('할머니 집 가기'));
    });

    test('오프라인 캐시에 보상이 함께 저장되고 그대로 돌아온다', () {
      // 아이가 쓰는 순간 인터넷이 끊겨도 보상은 계속 보여야 한다 (이슈 #140 동기화 정책).
      const original = Routine(
        id: 'r1',
        rewardText: '젤리 먹기',
        rewardPresetKey: 'SNACK',
      );
      final restored = Routine.fromJson(original.toJson());
      expect(restored.rewardText, original.rewardText);
      expect(restored.rewardPresetKey, original.rewardPresetKey);
    });
  });

  group('RecentReward — 재사용 칩', () {
    test('내용이 없는 항목은 칩으로 띄우지 않는다', () {
      expect(const RecentReward(rewardText: '').isValid, isFalse);
      expect(const RecentReward(rewardText: '  ').isValid, isFalse);
      expect(const RecentReward(rewardText: '산책').isValid, isTrue);
    });

    test('서버 응답을 그대로 읽는다', () {
      final reward = RecentReward.fromJson({
        'rewardText': '유튜브 10분',
        'rewardPresetKey': 'VIDEO',
      });
      expect(reward.rewardText, '유튜브 10분');
      expect(reward.emoji, RewardPreset.video.emoji);
    });

    test('같은 보상은 같은 값으로 취급한다 — 중복 칩을 걸러내야 한다', () {
      const a = RecentReward(rewardText: '산책', rewardPresetKey: 'WALK');
      const b = RecentReward(rewardText: '산책', rewardPresetKey: 'WALK');
      expect(a, b);
      expect({a, b}, hasLength(1));
    });
  });
}
