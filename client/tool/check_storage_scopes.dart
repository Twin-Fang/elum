// 로컬 저장 키 범위 분류 검사기. `dart run tool/check_storage_scopes.dart` 로 돌리고, CI 는 Flutter CI 의 규칙 검사 단계가 돌린다.
//
// 규칙 (원본: lib/core/storage/shared_prefs_storage.dart)
// - `static const _k이름 = '...'` 키는 분류 목록 5개 중 정확히 하나에 들어 있어야 함
//   계정 범위(accountScopedKeys·accountScopedKeyPrefixes·accountScopedKeysClearedByFeature) / 기기 범위(deviceScopedKeys·deviceScopedKeyPrefixes)
// - 분류를 빠뜨리면 로그아웃·다른 계정 로그인 때 이전 계정 값이 남음 (#1141)
import 'dart:io';

const _storagePath = 'lib/core/storage/shared_prefs_storage.dart';

// 분류 목록 이름 5개
const _scopeListNames = [
  'accountScopedKeys',
  'accountScopedKeyPrefixes',
  'accountScopedKeysClearedByFeature',
  'deviceScopedKeys',
  'deviceScopedKeyPrefixes',
];

/// 키 상수 이름 전부 (`static const _kXxx = '...'`)
Set<String> readKeyConstantNames(String source) => {
  for (final match in RegExp(
    r"static const (_k\w+)\s*=\s*\n?\s*'",
  ).allMatches(source))
    match.group(1)!,
};

/// 분류 목록 이름 > 그 안의 키 상수 이름
Map<String, List<String>> readScopeLists(String source) {
  final scopeLists = <String, List<String>>{};
  for (final listName in _scopeListNames) {
    final block = RegExp(
      'static const $listName\\s*=\\s*\\[(.*?)\\];',
      dotAll: true,
    ).firstMatch(source);
    if (block == null) {
      throw StateError('$_storagePath 에서 $listName 목록을 못 찾음');
    }
    scopeLists[listName] = [
      for (final match in RegExp(r'_k\w+').allMatches(block.group(1)!))
        match.group(0)!,
    ];
  }
  return scopeLists;
}

/// 위반 목록: 미분류 · 두 곳 이상 분류 · 없는 키 분류
List<String> findScopeViolations(String source) {
  final keyNames = readKeyConstantNames(source);
  final scopeLists = readScopeLists(source);
  final listNamesByKey = <String, List<String>>{};
  for (final entry in scopeLists.entries) {
    for (final keyName in entry.value) {
      listNamesByKey.putIfAbsent(keyName, () => []).add(entry.key);
    }
  }
  return [
    for (final keyName in keyNames)
      if (!listNamesByKey.containsKey(keyName))
        '$keyName: 분류 없음 (계정 범위인지 기기 범위인지 정해 목록에 넣을 것)'
      else if (listNamesByKey[keyName]!.length > 1)
        '$keyName: 두 곳 이상 분류 ${listNamesByKey[keyName]}',
    for (final keyName in listNamesByKey.keys)
      if (!keyNames.contains(keyName)) '$keyName: 분류 목록에 있지만 키 상수 없음',
  ];
}

void main() {
  final file = File(_storagePath);
  if (!file.existsSync()) {
    stderr.writeln('[storage scopes] missing $_storagePath (client 폴더에서 실행)');
    exit(2);
  }
  final violations = findScopeViolations(file.readAsStringSync());
  if (violations.isEmpty) {
    stdout.writeln('[storage scopes] ok');
    return;
  }
  stderr.writeln('[storage scopes] ${violations.length} violation(s) in $_storagePath');
  for (final violation in violations) {
    stderr.writeln('  - $violation');
  }
  exit(1);
}
