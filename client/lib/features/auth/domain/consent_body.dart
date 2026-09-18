/// 약관 전문 한 덩이의 종류.
enum ConsentBlockKind {
  /// `0. 누가 입력하고, 누가 동의하나`
  section,

  /// `[계정]`
  subsection,

  /// `- 항목`
  bullet,

  /// 그 외 문단
  paragraph,
}

/// 약관 전문을 읽기 좋게 나눈 한 덩이.
class ConsentBlock {
  const ConsentBlock(this.kind, this.text);

  final ConsentBlockKind kind;
  final String text;

  @override
  String toString() => '${kind.name}: $text';

  @override
  bool operator ==(Object other) =>
      other is ConsentBlock && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);
}

final _section = RegExp(r'^\d+\.\s+(.+)$');
// 대괄호 **뒤에 꼬리가 붙는** 소제목이 있다 — `[이룸이 정보] — 보호자가 직접 입력합니다`.
// `^\[.+\]$`로 잡으면 이런 줄이 통째로 평범한 문단이 되어 소제목 자리를 잃는다.
final _subsection = RegExp(r'^\[([^\]]+)\]\s*(.*)$');

/// 약관 전문을 덩이로 나눈다 (이슈 #235).
///
/// **왜 파싱하나** — 전에는 전문 전체를 `Text` 하나로 그렸다. 섹션 번호도
/// 소제목도 불릿도 같은 크기·같은 색이라 **글자 벽처럼 보였고**, 사용자가
/// 무엇을 읽고 있는지 알 수 없었다.
///
/// **원문은 하드랩되어 있다.** 문장 하나가 여러 줄에 걸쳐 있으므로 이어 붙인다.
/// 그대로 두면 화면 폭에 맞춰 다시 줄바꿈되며 줄이 들쭉날쭉해진다.
///
/// ```
/// - 이룸이가 만 14세 미만인 경우 — 법정대리인입니다.
///   이 동의가 법이 정한 동의를 갈음합니다.     ← 앞 불릿의 이어짐
/// ```
List<ConsentBlock> parseConsentBody(String raw) {
  final blocks = <ConsentBlock>[];
  ConsentBlockKind? kind;
  final buffer = StringBuffer();

  void flush() {
    if (kind == null) return;
    final text = buffer.toString().trim();
    if (text.isNotEmpty) blocks.add(ConsentBlock(kind!, text));
    buffer.clear();
    kind = null;
  }

  void start(ConsentBlockKind k, String text) {
    flush();
    kind = k;
    buffer.write(text);
  }

  for (final line in raw.split('\n')) {
    final trimmed = line.trim();

    // 빈 줄은 덩이의 끝이다.
    if (trimmed.isEmpty) {
      flush();
      continue;
    }

    // 번호를 떼지 않는다 — `개인정보 처리방침 3조`처럼 조항 번호로 가리키는
    // 일이 있어, 화면에서 사라지면 어디를 말하는지 짚을 수 없다.
    if (_section.hasMatch(trimmed)) {
      start(ConsentBlockKind.section, trimmed);
      flush();
      continue;
    }

    final sub = _subsection.firstMatch(trimmed);
    if (sub != null) {
      final tail = sub.group(2)!.trim();
      start(
        ConsentBlockKind.subsection,
        tail.isEmpty ? sub.group(1)! : '${sub.group(1)} $tail',
      );
      flush();
      continue;
    }

    if (trimmed.startsWith('- ')) {
      start(ConsentBlockKind.bullet, trimmed.substring(2));
      continue;
    }

    // 이어지는 줄. 하드랩을 풀어 한 문장으로 잇는다.
    if (kind != null) {
      buffer.write(' $trimmed');
      continue;
    }

    start(ConsentBlockKind.paragraph, trimmed);
  }

  flush();
  return blocks;
}
