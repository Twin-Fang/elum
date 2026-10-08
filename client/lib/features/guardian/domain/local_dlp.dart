/// 서버가 없을 때 쓰는 로컬 마스킹.
///
/// 실제 DLP는 서버(AI DLP Gateway)가 담당한다. 이건 **데모 대비용**이며,
/// 서버가 붙으면 `sanitizedInputText`를 그대로 쓴다.
abstract final class LocalDlp {
  /// 탐지 유형 4종 — 데모 성립 조건 (docs/07-mvp-scope.md)
  static final _patterns = <String, RegExp>{
    '전화번호': RegExp(r'01[0-9]-?\d{3,4}-?\d{4}'),
    '이메일': RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'),
    '학교명': RegExp(r'[가-힣]+(초등학교|중학교|고등학교|학교)'),
  };

  static String mask(String input) {
    var result = input;
    _patterns.forEach((label, pattern) {
      result = result.replaceAll(pattern, '<$label>');
    });
    return result;
  }

  /// 탐지된 유형 목록. **원문은 담지 않는다** — 유형·건수만 남긴다 (docs 원칙 5번).
  static List<String> detectedTypes(String input) {
    return [
      for (final entry in _patterns.entries)
        if (entry.value.hasMatch(input)) entry.key,
    ];
  }
}
