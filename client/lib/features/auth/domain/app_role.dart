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

  /// 카드 제목에서 **색이 다른 앞부분** (Figma 732:5258 · 이슈 #229).
  ///
  /// `보호자`는 민트, `이룸이`는 주황. 두 선택지를 색으로 먼저 구분하게 한다 —
  /// 글을 빨리 읽지 못해도 어느 쪽이 자기인지 보인다.
  String get roleWord => switch (this) {
        AppRole.guardian => '보호자',
        AppRole.elumi => '이룸이',
      };

  /// 카드 제목의 나머지. 앞부분과 이어 붙여 `보호자가 사용해요`가 된다.
  String get labelSuffix => '가 사용해요';

  /// 카드 제목 전체. 색 구분이 필요 없는 곳(테스트·접근성)에서 쓴다.
  String get label => '$roleWord$labelSuffix';

  /// 카드 설명 — 두 선택지가 **관계로 짝을 이룬다.**
  /// 한쪽은 만들고 관리하며, 한쪽은 그것을 실천한다.
  String get description => switch (this) {
        AppRole.guardian => '일과를 만들고 관리해요',
        AppRole.elumi => '일과를 실천해요',
      };
}
