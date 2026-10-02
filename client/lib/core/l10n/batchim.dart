/// 이름 끝 글자의 받침 유무를 ARB 의 `select` 가 읽는 값으로 돌려준다.
///
/// 한국어 조사(이/가·을/를·은/는)는 **받침이 있느냐**로 갈리는데 이름은 보호자가 직접 적어서
/// 코드가 미리 알 수 없다. 조사 글자 자체는 ARB 문구가 정하고(`{batchim, select,
/// yes{이} other{가}}`), 코드는 판정값만 준다 — 다른 언어 ARB 는 이 값을 쓰지 않는다.
///
/// 한글 음절이 아니면(영문·숫자·이모지·빈 문자열) `no` 다 (기존 `KoreanParticle` 과 같다.
/// ㄹ 받침도 받침 있음으로 본다).
/// 한글 음절은 U+AC00 부터 28개 종성 주기로 배열된다. 나머지가 0이면 받침이 없다.
String batchimOf(String name) {
  if (name.isEmpty) return 'no';
  final code = name.codeUnitAt(name.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return 'no';
  return (code - 0xAC00) % 28 != 0 ? 'yes' : 'no';
}
