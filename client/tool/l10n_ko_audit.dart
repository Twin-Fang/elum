// ko ARB 문구가 기준 커밋의 한글 문자열 리터럴과 글자 하나까지 같은지 확인한다 (`ko` 불변 검증).
//
// 사용: `cd client && dart run tool/l10n_ko_audit.dart --base 3cfec577`
//   --arb      검사할 ARB (기본 lib/l10n/app_ko.arb)
//   --base     문구를 옮기기 **전** 커밋. 이 커밋의 lib 에서 문자열 리터럴을 읽는다.
//   --accepted 눈으로 확인해 수용한 항목 (기본 tool/l10n_ko_audit_accepted.txt)
//
// 문구 추출 검증용 일회성 도구다. 기준 커밋(3cfec577…)이 squash 병합 등으로 사라지면 종료 코드 2 로 끝날 수 있다.
//
// 검사 방식: ARB 문구 **전체**가 기준 소스의 문자열 리터럴 **하나 전체**와 같아야 한다.
//  - 소스 리터럴은 이스케이프를 해석한 실제 값으로 읽는다(`\n`→줄바꿈, `\'`→`'`, `\$`→`$` …).
//    붙여 쓴 `'a' 'b'` 와 `'a' + 'b'` 는 하나로 이어 붙인다. raw(`r'..'`)는 해석하지 않는다.
//    보간(`$x`·`${..}`)은 자리 하나(`\u0001`)로 본다.
//  - ARB 문구는 같은 값으로 바꾼다: `{name}` 은 자리 하나, 줄바꿈 개수·위치와 앞뒤 공백은 그대로,
//    ICU `plural`/`select` 는 분기마다 (앞뒤 글 + 분기) 전체 문구로 펼쳐 각각 대조한다.
//    `#`(plural 안)은 자리 하나, ICU 따옴표(`'{'`·`''`)는 풀어서 쓴다.
//  - 그래서 글자·공백·줄바꿈 한 개의 삭제·추가·순서 변경은 모두 "소스에 같은 문자열이 없다"가 된다.
//    주석·코드·다른 리터럴 속 부분 문자열은 맞지 않는다.
//  - **검증 못 하는 문구는 통과시키지 않는다**: ICU 문법을 못 푸는 문구, 글 없이 자리표시자뿐인 문구,
//    분기가 너무 많은 문구는 `검증 불가: 키, 이유` 로 실패한다.
// 한계: 소스에서 한국어 조사 도우미(`$name.subjectParticle`)나 삼항식으로 **조립되는** 문구는 한 리터럴이
// 아니므로 실패한다 — 눈으로 확인해 수용 목록에 올린다(아래).
//
// 수용 목록 한 줄: `<항목> # <사유>` — 사유가 없으면 무시한다. 항목은 실패 메시지의 앞부분 그대로다.
//   `키: "문구"`  (소스에 같은 문자열이 없는 문구 — 문구까지 똑같을 때만 면제된다)
//   `키`          (검증 불가 문구)
//
// 종료 코드: 0 통과 · 1 소스에 없거나 검증 불가인 문구 · 2 도구를 못 돌림(기준 커밋 없음·git 오류·인자 오류).
import 'dart:convert';
import 'dart:io';

/// 보간 하나를 뜻하는 자리 표지(소스의 `$x`·`${..}`, ARB 의 `{x}`·`#`).
const _slot = '\u0001';

bool _isIdent(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

// ---------------------------------------------------------------- 소스 쪽

/// Dart 소스에서 문자열 리터럴의 **실제 값**을 뽑는다. 보간은 [_slot] 하나로 바꾼다.
/// 붙여 쓴 리터럴(`'a' 'b'`)과 `+` 로 이은 리터럴(`'a' + 'b'`)은 하나로 잇는다. 주석은 건너뛴다.
List<String> literalsOf(String src) {
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
      final value = StringBuffer();
      while (true) {
        i = _readLiteral(src, i, value);
        final next = _nextLiteralStart(src, i);
        if (next < 0) break;
        i = next;
      }
      out.add(value.toString());
    } else {
      i++;
    }
  }
  return out;
}

bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';

/// 리터럴 끝 다음에 이어지는 리터럴(공백만 사이 또는 `+`)의 여는 따옴표 위치. 없으면 -1.
int _nextLiteralStart(String src, int from) {
  var j = from;
  while (j < src.length && _isSpace(src[j])) {
    j++;
  }
  if (j < src.length && src[j] == '+') {
    j++;
    while (j < src.length && _isSpace(src[j])) {
      j++;
    }
  }
  return j < src.length && (src[j] == "'" || src[j] == '"') ? j : -1;
}

/// `start` 의 여는 따옴표부터 닫는 따옴표까지 읽어 해석한 값을 `out` 에 붙이고 다음 위치를 돌려준다.
int _readLiteral(String src, int start, StringBuffer out) {
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
      i = _readEscape(src, i, out);
    } else if (!raw && c == r'$' && i + 1 < src.length && src[i + 1] == '{') {
      out.write(_slot);
      i = _skipInterpolation(src, i + 1);
    } else if (!raw &&
        c == r'$' &&
        i + 1 < src.length &&
        RegExp(r'[A-Za-z_]').hasMatch(src[i + 1])) {
      out.write(_slot);
      i++;
      while (i < src.length && RegExp(r'\w').hasMatch(src[i])) {
        i++;
      }
    } else if (triple ? src.startsWith(q * 3, i) : c == q) {
      return i + (triple ? 3 : 1);
    } else if (!triple && c == '\n') {
      return i; // 닫히지 않은 리터럴 — 거기서 끊는다
    } else {
      out.write(c);
      i++;
    }
  }
  return i;
}

/// `\` 로 시작하는 이스케이프 하나를 해석해 붙이고 다음 위치를 돌려준다.
int _readEscape(String src, int i, StringBuffer out) {
  final e = src[i + 1];
  switch (e) {
    case 'n':
      out.write('\n');
    case 't':
      out.write('\t');
    case 'r':
      out.write('\r');
    case 'b':
      out.write('\b');
    case 'f':
      out.write('\f');
    case 'v':
      out.write('\v');
    case 'x':
      final m = RegExp(r'^[0-9a-fA-F]{2}').firstMatch(
        src.substring(i + 2, i + 4 > src.length ? src.length : i + 4),
      );
      if (m != null) {
        out.writeCharCode(int.parse(m.group(0)!, radix: 16));
        return i + 4;
      }
      out.write(e);
    case 'u':
      final braced = RegExp(r'^\{([0-9a-fA-F]+)\}').firstMatch(
        src.substring(i + 2, i + 12 > src.length ? src.length : i + 12),
      );
      if (braced != null) {
        out.writeCharCode(int.parse(braced.group(1)!, radix: 16));
        return i + 2 + braced.group(0)!.length;
      }
      final fixed = RegExp(r'^[0-9a-fA-F]{4}').firstMatch(
        src.substring(i + 2, i + 6 > src.length ? src.length : i + 6),
      );
      if (fixed != null) {
        out.writeCharCode(int.parse(fixed.group(0)!, radix: 16));
        return i + 6;
      }
      out.write(e);
    default:
      out.write(e); // `\'` `\"` `\\` `\$` 와 모르는 이스케이프는 그 글자
  }
  return i + 2;
}

/// `${ ... }` 의 `{` 위치에서 짝이 맞는 `}` 다음까지 건너뛴다(안쪽 문자열 속 중괄호는 무시).
int _skipInterpolation(String src, int braceAt) {
  var depth = 0;
  var i = braceAt;
  while (i < src.length) {
    final c = src[i];
    if (c == "'" || c == '"') {
      i++;
      while (i < src.length && src[i] != c) {
        if (src[i] == r'\') i++;
        i++;
      }
    } else if (c == '{') {
      depth++;
    } else if (c == '}' && --depth == 0) {
      return i + 1;
    }
    i++;
  }
  return i;
}

// ---------------------------------------------------------------- ARB 쪽

/// ARB 문구를 대조용 값으로 바꿀 수 없다 — 조용히 통과시키지 않고 이유를 말한다.
class Unverifiable implements Exception {
  Unverifiable(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

sealed class _Node {}

class _Text extends _Node {
  _Text(this.text);
  final String text;
}

class _Ph extends _Node {
  _Ph(this.name);
  final String name;
}

class _Icu extends _Node {
  _Icu(this.branches);
  final List<List<_Node>> branches;
}

/// 대조할 한 가지 모양의 문구. [display] 는 메시지에 보일 글(자리표시자는 `{x}`), [canon] 은 비교 값.
class Variant {
  const Variant(this.display, this.canon);
  final String display;
  final String canon;
}

class _Parser {
  _Parser(this.s);
  final String s;
  var i = 0;

  List<_Node> parseSeq({required bool inBranch, required bool inPlural}) {
    final nodes = <_Node>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) nodes.add(_Text(buf.toString()));
      buf.clear();
    }

    while (i < s.length) {
      final c = s[i];
      if (c == "'") {
        final next = i + 1 < s.length ? s[i + 1] : '';
        if (next == "'") {
          buf.write("'");
          i += 2;
        } else if (next == '{' || next == '}') {
          // ICU 따옴표: `'{'` 처럼 따옴표 사이는 글자 그대로다
          i++;
          while (i < s.length) {
            if (s[i] == "'") {
              if (i + 1 < s.length && s[i + 1] == "'") {
                buf.write("'");
                i += 2;
              } else {
                i++;
                break;
              }
            } else {
              buf.write(s[i++]);
            }
          }
        } else {
          buf.write("'");
          i++;
        }
      } else if (c == '{') {
        flush();
        nodes.add(_parseBrace(inPlural));
      } else if (c == '}') {
        if (!inBranch) throw Unverifiable('짝이 없는 `}` 가 있다');
        break;
      } else if (c == '#' && inPlural) {
        flush();
        nodes.add(_Ph('#'));
        i++;
      } else {
        buf.write(c);
        i++;
      }
    }
    flush();
    return nodes;
  }

  void _skipWs() {
    while (i < s.length && _isSpace(s[i])) {
      i++;
    }
  }

  String _word() {
    final m = RegExp(r'^[A-Za-z_]\w*').firstMatch(s.substring(i));
    if (m == null) throw Unverifiable('`{` 안을 읽을 수 없다 (위치 $i)');
    i += m.group(0)!.length;
    return m.group(0)!;
  }

  _Node _parseBrace(bool inPlural) {
    i++; // {
    _skipWs();
    final name = _word();
    _skipWs();
    if (i < s.length && s[i] == '}') {
      i++;
      return _Ph(name);
    }
    if (i >= s.length || s[i] != ',') throw Unverifiable('`{$name` 뒤를 읽을 수 없다');
    i++;
    _skipWs();
    final kind = _word();
    if (kind != 'plural' && kind != 'select') {
      throw Unverifiable('지원하지 않는 ICU 형식 `$kind`');
    }
    _skipWs();
    if (i >= s.length || s[i] != ',') throw Unverifiable('`$kind` 뒤의 `,` 가 없다');
    i++;
    final branches = <List<_Node>>[];
    while (true) {
      _skipWs();
      if (i >= s.length) throw Unverifiable('ICU 가 닫히지 않았다');
      if (s[i] == '}') {
        i++;
        break;
      }
      final sel = RegExp(r'^(=\d+|[A-Za-z_]\w*:?)').firstMatch(s.substring(i));
      if (sel == null || sel.group(0)!.endsWith(':')) {
        throw Unverifiable('ICU 분기 선택자를 읽을 수 없다 (offset 등)');
      }
      i += sel.group(0)!.length;
      _skipWs();
      if (i >= s.length || s[i] != '{') throw Unverifiable('ICU 분기에 `{` 가 없다');
      i++;
      branches.add(
        parseSeq(inBranch: true, inPlural: kind == 'plural' || inPlural),
      );
      if (i >= s.length || s[i] != '}') throw Unverifiable('ICU 분기가 닫히지 않았다');
      i++;
    }
    if (branches.isEmpty) throw Unverifiable('ICU 분기가 없다');
    return _Icu(branches);
  }
}

const _maxVariants = 200;

List<Variant> _expand(List<_Node> nodes) {
  var acc = <Variant>[const Variant('', '')];
  for (final n in nodes) {
    final next = <Variant>[];
    switch (n) {
      case _Text():
        for (final v in acc) {
          next.add(Variant(v.display + n.text, v.canon + n.text));
        }
      case _Ph():
        final shown = n.name == '#' ? '#' : '{${n.name}}';
        for (final v in acc) {
          next.add(Variant(v.display + shown, v.canon + _slot));
        }
      case _Icu():
        for (final branch in n.branches) {
          final bs = _expand(branch);
          for (final v in acc) {
            for (final b in bs) {
              next.add(Variant(v.display + b.display, v.canon + b.canon));
            }
          }
        }
    }
    if (next.length > _maxVariants) {
      throw Unverifiable('분기 조합이 $_maxVariants 개를 넘는다');
    }
    acc = next;
  }
  return acc;
}

/// ARB 문구 하나를 대조할 모양들로 펼친다. 풀 수 없으면 [Unverifiable].
/// 글이 없는 모양(빈 분기·자리표시자뿐)은 뺀다 — 하나도 안 남으면 검증할 것이 없어 [Unverifiable].
List<Variant> variantsOf(String message) {
  final parser = _Parser(message);
  final nodes = parser.parseSeq(inBranch: false, inPlural: false);
  final seen = <String>{};
  final out = <Variant>[
    for (final v in _expand(nodes))
      if (v.canon.replaceAll(_slot, '').isNotEmpty && seen.add(v.canon)) v,
  ];
  if (out.isEmpty) throw Unverifiable('대조할 글이 없다 (자리표시자뿐이거나 빈 문구)');
  return out;
}

// ---------------------------------------------------------------- 감사

String _show(String s) => s.replaceAll('\n', r'\n').replaceAll('\t', r'\t');

/// ARB 맵을 감사한다. `missing` 은 `키: "문구"` 또는 `검증 불가: 키, 이유` 로 시작하는 줄들이다.
/// [literals] 는 기준 커밋 소스의 문자열 리터럴 값들이다(`literalsOf`).
/// [accepted] 는 수용 항목(`키: "문구"` · `키`).
({int checked, List<String> missing}) auditArb(
  Map<String, dynamic> arb,
  Iterable<String> literals, {
  Set<String> accepted = const {},
}) {
  final known = literals.toSet();
  var checked = 0;
  final missing = <String>[];
  for (final e in arb.entries) {
    if (e.key.startsWith('@') || e.value is! String) continue;
    final List<Variant> variants;
    try {
      variants = variantsOf(e.value as String);
    } on Unverifiable catch (ex) {
      if (!accepted.contains(e.key)) {
        missing.add('검증 불가: ${e.key}, ${ex.reason}');
      }
      continue;
    }
    for (final v in variants) {
      checked++;
      final id = '${e.key}: "${_show(v.display)}"';
      if (known.contains(v.canon) || accepted.contains(id)) continue;
      missing.add('$id ← 기준 소스에 이 문구와 같은 문자열 리터럴이 없다');
    }
  }
  return (checked: checked, missing: missing);
}

/// 수용 목록을 읽는다. `항목 # 사유` 에서 사유가 비면 그 줄은 무시한다.
Set<String> parseAccepted(Iterable<String> lines) {
  final out = <String>{};
  for (final l in lines) {
    final at = l.indexOf(' # ');
    if (at < 0) continue;
    final id = l.substring(0, at).trim();
    if (id.isNotEmpty && l.substring(at + 3).trim().isNotEmpty) out.add(id);
  }
  return out;
}

/// 기준 커밋을 읽을 수 없다 — 문구가 틀린 것이 아니라 도구를 못 돌리는 상황이다.
class BaseCommitError implements Exception {
  BaseCommitError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 기준 커밋의 `lib` 소스에서 문자열 리터럴 값을 읽는다.
/// 커밋이 없거나(shallow clone 포함) git 이 오류를 내면 [BaseCommitError].
List<String> loadBaseLiterals(String base, {String? workingDirectory}) {
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
  return literalsOf(out);
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
      ? parseAccepted(acceptedFile.readAsLinesSync())
      : <String>{};

  final List<String> literals;
  try {
    literals = loadBaseLiterals(base, workingDirectory: workingDirectory);
  } on BaseCommitError catch (ex) {
    e.writeln(ex.message);
    return 2;
  }
  final arb =
      jsonDecode(File(arbPath).readAsStringSync()) as Map<String, dynamic>;
  final result = auditArb(arb, literals, accepted: accepted);
  result.missing.forEach(o.writeln);
  o.writeln('--- 대조한 문구 ${result.checked}개 중 실패 ${result.missing.length}건');
  return result.missing.isEmpty ? 0 : 1;
}

void main(List<String> args) => exit(runAudit(args));
