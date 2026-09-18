/// 이름 뒤 조사를 받침에 맞춰 고른다 (이슈 #196).
///
/// 이름은 보호자가 직접 적는다. `루미` 처럼 받침이 없을 수도, `민준` 처럼 있을 수도 있다.
/// 조사를 하드코딩하면 한쪽이 반드시 깨진다 — 실제로 `'$name가'` 로 박혀 있어
/// **`민준가 할 일`** 이 나왔다.
///
/// ```dart
/// '민준'.subjectParticle  // '이' → 민준이   (받침 ㄴ)
/// '루미'.subjectParticle  // '가' → 루미가   (받침 없음)
/// ```
extension KoreanParticle on String {
  /// 받침이 있으면 true. 한글이 아니면(영문·숫자·이모지) false로 본다.
  ///
  /// 한글 음절은 U+AC00부터 28개 종성 주기로 배열된다. 나머지가 0이면 받침이 없다.
  bool get _hasFinalConsonant {
    if (isEmpty) return false;
    final code = codeUnitAt(length - 1);
    if (code < 0xAC00 || code > 0xD7A3) return false;
    return (code - 0xAC00) % 28 != 0;
  }

  /// 이/가
  String get subjectParticle => _hasFinalConsonant ? '이' : '가';

  /// 을/를
  String get objectParticle => _hasFinalConsonant ? '을' : '를';

  /// 은/는
  String get topicParticle => _hasFinalConsonant ? '은' : '는';

  /// 와/과
  String get withParticle => _hasFinalConsonant ? '과' : '와';
}
