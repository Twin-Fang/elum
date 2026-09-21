/// 보호자가 고를 수 있는 보상(강화물) 프리셋.
///
/// 서버 `RewardPreset`과 **키가 1:1로 맞아야 한다.**
/// 출처: server/.../routine/infrastructure/constant/RewardPreset.java
///
/// 자유 입력만 받지 않고 프리셋을 두는 이유는 **아동 화면에 그림을 띄우기 위해서**다.
/// 글자를 못 읽는 사용자에게 텍스트만 보여주면 아무 의미가 없다.
///
/// 2026-09-13 서울 ABA연구소 자문 — *"한 달 뒤 선물보다 오늘 받을 수 있는 것이 낫다"*
enum RewardPreset {
  snack('SNACK', '좋아하는 간식', '🍪'),
  video('VIDEO', '유튜브 10분', '📺'),
  play('PLAY', '좋아하는 놀이', '🧸'),
  walk('WALK', '산책', '🚶'),

  /// 프리셋에 없는 것을 보호자가 직접 적은 경우.
  /// **대표 그림이 없다** — 보호자가 적지 않은 별을 앱이 지어내면 안 된다 (#275).
  custom('CUSTOM', '직접 입력', '');

  const RewardPreset(this.key, this.label, this.emoji);

  /// 서버로 보내는 값. enum 이름(`snack`)이 아니라 이 값을 쓴다.
  final String key;

  /// 보호자 화면 칩에 보여줄 이름.
  final String label;

  /// 아동 화면용. 프리셋 그림이 준비되기 전까지 이모지로 대신한다.
  /// **[custom]은 비어 있다** — 직접 적은 말에 어울리는 그림은 앱이 알 수 없다.
  final String emoji;

  /// 보호자가 고를 수 있는 프리셋 — [custom]은 별도 버튼이라 목록에서 뺀다.
  static List<RewardPreset> get selectable =>
      values.where((p) => p != custom).toList();

  /// 서버가 준 키를 enum으로 되돌린다.
  ///
  /// **모르는 키·null·빈 문자열은 전부 null이다.** 서버에 프리셋이 추가됐는데
  /// 앱이 아직 모를 때 화면이 죽으면 안 된다 — 보상은 선택 항목이다.
  static RewardPreset? fromKey(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    final upper = key.trim().toUpperCase();
    for (final preset in values) {
      if (preset.key == upper) return preset;
    }
    return null;
  }

  /// 보상 텍스트 앞에 붙일 그림. **모르는 키는 빈 문자열이다** (#275).
  ///
  /// 예전에는 모르는 키를 ⭐로 메웠다. 그런데 별은 이룸이가 일과를 끝냈을 때 나오는
  /// 연출이라 뜻이 겹쳤고, ⭐가 `유튜브 시청 20분`을 뜻하지도 않아 그림 구실을
  /// 못 했다. **모르면 비워 두고 글자만 보여준다.**
  static String emojiOf(String? key) => fromKey(key)?.emoji ?? '';
}
