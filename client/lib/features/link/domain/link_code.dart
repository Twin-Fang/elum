/// 연결 암호 — 보호자가 불러주고 이룸이가 받아적는 여섯 글자 (이슈 #205).
///
/// 서버가 만든 값을 화면에 옮길 때와, 이룸이가 친 값을 서버에 보낼 때 모양을 맞춘다.
class LinkCode {
  const LinkCode._();

  static const length = 6;

  /// 헷갈리는 글자(`0 O 1 I L U`)를 뺀 30자. 서버와 같은 집합이다 —
  /// 여기서 더 넓게 받으면 서버가 404를 돌려주고, 좁게 받으면 맞는 암호를 막는다.
  static const alphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// 화면 표시용. `A7K3M9` → `A7K 3M9`.
  ///
  /// 여섯 글자를 한 덩어리로 보여주면 불러주다 자리를 놓친다. 3-3으로 끊어 준다.
  static String grouped(String code) {
    if (code.length != length) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }

  /// 입력을 서버에 보낼 모양으로. 소문자·공백·하이픈을 받아준다.
  ///
  /// 보호자가 화면에 보이는 대로 `A7K 3M9`이라고 불러주면 그대로 받아적는 사람이 있다.
  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  /// 우리가 만들 수 있는 모양인가. 서버에 보내기 전에 한 번 거른다.
  static bool hasValidShape(String normalized) =>
      normalized.length == length &&
      normalized.split('').every(alphabet.contains);
}
