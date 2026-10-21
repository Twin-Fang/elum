/// 보호자 닉네임 형식: 서버 `NicknamePolicy` 와 같은 규칙 (금지어·중복은 서버만 판단)
///
/// 규칙 3개: 2~16자, 한글·영문·숫자·하이픈만, 글자(한글·영문) 1개 이상
abstract final class GuardianNicknamePolicy {
  static const minLength = 2;
  static const maxLength = 16;

  static final _allowedCharacters = RegExp(r'^[가-힣A-Za-z0-9-]+$');
  static final _hasLetter = RegExp(r'[가-힣A-Za-z]');

  /// 앞뒤 공백을 지운 값이 형식에 맞나 (서버도 지우고 저장)
  static bool isValidFormat(String nickname) {
    final trimmed = nickname.trim();
    final length = trimmed.runes.length;
    return length >= minLength &&
        length <= maxLength &&
        _allowedCharacters.hasMatch(trimmed) &&
        _hasLetter.hasMatch(trimmed);
  }
}
