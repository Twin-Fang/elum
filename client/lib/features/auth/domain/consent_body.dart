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

  /// `이름   값` — 공백 여러 칸으로 맞춘 표의 한 행 (#376)
  row,
}

/// 약관 전문을 읽기 좋게 나눈 한 덩이.
class ConsentBlock {
  const ConsentBlock(this.kind, this.text, {this.label, this.bulleted = false});

  final ConsentBlockKind kind;

  /// 표 행이면 **값**이다. 값이 여러 개면 `\n` 으로 나뉜다 (전달받는 자 세 곳).
  final String text;

  /// 표 행의 이름 (`전달받는 자`). 표 행이 아니면 null.
  final String? label;

  /// `- 이름   값` 처럼 불릿 안에 있던 표 행. 점을 남겨 앞뒤 불릿과 줄을 맞춘다.
  final bool bulleted;

  @override
  String toString() => [
        kind.name,
        if (bulleted) '•',
        if (label != null) '[$label]',
        ': $text',
      ].join();

  @override
  bool operator ==(Object other) =>
      other is ConsentBlock &&
      other.kind == kind &&
      other.text == text &&
      other.label == label &&
      other.bulleted == bulleted;

  @override
  int get hashCode => Object.hash(kind, text, label, bulleted);
}

final _section = RegExp(r'^\d+\.\s+(.+)$');
// 법률 문서식 조항 제목 — `제3조 (계정)` (#430). 이 줄이 있는 문서는 조항이 제목이고,
// 그 아래 `1.` `2.` 는 제목이 아니라 **본문 항목**이다.
final _article = RegExp(r'^제\d+조(\s|\(|$)');
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
///
/// **다만 공백 여러 칸으로 맞춘 표는 잇지 않는다** (#376). 이어 붙이면
/// `전달받는 자 … 이전되는 국가 미국 이전 일시 …` 가 한 덩이가 되어 어디서
/// 항목이 바뀌는지 안 보인다. 법적 고지라 항목마다 읽혀야 한다.
///
/// ```
/// 전달받는 자   Google LLC (…)        ← 표 행 (이름 · 값)
///              OpenAI, L.L.C. (…)     ← 들여쓴 줄 = 같은 항목의 다음 값
/// 이전되는 국가  미국                   ← 다음 표 행
/// ```
List<ConsentBlock> parseConsentBody(String raw) {
  final blocks = <ConsentBlock>[];
  ConsentBlockKind? kind;
  String? label;
  var bulleted = false;
  final buffer = StringBuffer();

  // 조항식 문서인가 — 서비스 이용약관은 `제N조` 가 제목이고 `1.` 은 항목이다.
  // 이걸 모르면 `1.` 을 제목으로 잘라 들여쓴 다음 줄이 떨어지고(문장이 중간에서
  // 끊김), `제N조` 는 제목이 못 되어 앞 문단에 붙었다 (#430, 실기기 실측).
  // 개인정보처리방침처럼 `1. 수집하는 항목` 이 제목인 문서는 그대로 둔다.
  final usesArticles = raw.split('\n').any((l) => _article.hasMatch(l.trim()));

  void flush() {
    if (kind == null) return;
    final text = buffer.toString().trim();
    if (text.isNotEmpty) {
      blocks.add(ConsentBlock(kind!, text, label: label, bulleted: bulleted));
    }
    buffer.clear();
    kind = null;
    label = null;
    bulleted = false;
  }

  void start(ConsentBlockKind k, String text, {String? rowLabel, bool bullet = false}) {
    flush();
    kind = k;
    label = rowLabel;
    bulleted = bullet;
    buffer.write(text);
  }

  for (final line in raw.split('\n')) {
    final trimmed = line.trim();

    // 빈 줄은 덩이의 끝이다.
    if (trimmed.isEmpty) {
      flush();
      continue;
    }

    // 표 행 아래 들여쓴 줄은 같은 항목에 붙는다 (#376 L3). 두 가지다.
    // - `전달받는 자` 아래 업체 세 곳 — 줄마다 값이 하나라 **줄로** 잇는다.
    // - `이룸이를 부르는 / 이름(별명)` — 긴 값을 하드랩한 것이라 **띄어** 잇는다.
    //   줄로 두면 `이름(별명)`이 떨어져 다른 값처럼 읽힌다.
    if (kind == ConsentBlockKind.row && line.startsWith(RegExp(r'\s'))) {
      buffer.write(_endsMidSentence(buffer.toString()) ? ' $trimmed' : '\n$trimmed');
      continue;
    }

    if (usesArticles && _article.hasMatch(trimmed)) {
      start(ConsentBlockKind.section, trimmed);
      flush();
      continue;
    }

    // 조항식 문서의 `1.` 은 본문 항목이다 — 새 문단으로 시작하고, 들여쓴 다음 줄은
    // 아래 '이어지는 줄' 규칙으로 이 항목에 붙는다.
    if (usesArticles && _section.hasMatch(trimmed)) {
      start(ConsentBlockKind.paragraph, trimmed);
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
      final item = trimmed.substring(2);
      final cells = _splitRow(item);
      if (cells != null) {
        start(ConsentBlockKind.row, cells.$2, rowLabel: cells.$1, bullet: true);
      } else {
        start(ConsentBlockKind.bullet, item);
      }
      continue;
    }

    final cells = _splitRow(trimmed);
    if (cells != null) {
      start(ConsentBlockKind.row, cells.$2, rowLabel: cells.$1);
      continue;
    }

    // 이어지는 줄. 하드랩을 풀어 한 문장으로 잇는다.
    // 표 행 뒤에 들여쓰지 않은 줄은 표가 끝난 것이다 — 값에 붙이지 않는다.
    if (kind != null && kind != ConsentBlockKind.row) {
      buffer.write(' $trimmed');
      continue;
    }

    start(ConsentBlockKind.paragraph, trimmed);
  }

  flush();
  return blocks;
}

/// 앞 줄이 문장 가운데서 끊겼나 — 한글이나 쉼표로 끝나면 하드랩이다.
///
/// 업체 이름·주소처럼 한 값이 끝난 줄은 `)`·영문으로 끝난다. 잘못 보면 두 값이
/// 한 줄로 붙는 쪽보다 한 문장이 두 줄로 갈리는 쪽이 덜 위험하므로, 확실한
/// 경우(한글·쉼표)만 잇고 나머지는 줄을 바꾼다.
bool _endsMidSentence(String text) =>
    RegExp(r'[가-힣,]$').hasMatch(text.trimRight());

/// 표 행의 이름이 될 수 있는 최대 길이. 원문에서 가장 긴 이름은 `이전되는 국가`(7).
/// 넉넉히 두되 문장 가운데 우연히 들어간 두 칸 공백을 표로 오인하지 않을 만큼만.
const _maxRowLabel = 12;

/// `이름   값` 을 (이름, 값)으로 가른다 — 표 행이 아니면 null (#376 L1·L2).
///
/// **공백 두 칸 이상**이 기준이다. 원문은 고정폭 표처럼 값을 맞추려고 이름 뒤를
/// 여러 칸 띄운다. 한 칸은 평범한 문장 속 띄어쓰기다.
(String, String)? _splitRow(String text) {
  final gap = RegExp(r' {2,}').firstMatch(text);
  if (gap == null) return null;
  final name = text.substring(0, gap.start).trim();
  final value = text.substring(gap.end).trim();
  if (name.isEmpty || value.isEmpty || name.length > _maxRowLabel) return null;
  return (name, value);
}
