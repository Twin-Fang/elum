/// 이 휴대폰을 쓰는 사람 (이슈 #212 · 명세 §4-3).
///
/// 약관 동의 뒤 한 번 고르면 저장된다. 앱을 다시 열어도 묻지 않는다.
///
/// ## 여기서 `연결 암호`를 말하지 않는다
///
/// 처음 이 화면을 보는 이룸이는 **암호를 받은 적이 없다.** `받은 코드로 연결해요`라고
/// 쓰면 "무슨 코드? 어디서 받지?"에서 막힌다. 이 단계는 **누구인가만** 묻고,
/// 암호는 다음 화면에서 처음 나오면서 어디서 받는지까지 같이 알려준다.
enum AppRole {
  /// 일과를 만드는 사람. 계정이 이 사람 것이다.
  guardian,

  /// 만들어 준 일과를 하는 당사자.
  elumi;

  /// 저장소에 남기는 값. enum 이름을 그대로 쓰되 **바꾸지 않는다** —
  /// 바꾸면 이미 저장된 휴대폰이 역할을 잃고 선택 화면으로 되돌아간다.
  String get storageValue => name;

  static AppRole? fromStorage(String? v) {
    if (v == null) return null;
    for (final r in AppRole.values) {
      if (r.storageValue == v) return r;
    }
    // 저장된 값이 깨졌거나 옛 버전의 값이다. 다시 묻는 편이 안전하다.
    return null;
  }

  /// 카드 제목 — 자기가 어느 쪽인지 알아보는 한 마디
  String get label => switch (this) {
        AppRole.guardian => '보호자예요',
        AppRole.elumi => '이룸이예요',
      };

  /// 카드 설명 — 두 선택지가 **관계로 짝을 이룬다.**
  /// 한쪽은 만들고, 한쪽은 만들어 준 걸 한다.
  String get description => switch (this) {
        AppRole.guardian => '일과를 만들어요',
        AppRole.elumi => '만들어 준 일과를 해요',
      };
}
