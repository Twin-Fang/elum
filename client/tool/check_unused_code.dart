// 안 쓰는 코드 검사기. `dart run tool/check_unused_code.dart` 로 돌리고, CI 는 Flutter CI 의 규칙 검사 단계가 돌린다.
//
// 규칙 4개
// (a) lib/ 의 dart 파일은 lib/main*.dart · tool/preview/*.dart 에서 import · export · part 로 닿아야 함
// (b) app_ko.arb 의 키는 생성 파일 밖 lib/**/*.dart 에서 식별자로 한 번은 쓰여야 함
// (c) AppAssets 의 static 상수는 app_assets.dart 안팎에서 선언 줄 밖에 한 번은 쓰여야 함
// (d) assets/images · assets/icon 의 파일명은 lib · pubspec.yaml · android · ios 어딘가에 나와야 함
// 예외는 아래 목록에만 둔다. 이유 없는 예외는 두지 않는다.
import 'dart:io';

const _arbPath = 'lib/l10n/app_ko.arb';
const _assetConstantsPath = 'lib/core/assets/app_assets.dart';
const _assetRoots = ['assets/images', 'assets/icon'];

// 파일명으로 찾을 수 있는 곳 (텍스트 파일만 읽음)
const _assetReferenceRoots = ['lib', 'pubspec.yaml', 'android', 'ios'];
const _skippedDirectoryNames = {'build', 'Pods', '.gradle', '.dart_tool', '.symlinks', 'DerivedData', '.idea'};
const _binaryExtensions = {
  'png', 'jpg', 'jpeg', 'webp', 'gif', 'ico', 'icns', 'jar', 'so', 'a', 'ttf', 'otf',
  'm4a', 'mp3', 'wav', 'zip', 'keystore', 'jks', 'ipa', 'apk', 'aab', 'pdf', 'car',
};

// (b) 예외: 키 이름 > 이유
const _arbKeyExceptions = <String, String>{};

// (d) 예외: 폴더 경로 접두 > 이유 (파일명이 코드에서 문자열 조립으로 만들어지는 곳)
const _assetPathExceptions = <String, String>{
  'assets/images/example_routines/': '서버가 주는 exampleImageId 로 `\$_images/example_routines/\$id.webp` 조립',
};

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    RegExp(r'lib/l10n/app_localizations[^/]*\.dart$').hasMatch(path);

String _extensionOf(String path) => path.contains('.') ? path.split('.').last.toLowerCase() : '';

List<File> _filesUnder(String root, bool Function(String path) accept) {
  if (File(root).existsSync()) return accept(root) ? [File(root)] : [];
  final directory = Directory(root);
  if (!directory.existsSync()) return [];
  return [
    for (final entity in directory.listSync(recursive: true, followLinks: false))
      if (entity is File &&
          !entity.path.split('/').any(_skippedDirectoryNames.contains) &&
          accept(entity.path))
        entity,
  ];
}

String _read(File file) => String.fromCharCodes(file.readAsBytesSync());

/// (a) 진입점에서 닿지 않는 dart 파일
List<String> findUnreachableDartFiles() {
  final libFiles = _filesUnder('lib', (p) => p.endsWith('.dart') && !_isGenerated(p));
  final sourceByPath = {for (final file in libFiles) file.path: _read(file)};
  final reference = RegExp(
    r"""(?:import|export|part)\s+['"]([^'"]+)['"]|\bif\s*\([^)]*\)\s*['"]([^'"]+)['"]""",
  );
  final reached = <String>{};
  final pending = <String>[
    for (final path in sourceByPath.keys)
      if (RegExp(r'^lib/main[^/]*\.dart$').hasMatch(path)) path,
  ];
  // tool/preview 는 lib 안 파일을 import 하는 쪽이라 시작점이 아니라 사용처로만 센다
  final previewSources = [
    for (final file in _filesUnder('tool/preview', (p) => p.endsWith('.dart'))) (file.path, _read(file)),
  ];
  void collect(String fromPath, String source) {
    for (final match in reference.allMatches(source)) {
      final uri = match.group(1) ?? match.group(2)!;
      String? target;
      if (uri.startsWith('package:elum/')) {
        target = 'lib/${uri.substring('package:elum/'.length)}';
      } else if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
        target = Uri.parse(fromPath).resolve(uri).path;
      }
      if (target != null && sourceByPath.containsKey(target)) pending.add(target);
    }
  }

  for (final (path, source) in previewSources) {
    collect(path, source);
  }
  while (pending.isNotEmpty) {
    final path = pending.removeLast();
    if (!reached.add(path)) continue;
    collect(path, sourceByPath[path]!);
  }
  return [
    for (final path in sourceByPath.keys.toList()..sort())
      if (!reached.contains(path)) '$path:1 : 진입점에서 닿지 않는 파일',
  ];
}

/// 생성 파일 밖 lib 소스 전체 (키 · 상수 사용처 검색용)
String _readHandWrittenLibSource() => _filesUnder(
  'lib',
  (p) => p.endsWith('.dart') && !_isGenerated(p),
).map(_read).join('\n');

/// (b) 쓰이지 않는 ARB 키
List<String> findUnusedArbKeys() {
  final lines = File(_arbPath).readAsLinesSync();
  final source = _readHandWrittenLibSource();
  final violations = <String>[];
  for (var index = 0; index < lines.length; index++) {
    final match = RegExp(r'^  "([A-Za-z]\w*)"\s*:').firstMatch(lines[index]);
    if (match == null) continue;
    final key = match.group(1)!;
    if (_arbKeyExceptions.containsKey(key)) continue;
    if (!RegExp('\\b$key\\b').hasMatch(source)) {
      violations.add('$_arbPath:${index + 1} : ARB 키 $key 를 쓰는 곳 없음');
    }
  }
  return violations;
}

/// (c) 쓰이지 않는 AppAssets 상수
List<String> findUnusedAssetConstants() {
  final lines = File(_assetConstantsPath).readAsLinesSync();
  final source = _readHandWrittenLibSource();
  final violations = <String>[];
  for (var index = 0; index < lines.length; index++) {
    final match = RegExp(r'^\s*static (?:const|final) (?:\w+ )?([a-z]\w*)\s*=').firstMatch(lines[index]);
    if (match == null) continue;
    final name = match.group(1)!;
    final usageCount = RegExp('\\b$name\\b').allMatches(source).length;
    // 선언 1회 말고 한 번도 안 나오면 위반
    if (usageCount <= 1) {
      violations.add('$_assetConstantsPath:${index + 1} : AppAssets.$name 를 쓰는 곳 없음');
    }
  }
  return violations;
}

/// 문자열 조립으로 만드는 파일명 패턴 (`star_deco_$index.png` > star_deco_.*\.png)
/// 앞부분 글자가 3자 미만이면 모든 파일에 걸리므로 패턴으로 치지 않음
List<RegExp> _readDynamicFileNamePatterns(String source) {
  final patterns = <RegExp>[];
  for (final match in RegExp(r"""['"]([^'"\n]*\$[^'"\n]*\.(?:png|svg|webp|jpg|jpeg))['"]""").allMatches(source)) {
    final fileName = match.group(1)!.split('/').last;
    final literalPrefix = fileName.split(r'$').first;
    if (literalPrefix.length < 3) continue;
    final escaped = fileName.split(RegExp(r'\$\{[^}]*\}|\$\w+')).map(RegExp.escape).join(r'\w+');
    patterns.add(RegExp('^$escaped\$'));
  }
  return patterns;
}

/// (d) 어디에도 이름이 안 나오는 에셋 파일
List<String> findUnreferencedAssetFiles() {
  final referenceFiles = [
    for (final root in _assetReferenceRoots)
      ..._filesUnder(root, (p) => !_binaryExtensions.contains(_extensionOf(p))),
  ];
  final referenceText = referenceFiles.map(_read).join('\n');
  final dynamicPatterns = _readDynamicFileNamePatterns(referenceText);
  final violations = <String>[];
  for (final root in _assetRoots) {
    for (final file in _filesUnder(root, (_) => true)) {
      final path = file.path;
      final fileName = path.split('/').last;
      if (_assetPathExceptions.keys.any(path.startsWith)) continue;
      if (referenceText.contains(fileName)) continue;
      if (dynamicPatterns.any((pattern) => pattern.hasMatch(fileName))) continue;
      violations.add('$path:1 : 파일명이 lib · pubspec.yaml · android · ios 어디에도 없음');
    }
  }
  return violations..sort();
}

void main() {
  if (!Directory('lib').existsSync()) {
    stderr.writeln('[unused code] missing lib (client 폴더에서 실행)');
    exit(2);
  }
  final violations = [
    ...findUnreachableDartFiles(),
    ...findUnusedArbKeys(),
    ...findUnusedAssetConstants(),
    ...findUnreferencedAssetFiles(),
  ];
  if (violations.isEmpty) {
    stdout.writeln('[unused code] ok');
    return;
  }
  stderr.writeln('[unused code] ${violations.length} violation(s)');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  exit(1);
}
