// ko ARB 문구가 기준 커밋의 한글 리터럴과 글자 하나까지 같은지 확인한다 (`ko` 불변 검증).
//
// 사용: `cd client && dart run tool/l10n_ko_audit.dart --base 3cfec577`
//   --arb  검사할 ARB (기본 lib/l10n/app_ko.arb)
//   --base 문구를 옮기기 **전** 커밋. 이 커밋의 lib 에서 조각을 찾는다.
//
// ARB 문구를 자리표시자·ICU 가지·줄바꿈 기준으로 조각내고, 각 조각(2글자 이상)이 기준
// 커밋의 소스에 그대로 있는지 `git grep -F` 로 묻는다. 없으면 오타이거나 문구를 고친 것이다.
// 붙여 쓴 문자열 리터럴(`'a' 'b'`)의 경계를 가로지르는 조각은 걸릴 수 있다 — 눈으로
// 확인한 뒤 `tool/l10n_ko_audit_accepted.txt` 에 한 줄씩 적는다.
import 'dart:convert';
import 'dart:io';

const _nul = '\u0000';

/// ARB 문구 하나를 소스에서 찾을 조각들로 나눈다.
List<String> fragmentsOf(String message) {
  var m = message;
  m = m.replaceAll(RegExp(r'\{\s*\w+\s*\}'), _nul); // {name}
  m = m.replaceAll(
    RegExp(r'\{\s*\w+\s*,\s*(plural|select)\s*,'),
    _nul,
  ); // {n, plural,
  // 남은 `가지이름{` (other{ · yes{ · mon{ · =0{) — 앞의 두 줄이 자리표시자를 먼저 지웠으므로 여기 남는 `{` 는 가지뿐이다
  m = m.replaceAll(RegExp(r'(=\d+|[A-Za-z_]\w*)\s*\{'), _nul);
  m = m.replaceAll('}', _nul);
  return m
      .split(RegExp('$_nul|\n'))
      .map((f) => f.trim())
      .where((f) => f.runes.length >= 2)
      // 따옴표·역슬래시가 든 조각은 소스 표기(`\'`, `\n`)와 달라 이 방법으로 못 맞댄다
      .where((f) => !f.contains("'") && !f.contains(r'\'))
      .toList();
}

/// 기준 커밋의 `lib` 에서 조각을 `git grep -F` 로 찾는 함수를 만든다.
/// `-e` 로 넘겨 `-` 로 시작하는 조각이 옵션으로 읽히지 않게 한다.
bool Function(String) gitGrepIn(String base, {String? workingDirectory}) {
  return (fragment) {
    final r = Process.runSync('git', [
      'grep',
      '-F',
      '-q',
      '-e',
      fragment,
      base,
      '--',
      'lib',
    ], workingDirectory: workingDirectory);
    return r.exitCode == 0;
  };
}

/// ARB 맵을 감사한다. `missing` 은 `키: "조각"` 형식이라 어느 키의 어느 조각인지 바로 보인다.
({int checked, List<String> missing}) auditArb(
  Map<String, dynamic> arb,
  bool Function(String fragment) inBase, {
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
    for (final f in fragmentsOf(text)) {
      checked++;
      if (accepted.contains(f) || inBase(f)) continue;
      missing.add('${e.key}: "$f"');
    }
  }
  return (checked: checked, missing: missing);
}

void main(List<String> args) {
  String opt(String name, String fallback) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final base = opt('--base', '');
  final arbPath = opt('--arb', 'lib/l10n/app_ko.arb');
  if (base.isEmpty) {
    stderr.writeln('--base <커밋> 이 필요하다');
    exit(2);
  }
  final acceptedFile = File('tool/l10n_ko_audit_accepted.txt');
  final accepted = acceptedFile.existsSync()
      ? acceptedFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toSet()
      : <String>{};

  final arb =
      jsonDecode(File(arbPath).readAsStringSync()) as Map<String, dynamic>;
  final result = auditArb(arb, gitGrepIn(base), accepted: accepted);
  result.missing.forEach(stdout.writeln);
  stdout.writeln(
    '--- 조각 ${result.checked}개 중 기준 커밋에 없는 것 ${result.missing.length}개',
  );
  if (result.missing.isNotEmpty) exit(1);
}
