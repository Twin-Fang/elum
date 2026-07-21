import 'dart:math';

/// 보상 화면에 등장하는 캐릭터.
///
/// Figma `아이_보상_루미`(309:4055) / `_포포`(334:4320) / `_루루`(343:4434).
/// 세 화면이 배경·별은 같고 **캐릭터와 문구만 다르다.**
///
/// 온보딩에서 고른 캐릭터(고양이 루루 / 여우 포포)와 이름이 겹치지만 별개다 —
/// 여기서는 **랜덤으로 뽑는다.** 매번 같은 캐릭터가 나오면 보상이 단조로워진다.
enum RewardCharacter {
  /// 서비스 AI이자 병아리. 온보딩 선택지에는 없다.
  lumi(
    '축하해요!',
    '할 일을 해내서 루미가\n{name}에게 별을 가져왔어요',
    '오예!',
  ),

  /// 여우
  popo(
    '잘했어요!',
    '할 일을 해내서\n포포가 별을 가져왔네요',
    '오예!',
  ),

  /// 고양이
  ruru(
    '멋져요!',
    '{name}가 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
    '신난다!',
  );

  const RewardCharacter(this.title, this._messageTemplate, this.buttonLabel);

  /// 큰 제목 (30/w800)
  final String title;

  /// 두 줄 설명 원본. `{name}` 자리에 아이 이름이 들어간다.
  final String _messageTemplate;

  /// 하단 버튼 문구 (22/w800). 캐릭터마다 다르다 —
  /// 루미·포포는 `오예!`, 루루는 `신난다!` (Figma 343:4434).
  final String buttonLabel;

  /// 아이 이름을 넣은 설명 문구.
  ///
  /// 이름이 비면 조사만 남아 어색해지므로 대체어를 쓴다
  /// (`가 할 일을 해내서` → `우리 아이가 할 일을 해내서`).
  String messageFor(String childName) {
    final name = childName.trim().isEmpty ? '우리 아이' : childName.trim();
    return _messageTemplate.replaceAll('{name}', name);
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
