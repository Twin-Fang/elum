// ko ARB 문구가 기준 커밋의 한글 리터럴과 글자 하나까지 같은지 확인한다 (`ko` 불변 검증).
//
// 사용: `cd client && dart run tool/l10n_ko_audit.dart --base 3cfec577`
//   --arb      검사할 ARB (기본 lib/l10n/app_ko.arb)
//   --base     문구를 옮기기 **전** 커밋. 이 커밋의 lib 에서 문자열 리터럴을 읽는다.
//   --accepted 눈으로 확인해 수용한 조각 목록 (기본 tool/l10n_ko_audit_accepted.txt)
//
// 검사 방식: 기준 커밋 `lib` 의 Dart 소스에서 **문자열 리터럴**(붙여 쓴 `'a' 'b'` 는 하나로 묶는다)을
// 뽑고, ARB 문구를 자리표시자·ICU 가지·줄바꿈 기준으로 조각내 리터럴과 맞댄다. 주석·코드에 같은
// 글이 있다고 통과하지 않는다. 조각 앞뒤 공백은 자르지 않는다(공백 차이도 실패).
//
// 맞대는 규칙 (조각 = 문구를 자리표시자·줄바꿈으로 자른 글):
//  - 문구 **전체**가 조각 하나(평문)면 리터럴 본문과 **정확히 같아야** 한다 (`'다음'` ≠ `'다음에'`).
//  - 문구의 **시작** 조각은 리터럴 맨 앞, **끝** 조각은 리터럴 맨 끝에 와야 한다. 그래서 끝 마침표·
//    끝 단어·앞 단어를 지우면 걸린다.
//  - 보간 문구(`{name}` 등)는 모든 조각이 **한 리터럴 안에 이 순서로** 있어야 한다. 줄바꿈 하나로만
//    이어진 조각 사이에는 `\n` 외의 글이 끼면 안 된다.
//  - ICU `plural`/`select` 문구는 소스에서 삼항식 등으로 흩어져 있을 수 있어 조각을 **각각** 맞댄다
//    (조각끼리의 순서·같은 리터럴 여부는 보지 않는다).
// 한계: 보간 문구의 **안쪽** 조각은 부분 문자열이라 약하다 — 안쪽 한 글자 차이는 같은 리터럴
// 안의 다른 위치에 같은 글이 있으면 못 잡는다. 따옴표·역슬래시가 든 조각과, 공백 뺀 길이가
// 1글자인 조각(문구 전체가 아닌 경우)은 맞댈 수 없어 건너뛴다.
//
// 종료 코드: 0 통과 · 1 기준 소스에 없는 조각 · 2 도구를 못 돌림(기준 커밋 없음·git 오류·인자 오류).
import 'dart:convert';
import 'dart:io';

const _nul = '\u0000';

/// ARB 문구를 자른 조각 하나.
class Piece {
  const Piece(
    this.text, {
    this.atStart = false,
    this.atEnd = false,
    this.gapNewlineOnly = false,
  });

  final String text;

  /// 문구의 맨 앞에서 시작한다(앞에 자리표시자가 없다).
  final bool atStart;

  /// 문구의 맨 끝에서 끝난다(뒤에 자리표시자가 없다).
  final bool atEnd;

  /// 바로 앞 조각과 줄바꿈 하나(들)로만 이어진다.
  final bool gapNewlineOnly;
}

String _strip(String message) {
  var m = message;
  m = m.replaceAll(RegExp(r'\{\s*\w+\s*\}'), _nul); // {name}
  m = m.replaceAll(
    RegExp(r'\{\s*\w+\s*,\s*(plural|select)\s*,'),
    _nul,
  ); // {n, plural,
  // 남은 `가지이름{` (other{ · yes{ · mon{ · =0{) — 앞의 두 줄이 자리표시자를 먼저 지웠으므로 여기 남는 `{` 는 가지뿐이다
  m = m.replaceAll(RegExp(r'(=\d+|[A-Za-z_]\w*)\s*\{'), _nul);
  return m.replaceAll('}', _nul);
}

bool _isIcu(String message) =>
    RegExp(r'\{\s*\w+\s*,\s*(plural|select)\s*,').hasMatch(message);

/// ARB 문구 하나를 소스에서 찾을 조각들로 나눈다(공백은 자르지 않는다).
List<Piece> piecesOf(String message) {
  final m = _strip(message);
  final out = <Piece>[];
  final seg = StringBuffer();
  var segStart = 0;
  var gapNewlineOnly = true;

  void flush(int end) {
    final text = seg.toString();
    seg.clear();
    if (text.isEmpty) return;
    final atStart = segStart == 0;
    final atEnd = end == m.length;
    final trimmed = text.trim();
    // 따옴표·역슬래시가 든 조각은 소스 표기(`\'`, `\n`)와 달라 이 방법으로 못 맞댄다
    final unmatchable = text.contains("'") || text.contains(r'\');
    // 한 글자 조각은 어디에나 있다 — 문구 전체일 때만 따옴표 경계가 받쳐 준다
    final strong =
        trimmed.runes.length >= 2 || (atStart && atEnd && trimmed.isNotEmpty);
    if (unmatchable || !strong) {
      gapNewlineOnly = false; // 건너뛴 글이 사이에 끼었다 — 간격을 단정할 수 없다
      return;
    }
    out.add(
      Piece(
        text,
        atStart: atStart,
        atEnd: atEnd,
        gapNewlineOnly: out.isNotEmpty && gapNewlineOnly,
      ),
    );
    gapNewlineOnly = true;
  }

  for (var i = 0; i < m.length; i++) {
    final c = m[i];
    if (c == _nul || c == '\n') {
      flush(i);
      if (c == _nul) gapNewlineOnly = false;
      segStart = i + 1;
    } else {
      seg.write(c);
    }
  }
  flush(m.length);
  return out;
}

/// 테스트·진단용: 조각의 글만.
List<String> fragmentsOf(String message) =>
    piecesOf(message).map((p) => p.text).toList();

bool _isIdent(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// Dart 소스에서 문자열 리터럴 묶음의 본문을 뽑는다. 붙여 쓴 `'a' 'b'` 는 한 묶음(`ab`)이다.
/// 본문은 소스 표기 그대로다(`\n`·`$name`·`${...}` 가 글자로 남는다). 주석은 건너뛴다.
List<String> chainsOf(String src) {
  final out = <String>[];
  var i = 0;
  while (i < src.length) {
    if (src.startsWith('//', i)) {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
    } else if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      i = end < 0 ? src.length : end + 2;
    } else if (src[i] == "'" || src[i] == '"') {
      final body = StringBuffer();
      // 리터럴을 읽고, 공백 뒤에 또 따옴표가 오면 이어 붙인 한 묶음으로 계속 읽는다
      while (true) {
        i = _readLiteral(src, i, body);
        var j = i;
        while (j < src.length &&
            (src[j] == ' ' ||
                src[j] == '\t' ||
                src[j] == '\n' ||
                src[j] == '\r')) {
          j++;
        }
        if (j < src.length && (src[j] == "'" || src[j] == '"')) {
          i = j;
        } else {
          break;
        }
      }
      out.add(body.toString());
    } else {
      i++;
    }
  }
  return out;
}

/// `start` 의 여는 따옴표부터 닫는 따옴표까지 읽어 본문을 `body` 에 붙이고 다음 위치를 돌려준다.
int _readLiteral(String src, int start, StringBuffer body) {
  final q = src[start];
  final triple = src.startsWith(q * 3, start);
  final raw =
      start > 0 &&
      src[start - 1] == 'r' &&
      (start < 2 || !_isIdent(src[start - 2]));
  var i = start + (triple ? 3 : 1);
  while (i < src.length) {
    final c = src[i];
    if (!raw && c == r'\' && i + 1 < src.length) {
      body.write(src.substring(i, i + 2));
      i += 2;
    } else if (!raw && c == r'$' && i + 1 < src.length && src[i + 1] == '{') {
      // 보간 `${ ... }` 는 중괄호 짝까지 통째로 본문에 둔다
      var depth = 0;
      while (i < src.length) {
        body.write(src[i]);
        if (src[i] == '{') depth++;
        if (src[i] == '}' && --depth == 0) {
          i++;
          break;
        }
        i++;
      }
    } else if (triple ? src.startsWith(q * 3, i) : c == q) {
      return i + (triple ? 3 : 1);
    } else if (!triple && c == '\n') {
      return i; // 닫히지 않은 리터럴 — 거기서 끊는다
    } else {
      body.write(c);
      i++;
    }
  }
  return i;
}

bool _pieceIn(String chain, Piece p) {
  if (p.atStart && p.atEnd) return chain == p.text;
  if (p.atStart) return chain.startsWith(p.text);
  if (p.atEnd) return chain.endsWith(p.text);
  return chain.contains(p.text);
}

final _newlineOnly = RegExp(r'^(\\n|\n)*$');

/// 조각들이 한 묶음 안에 순서대로 있는지(앞에서부터 모든 위치를 시도한다).
bool _ordered(String chain, List<Piece> ps, int k, int from) {
  if (k == ps.length) return true;
  final p = ps[k];
  var idx = chain.indexOf(p.text, from);
  while (idx >= 0) {
    final end = idx + p.text.length;
    final okStart = !p.atStart || idx == 0;
    final okEnd = !p.atEnd || end == chain.length;
    final okGap =
        !p.gapNewlineOnly || _newlineOnly.hasMatch(chain.substring(from, idx));
    if (okStart && okEnd && okGap && _ordered(chain, ps, k + 1, end)) {
      return true;
    }
    idx = chain.indexOf(p.text, idx + 1);
  }
  return false;
}

/// ARB 맵을 감사한다. `missing` 은 `키: "조각"` 형식이라 어느 키의 어느 조각인지 바로 보인다.
/// [chains] 는 기준 커밋 소스의 문자열 리터럴 묶음 본문들이다(`chainsOf`).
({int checked, List<String> missing}) auditArb(
  Map<String, dynamic> arb,
  List<String> chains, {
  Set<String> accepted = const {},
}) {
  var checked = 0;
  final missing = <String>[];
  for (final e in arb.entries) {
    if (e.key.startsWith('@') || e.value is! String) continue;
    final text = e.value as String;
    // JSON 의 `\n` 은 줄바꿈 문자로 읽힌다. 역슬래시가 **글자로** 남았다면 `\\n` 으로 잘못 쓴 것이다
    // (조각 검사는 역슬래시가 든 조각을 건너뛰므로 여기서 따로 잡는다).
    if (text.contains(r'\')) {
      missing.add('${e.key}: 역슬래시 글자가 있다 — 줄바꿈은 JSON 에서 `\\n` 하나다');
      continue;
    }
    final pieces = piecesOf(text);
    var allFound = true;
    for (final p in pieces) {
      checked++;
      if (accepted.contains(p.text) || accepted.contains(p.text.trim())) {
        allFound = false; // 수용한 조각이 있으면 순서 검사는 건너뛴다
        continue;
      }
      if (chains.any((c) => _pieceIn(c, p))) continue;
      allFound = false;
      missing.add('${e.key}: "${p.text}"');
    }
    if (allFound &&
        !_isIcu(text) &&
        pieces.length > 1 &&
        !chains.any((c) => _ordered(c, pieces, 0, 0))) {
      missing.add(
        '${e.key}: 조각들이 기준 소스의 한 문자열 안에 이 순서로 있지 않다 — '
        '${pieces.map((p) => '"${p.text}"').join(' → ')}',
      );
    }
  }
  return (checked: checked, missing: missing);
}

/// 기준 커밋을 읽을 수 없다 — 문구가 틀린 것이 아니라 도구를 못 돌리는 상황이다.
class BaseCommitError implements Exception {
  BaseCommitError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 기준 커밋의 `lib` 소스에서 문자열 리터럴 묶음을 읽는다.
/// 커밋이 없거나(shallow clone 포함) git 이 오류를 내면 [BaseCommitError].
List<String> loadBaseChains(String base, {String? workingDirectory}) {
  final check = Process.runSync('git', [
    'cat-file',
    '-e',
    '$base^{commit}',
  ], workingDirectory: workingDirectory);
  if (check.exitCode != 0) {
    throw BaseCommitError(
      '기준 커밋 `$base` 가 로컬에 없다. `git fetch origin` 후 다시 실행해라 '
      '(shallow clone 이면 `git fetch --unshallow`).',
    );
  }
  // 종료 코드 1 은 "일치 없음"(lib 가 비어 있음), 128 등은 git 오류다
  final r = Process.runSync('git', [
    'grep',
    '-h',
    '-I',
    '-e',
    '',
    base,
    '--',
    'lib',
  ], workingDirectory: workingDirectory);
  if (r.exitCode != 0 && r.exitCode != 1) {
    throw BaseCommitError(
      'git grep 이 종료 코드 ${r.exitCode} 로 실패했다: ${r.stderr}'.trim(),
    );
  }
  final out = r.stdout as String;
  if (out.trim().isEmpty) {
    throw BaseCommitError(
      '기준 커밋 `$base` 의 lib 에서 읽은 소스가 없다 — 경로(client 에서 실행)를 확인해라.',
    );
  }
  return chainsOf(out);
}

/// CLI 본체. 종료 코드를 돌려준다(테스트에서 직접 부른다).
int runAudit(
  List<String> args, {
  String? workingDirectory,
  StringSink? out,
  StringSink? err,
}) {
  final o = out ?? stdout;
  final e = err ?? stderr;
  String opt(String name, String fallback) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final base = opt('--base', '');
  final arbPath = opt('--arb', 'lib/l10n/app_ko.arb');
  if (base.isEmpty) {
    e.writeln('--base <커밋> 이 필요하다');
    return 2;
  }
  final acceptedFile = File(
    opt('--accepted', 'tool/l10n_ko_audit_accepted.txt'),
  );
  final accepted = acceptedFile.existsSync()
      ? acceptedFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toSet()
      : <String>{};

  final List<String> chains;
  try {
    chains = loadBaseChains(base, workingDirectory: workingDirectory);
  } on BaseCommitError catch (ex) {
    e.writeln(ex.message);
    return 2;
  }
  final arb =
      jsonDecode(File(arbPath).readAsStringSync()) as Map<String, dynamic>;
  final result = auditArb(arb, chains, accepted: accepted);
  result.missing.forEach(o.writeln);
  o.writeln(
    '--- 조각 ${result.checked}개 중 기준 커밋에 없는 것 ${result.missing.length}개',
  );
  return result.missing.isEmpty ? 0 : 1;
}

void main(List<String> args) => exit(runAudit(args));
