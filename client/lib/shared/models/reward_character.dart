import 'dart:math';

import '../../core/l10n/batchim.dart';
import '../../core/l10n/current_l10n.dart';

/// 보상 화면에 등장하는 캐릭터.
///
/// Figma `아이_보상_루미`(309:4055) / `_포포`(334:4320) / `_루루`(343:4434).
/// 세 화면이 배경·별은 같고 **캐릭터·문구·버튼이 모두 다르다.**
///
/// 문구는 전부 Figma 원본에서 옮겼다. 루루만 별이 아니라 **선물**을 가져온다.
/// **이 상수를 고칠 땐 반드시 해당 노드를 다시 덤프한다.**
///
/// 온보딩에서 고른 캐릭터(고양이 루루 / 여우 포포)와 이름이 겹치지만 별개다 —
/// 여기서는 **랜덤으로 뽑는다.** 매번 같은 캐릭터가 나오면 보상이 단조로워진다.
enum RewardCharacter {
  /// 서비스 AI이자 병아리. 온보딩 선택지에는 없다.
  lumi,

  /// 여우
  popo,

  /// 고양이
  ruru;

  /// 큰 제목 (30/w800)
  ///
  /// 문구는 읽을 때 푼다 — 값으로 들고 있으면 앱 언어가 바뀐 뒤에도 이전 언어가 남는다.
  String get title => switch (this) {
    RewardCharacter.lumi => appL10n.rewardLumiTitle,
    RewardCharacter.popo => appL10n.rewardPopoTitle,
    RewardCharacter.ruru => appL10n.rewardRuruTitle,
  };

  /// 하단 버튼 문구 (22/w800). 캐릭터마다 다르다 —
  /// 루미·포포는 `오예!`, 루루는 `신난다!` (Figma 343:4434).
  String get buttonLabel => switch (this) {
    RewardCharacter.lumi => appL10n.rewardLumiButton,
    RewardCharacter.popo => appL10n.rewardPopoButton,
    RewardCharacter.ruru => appL10n.rewardRuruButton,
  };

  /// 이룸이 이름을 넣은 설명 문구.
  ///
  /// 이름이 비면 조사만 남아 어색해지므로 대체어를 쓴다
  /// (`가 할 일을 해내서` → `이룸이가 할 일을 해내서`).
  ///
  /// 한국어 조사는 받침에 따라 갈린다 — `민준이` / `루미가`. 코드는 받침 판정값만
  /// 넘기고 조사 글자는 문구가 정한다.
  String messageFor(String childName) {
    final name = childName.trim().isEmpty
        ? appL10n.commonElumiName
        : childName.trim();
    return switch (this) {
      RewardCharacter.lumi => appL10n.rewardLumiMessage(name),
      RewardCharacter.popo => appL10n.rewardPopoMessage(name),
      RewardCharacter.ruru => appL10n.rewardRuruMessage(name, batchimOf(name)),
    };
  }

  /// 무작위로 하나 고른다.
  ///
  /// [random]을 받는 이유는 테스트에서 결과를 고정하기 위함이다.
  /// 안 넘기면 실제 무작위로 동작한다.
  static RewardCharacter pick([Random? random]) {
    final r = random ?? Random();
    return values[r.nextInt(values.length)];
  }
}
