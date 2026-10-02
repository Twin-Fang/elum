// 사용자에게 보일 수 있는 한글 리터럴을 코드에서 찾는다 (다국어 문구 추출 검증용).
//
// 사용: `cd client && dart run tool/check_hangul_literals.dart [경로...]` (기본 `lib`)
// 한 줄이라도 걸리면 종료 코드 1 이다. 걸린 줄은 ARB 로 옮기거나, 사용자에게 안 보이는
// 글(로그·예외·정규식)이면 줄 끝에 `// l10n-ignore: 이유` 를 단다.
import 'dart:io';

/// 파일·폴더 전체를 건너뛴다. 이유를 반드시 적는다.
const _skipPaths = <String, String>{
  'lib/l10n/': '생성된 번역 코드',
  'lib/core/dev/': '개발자 도구 — 운영자·QA 전용이라 번역하지 않는다 (스펙 1장)',
  'lib/core/logger/': '로그 — 번역하지 않는다',
  'lib/features/auth/domain/consent_documents.dart': '약관 번들 기본값 — 하위 계획 4 소관',
  'lib/features/auth/domain/consent_body.dart': '약관 본문 파서의 한국어 규칙 — 하위 계획 4 소관',
  'lib/features/guardian/data/routine_repository.dart':
      '로그·예외 문구와 로컬 마스킹 정규식뿐이다',
  'lib/features/guardian/presentation/dlp_screen.dart':
      'DLP 폐기(#377) 후 어디서도 열지 않는 화면',
  'lib/features/guardian/data/demo_cards.dart': 'lib 어디서도 쓰지 않는 데모 카드(테스트만 참조)',
  'lib/core/assets/app_assets.dart': '@Deprecated 개발자 안내문뿐이다',
  'lib/features/auth/data/oauth_sdk.dart': '제공자 이름은 로그에만 쓴다(사용자에게 보이지 않는다)',
};

/// 이 줄은 사용자에게 보이지 않는 글이다.
final _skipLine = RegExp(
  r'''AppLogger\.|debugPrint\(|throw |FormatException|StateError|ArgumentError|'''
  r'''UnimplementedError|@Deprecated|RegExp\(|assert\(|\[config\]|\.env\.example|'''
  r'''\[cost\]|Key\('|l10n-ignore''',
);

bool _isHangul(int c) => c >= 0xAC00 && c <= 0xD7A3; // 완성형 음절만(자모는 문구가 아니다)
bool _isIdent(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// 소스를 한 글자씩 읽어 **문자열 리터럴 안**에 한글이 든 줄 번호(1부터)를 모은다.
///
/// 줄 단위 정규식은 주석 안의 `'` 를 문자열 시작으로, 삼중 따옴표 문자열 속 `//` 를
/// 주석으로 오해한다. 그래서 주석·문자열·보간(`${}`)을 상태로 따라간다.
Set<int> _hangulStringLines(String src) {
  final hits = <int>{};
  // 스택 맨 위가 지금 상태다: 코드(중괄호 깊이) 또는 문자열(따옴표·삼중·raw)
  final stack = <_Mode>[_Code()];
  var line = 1;
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    final top = stack.last;
    if (c == '\n') line++;
    if (top is _Code) {
      if (src.startsWith('//', i)) {
        // 줄 끝까지 주석
        while (i < src.length && src[i] != '\n') {
          i++;
        }
        continue;
      }
      if (src.startsWith('/*', i)) {
        // Dart 블록 주석은 중첩된다
        var depth = 1;
        i += 2;
        while (i < src.length && depth > 0) {
          if (src.startsWith('/*', i)) {
            depth++;
            i += 2;
          } else if (src.startsWith('*/', i)) {
            depth--;
            i += 2;
          } else {
            if (src[i] == '\n') line++;
            i++;
          }
        }
        continue;
      }
      if (c == "'" || c == '"') {
        final triple = src.startsWith(c * 3, i);
        // `r'...'` 는 이스케이프·보간이 없다 (r 앞이 식별자 글자면 그냥 이름의 일부)
        final raw =
            i > 0 && src[i - 1] == 'r' && (i < 2 || !_isIdent(src[i - 2]));
        stack.add(_Str(c, triple, raw));
        i += triple ? 3 : 1;
        continue;
      }
      if (c == '{') {
        top.depth++;
      } else if (c == '}') {
        if (top.depth == 0 && stack.length > 1) {
          stack.removeLast(); // 보간 `${ }` 끝 — 바깥 문자열로 돌아간다
        } else {
          top.depth--;
        }
      }
      i++;
      continue;
    }
    final str = top as _Str;
    if (!str.raw && c == r'\' && i + 1 < src.length) {
      if (src[i + 1] == '\n') line++;
      i += 2; // 이스케이프된 글자는 읽지 않는다 (`\'` 가 문자열을 끝내지 않게)
      continue;
    }
    if (!str.raw && c == r'$' && i + 1 < src.length && src[i + 1] == '{') {
      stack.add(_Code());
      i += 2;
      continue;
    }
    if (c == str.quote) {
      if (!str.triple) {
        stack.removeLast();
        i++;
        continue;
      }
      if (src.startsWith(c * 3, i)) {
        stack.removeLast();
        i += 3;
        continue;
      }
    }
    if (_isHangul(c.codeUnitAt(0))) hits.add(line);
    i++;
  }
  return hits;
}

sealed class _Mode {
  int depth = 0;
}

class _Code extends _Mode {}

class _Str extends _Mode {
  _Str(this.quote, this.triple, this.raw);
  final String quote;
  final bool triple;
  final bool raw;
}

/// 파일 하나에서 걸린 줄(`경로:줄: 내용`)을 모은다.
List<String> scan(String path, String source) {
  final lines = source.split('\n');
  final hits = _hangulStringLines(source).toList()..sort();
  return [
    for (final n in hits)
      if (n <= lines.length && !_skipLine.hasMatch(lines[n - 1]))
        '$path:$n: ${lines[n - 1].trim()}',
  ];
}

bool _skipped(String path) => _skipPaths.keys.any(path.startsWith);

void main(List<String> args) {
  final roots = args.isEmpty ? ['lib'] : args;
  final hits = <String>[];
  for (final root in roots) {
    final type = FileSystemEntity.typeSync(root);
    final files = switch (type) {
      FileSystemEntityType.directory =>
        Directory(root)
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path)
            .toList()
          ..sort(),
      FileSystemEntityType.file => [root],
      _ => <String>[],
    };
    for (final path in files) {
      if (!path.endsWith('.dart') || path.endsWith('.freezed.dart')) continue;
      if (_skipped(path)) continue;
      hits.addAll(scan(path, File(path).readAsStringSync()));
    }
  }
  hits.forEach(stdout.writeln);
  stdout.writeln('--- 사용자 노출 한글 리터럴 ${hits.length}줄');
  if (hits.isNotEmpty) exit(1);
}
