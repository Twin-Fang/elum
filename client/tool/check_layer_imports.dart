// 계층 import 규칙 검사기. `dart run tool/check_layer_imports.dart` 로 돌리고, CI 는 test/tool 의 시험으로 건다.
//
// 규칙
// - core·shared 는 features·app 을 모른다. 바닥 계층이 위를 알면 순환이 생기고 따로 시험할 수 없다.
// - 한 기능은 다른 기능의 data·presentation 을 직접 import 하지 않는다. 이미 있는 것은 동결 목록에 둔다.
import 'dart:io';

/// 바닥 계층 규칙에서 빼는 경로와 이유. 화면을 엮는 조립 지점만 둔다.
const _assemblyPaths = <String, String>{
  'core/router/': '라우터는 모든 화면을 알아야 경로를 만든다',
  'core/dev/': '개발자 도구는 여러 기능의 상태를 들여다본다',
};

final _import = RegExp(
  r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""",
  multiLine: true,
);

/// lib 기준 경로(`features/a/b.dart`)가 import 하는 lib 안 경로들.
Iterable<String> _libTargets(String libPath, String source) sync* {
  for (final m in _import.allMatches(source)) {
    final uri = m.group(1)!;
    if (uri.startsWith('package:elum/')) {
      yield uri.substring('package:elum/'.length);
    } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
      yield Uri.parse(libPath).resolve(uri).path;
    }
  }
}

/// 한 파일의 위반. 형식: `<파일> -> <대상>`
List<String> scan(String libPath, String source) {
  final hits = <String>[];
  final isBase = libPath.startsWith('core/') || libPath.startsWith('shared/');
  final inAssembly = _assemblyPaths.keys.any(libPath.startsWith);
  final feature = libPath.startsWith('features/')
      ? libPath.split('/')[1]
      : null;
  for (final target in _libTargets(libPath, source)) {
    if (isBase &&
        !inAssembly &&
        (target.startsWith('features/') || target.startsWith('app/'))) {
      hits.add('$libPath -> $target');
    }
    if (feature != null && target.startsWith('features/')) {
      final parts = target.split('/');
      if (parts.length > 2 &&
          parts[1] != feature &&
          (parts[2] == 'data' || parts[2] == 'presentation')) {
        hits.add('$libPath -> $target');
      }
    }
  }
  return hits;
}

/// lib 전체를 훑는다.
List<String> scanLib([String root = 'lib']) {
  final files =
      Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .where(
            (p) =>
                p.endsWith('.dart') &&
                !p.endsWith('.freezed.dart') &&
                !p.endsWith('.g.dart'),
          )
          .toList()
        ..sort();
  return [
    for (final path in files)
      ...scan(path.substring(root.length + 1), File(path).readAsStringSync()),
  ];
}

/// 동결 목록. `#` 로 시작하는 줄은 설명이다.
Set<String> allowed([String path = 'tool/layer_imports_allowed.txt']) =>
    File(path)
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toSet();

void main() {
  final hits = scanLib().toSet();
  final allow = allowed();
  final added = hits.difference(allow).toList()..sort();
  final stale = allow.difference(hits).toList()..sort();
  for (final h in added) {
    stdout.writeln('새 위반: $h');
  }
  for (final s in stale) {
    stdout.writeln('동결 목록에서 지울 줄: $s');
  }
  stdout.writeln('--- 새 위반 ${added.length}건 · 지울 줄 ${stale.length}건');
  if (added.isNotEmpty || stale.isNotEmpty) exit(1);
}
