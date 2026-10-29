// 네이티브 언어 등록 검사기 (#527). `dart run tool/check_native_locales.dart` 로 돌리고, CI 는 Flutter CI 의 규칙 검사 단계가 돌린다.
//
// 규칙 (원본: lib/core/l10n/app_locales.dart openedAppLocales)
// - OS 앱별 언어 목록에는 연 언어만: iOS lproj·pbxproj·CFBundleLocalizations, Android locales_config 가 모두 같은 목록
// - iOS 권한 문구 키(NS…UsageDescription)는 번들 lproj·대기 lproj(ios/staged_locales) 모두 빠짐없이, 빈 값 없이
// - 대기 언어는 연 언어와 겹치지 않음 (열었으면 Runner 로 옮겨야 함)
import 'dart:io';

const _appLocalesPath = 'lib/core/l10n/app_locales.dart';
const _infoPlistPath = 'ios/Runner/Info.plist';
const _iosRunnerPath = 'ios/Runner';
const _iosStagedPath = 'ios/staged_locales';
const _pbxprojPath = 'ios/Runner.xcodeproj/project.pbxproj';
const _androidManifestPath = 'android/app/src/main/AndroidManifest.xml';
const _androidLocalesConfigPath =
    'android/app/src/main/res/xml/locales_config.xml';

// 스토리보드 전용 기본 폴더 — 언어가 아님
const _iosBaseRegion = 'Base';

/// `Locale('ko')` · `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')` > `ko` · `zh-Hans`
Set<String> readOpenedLocaleTags(String appLocalesSource) {
  final block = RegExp(
    r'openedAppLocales\s*=\s*<Locale>\[(.*?)\];',
    dotAll: true,
  ).firstMatch(appLocalesSource);
  if (block == null) {
    throw StateError('$_appLocalesPath 에서 openedAppLocales 를 못 찾음');
  }
  final body = block.group(1)!;
  return {
    for (final m in RegExp(r"Locale\('(\w+)'\)").allMatches(body)) m.group(1)!,
    for (final m in RegExp(
      r"languageCode:\s*'(\w+)'\s*,\s*scriptCode:\s*'(\w+)'",
    ).allMatches(body))
      '${m.group(1)}-${m.group(2)}',
  };
}

/// Info.plist 의 CFBundleLocalizations 배열 값
Set<String> readBundleLocalizations(String plist) {
  final block = RegExp(
    r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(plist);
  if (block == null) return {};
  return {
    for (final m in RegExp(
      r'<string>([^<]+)</string>',
    ).allMatches(block.group(1)!))
      m.group(1)!.trim(),
  };
}

/// Info.plist 의 권한 문구 키 (NS…UsageDescription)
Set<String> readUsageDescriptionKeys(String plist) => {
  for (final m in RegExp(
    r'<key>(NS\w+UsageDescription)</key>',
  ).allMatches(plist))
    m.group(1)!,
};

/// pbxproj knownRegions (Base 제외)
Set<String> readKnownRegions(String pbxproj) {
  final block = RegExp(
    r'knownRegions\s*=\s*\((.*?)\);',
    dotAll: true,
  ).firstMatch(pbxproj);
  if (block == null) return {};
  return block
      .group(1)!
      .split(',')
      .map((region) => region.trim().replaceAll('"', ''))
      .where((region) => region.isNotEmpty && region != _iosBaseRegion)
      .toSet();
}

/// pbxproj 에 등록된 InfoPlist.strings 언어 (`path = ko.lproj/InfoPlist.strings`)
Set<String> readRegisteredInfoPlistStrings(String pbxproj) => {
  for (final m in RegExp(
    r'path = "?([\w-]+)\.lproj/InfoPlist\.strings"?;',
  ).allMatches(pbxproj))
    m.group(1)!,
};

/// 폴더 아래 `<언어>.lproj` 이름 (Base 제외)
Set<String> listLprojRegions(String directoryPath) {
  final directory = Directory(directoryPath);
  if (!directory.existsSync()) return {};
  return directory
      .listSync()
      .whereType<Directory>()
      .map((entry) => entry.uri.pathSegments.where((s) => s.isNotEmpty).last)
      .where((name) => name.endsWith('.lproj'))
      .map((name) => name.substring(0, name.length - '.lproj'.length))
      .where((region) => region != _iosBaseRegion)
      .toSet();
}

/// `"KEY" = "값";` 줄 > {KEY: 값} (블록 주석 제외)
Map<String, String> parseInfoPlistStrings(String text) {
  final body = text.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return {
    for (final m in RegExp(
      r'^\s*"(\w+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$',
      multiLine: true,
    ).allMatches(body))
      m.group(1)!: m.group(2)!,
  };
}

/// locales_config.xml 의 locale 이름
Set<String> readAndroidLocaleConfig(String xml) => {
  for (final m in RegExp(
    r'<locale\s+android:name="([^"]+)"',
  ).allMatches(xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')))
    m.group(1)!,
};

/// 두 목록 비교 > 다르면 위반 문구 1줄
String? describeMismatch(
  String label,
  Set<String> expected,
  Set<String> actual,
) {
  if (expected.length == actual.length && expected.containsAll(actual)) {
    return null;
  }
  final missing = expected.difference(actual).toList()..sort();
  final extra = actual.difference(expected).toList()..sort();
  return '$label: 빠짐 $missing · 남음 $extra (연 언어 기준)';
}

/// 권한 문구 파일 1개 검사 (키 누락·남는 키·빈 값)
List<String> checkInfoPlistStrings(
  String path,
  Map<String, String> values,
  Set<String> requiredKeys,
) {
  final violations = <String>[];
  final missing = requiredKeys.difference(values.keys.toSet()).toList()..sort();
  final extra = values.keys.toSet().difference(requiredKeys).toList()..sort();
  if (missing.isNotEmpty) violations.add('$path: 권한 문구 빠짐 $missing');
  if (extra.isNotEmpty) violations.add('$path: Info.plist 에 없는 키 $extra');
  for (final entry in values.entries) {
    if (entry.value.trim().isEmpty) {
      violations.add('$path: ${entry.key} 빈 값');
    }
  }
  return violations;
}

List<String> collectViolations() {
  final violations = <String>[];
  final opened = readOpenedLocaleTags(File(_appLocalesPath).readAsStringSync());
  final plist = File(_infoPlistPath).readAsStringSync();
  final pbxproj = File(_pbxprojPath).readAsStringSync();
  final bundledRegions = listLprojRegions(_iosRunnerPath);
  final stagedRegions = listLprojRegions(_iosStagedPath);

  // OS 앱별 언어 목록 일치 (iOS 4곳, Android 1곳)
  for (final mismatch in [
    describeMismatch('iOS Runner/*.lproj', opened, bundledRegions),
    describeMismatch(
      'iOS pbxproj knownRegions',
      opened,
      readKnownRegions(pbxproj),
    ),
    describeMismatch(
      'iOS pbxproj InfoPlist.strings',
      opened,
      readRegisteredInfoPlistStrings(pbxproj),
    ),
    describeMismatch(
      'iOS CFBundleLocalizations',
      opened,
      readBundleLocalizations(plist),
    ),
    describeMismatch(
      'Android locales_config.xml',
      opened,
      readAndroidLocaleConfig(
        File(_androidLocalesConfigPath).readAsStringSync(),
      ),
    ),
  ]) {
    if (mismatch != null) violations.add(mismatch);
  }

  // Android 매니페스트가 locales_config 를 가리키는가
  if (!File(
    _androidManifestPath,
  ).readAsStringSync().contains('android:localeConfig="@xml/locales_config"')) {
    violations.add('$_androidManifestPath: android:localeConfig 선언 없음');
  }

  // 대기 언어 <-> 연 언어 겹침
  final openedButStaged = stagedRegions.intersection(opened).toList()..sort();
  if (openedButStaged.isNotEmpty) {
    violations.add(
      '$_iosStagedPath: 이미 연 언어가 대기 중 $openedButStaged (Runner 로 옮김)',
    );
  }

  // 권한 문구 키 (번들·대기 공통)
  final requiredKeys = readUsageDescriptionKeys(plist);
  for (final (directoryPath, regions) in [
    (_iosRunnerPath, bundledRegions),
    (_iosStagedPath, stagedRegions),
  ]) {
    for (final region in regions) {
      final path = '$directoryPath/$region.lproj/InfoPlist.strings';
      final file = File(path);
      if (!file.existsSync()) {
        violations.add('$path: 파일 없음');
        continue;
      }
      violations.addAll(
        checkInfoPlistStrings(
          path,
          parseInfoPlistStrings(file.readAsStringSync()),
          requiredKeys,
        ),
      );
    }
  }
  return violations;
}

void main() {
  final violations = collectViolations();
  for (final violation in violations) {
    stdout.writeln('위반: $violation');
  }
  stdout.writeln('--- 네이티브 언어 위반 ${violations.length}건');
  if (violations.isNotEmpty) exit(1);
}
