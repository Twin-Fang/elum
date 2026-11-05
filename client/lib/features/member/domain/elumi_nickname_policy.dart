/// 이룸이 호칭 규칙: 서버 `ElumiNickname` 과 같은 상한 (#1129)
///
/// 넘기면 서버가 400 이라 입력에서 미리 막음. 온보딩 이름 칸 · 이룸이 정보 이름 바꾸기 공통
abstract final class ElumiNicknamePolicy {
  /// 글자 수 상한 (앞뒤 공백 제외)
  static const maxLength = 20;

  /// 앞뒤 공백을 지운 값이 비지 않고 상한 이내인가 (서버도 지우고 셈)
  static bool isValidLength(String nickname) {
    final length = nickname.trim().runes.length;
    return length > 0 && length <= maxLength;
  }
}
