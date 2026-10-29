// 디자인 규칙 검사기. `dart run tool/check_design_rules.dart` 로 돌리고, CI 는 Flutter CI 의 규칙 검사 단계가 돌린다.
//
// 규칙 원본은 `tool/design_rules.yaml` (Figma 화면 통계에서 뽑은 허용 값) 한 곳이다.
// 규칙 10개
// - palette: 색 토큰 값이 시안 색에 있다
// - type-token: 글자 토큰의 글꼴 · 굵기 · 크기 조합이 시안에 있다
// - color-literal · material-color: 화면 코드는 색을 토큰으로만 쓴다
// - font-literal: 화면 코드는 글꼴 · 크기를 토큰으로만 쓴다 (`copyWith(fontSize:)` 금지)
// - material-icon: 아이콘은 `fi-br` 에셋만 (Material `Icons.*` 금지)
// - material-widget: 테두리 버튼 · ListTile · Divider 같은 Material 기본 부품 금지 (공통 위젯 안 감싸기만 허용)
// - spacing · radius: 숫자로 쓴 간격 · 모서리가 시안 단계 안에 있다
// - restricted-token: 쓰는 곳을 묶어 둔 토큰(그림 색)을 화면에서 쓰지 않는다
// - text-scale: 글자 배율은 AppTextScale 한 곳 (`.sp` · noScaling · 숫자 배율 · 옛 textScaleFactor 금지, yaml `text_scale_owners` 만 예외)
// 시안 실측으로 확인한 단계 밖 값은 yaml `measured_exceptions` 에 근거 노드와 함께 둔다
//
// 이미 있는 위반은 `tool/design_rules_allowed.txt` 에 동결한다. 줄을 지울 수는 있어도 더하지 않는다.
//   dart run tool/check_design_rules.dart              # 검사
//   dart run tool/check_design_rules.dart --list       # 위반 전체를 줄 번호와 함께
//   dart run tool/check_design_rules.dart --summary    # 규칙 · 파일별 개수
import 'dart:io';

import 'package:yaml/yaml.dart';

const _rulesPath = 'tool/design_rules.yaml';
const _allowedPath = 'tool/design_rules_allowed.txt';
const _themeDir = 'lib/core/theme/';
const _colorsPath = 'lib/core/theme/app_colors.dart';
const _typographyPath = 'lib/core/theme/app_typography.dart';

/// 코드 글꼴 상수 > yaml 글꼴 이름
const _fontFamilyConstants = {
  'fontFamily': 'TmoneyRoundWind',
  'promptFontFamily': 'Pretendard',
};

/// 위반 하나: 규칙 · 파일 · 값 (동결 키) + 줄 번호 (보기용)
class Violation {
  Violation(this.rule, this.path, this.value, this.line);

  final String rule;
  final String path;
  final String value;
  final int line;

  String get key => '$rule  $path  $value';

  @override
  String toString() => '$rule  $path:$line  $value';
}

class DesignRules {
  DesignRules(YamlMap yaml)
    : palette = _hexSet(yaml['palette']),
      illustrationPalette = _hexSet(yaml['illustration_palette']),
      illustrationTokens = List<String>.from(yaml['illustration_tokens']),
      paletteExceptions = Map<String, String>.from(
        yaml['palette_exceptions'] as YamlMap,
      ),
      typography = {
        for (final family in (yaml['typography'] as YamlMap).entries)
          family.key as String: {
            for (final weight in (family.value as YamlMap).entries)
              weight.key as int: {
                for (final size in weight.value as YamlList) (size as num).toDouble(),
              },
          },
      },
      spacing = {
        for (final value in yaml['spacing'] as YamlList) (value as num).toDouble(),
      },
      spacingMaxChecked = (yaml['spacing_max_checked'] as num).toDouble(),
      radius = {
        for (final value in yaml['radius'] as YamlList) (value as num).toDouble(),
      },
      radiusPillMin = (yaml['radius_pill_min'] as num).toDouble(),
      materialWidgets = List<String>.from(yaml['material_widgets']),
      materialWrappers = Set<String>.from(
        (yaml['material_wrappers'] as YamlMap).keys,
      ),
      textScaleOwners = Set<String>.from(
        ((yaml['text_scale_owners'] as YamlMap?) ?? YamlMap()).keys,
      ),
      restrictedTokens = {
        for (final entry in ((yaml['restricted_tokens'] as YamlMap?) ?? YamlMap()).entries)
          entry.key as String: Set<String>.from((entry.value as YamlMap)['allowed'] as YamlList),
      },
      measuredExceptions = {
        for (final item in (yaml['measured_exceptions'] as YamlList?) ?? YamlList())
          '${item['rule']}  ${item['path']}  ${item['value']}',
      };

  final Set<String> palette;
  final Set<String> illustrationPalette;
  final List<String> illustrationTokens;
  final Map<String, String> paletteExceptions;
  final Map<String, Map<int, Set<double>>> typography;
  final Set<double> spacing;
  final double spacingMaxChecked;
  final Set<double> radius;
  final double radiusPillMin;
  final List<String> materialWidgets;
  final Set<String> materialWrappers;

  /// 글자 배율을 직접 다뤄도 되는 파일 (배율 원본 · 진단 기록)
  final Set<String> textScaleOwners;

  /// 토큰 이름 > 써도 되는 파일
  final Map<String, Set<String>> restrictedTokens;

  /// 시안 실측으로 확인한 예외 (동결 키와 같은 모양)
  final Set<String> measuredExceptions;

  static Set<String> _hexSet(Object? list) => {
    for (final value in list as YamlList) (value as String).toUpperCase(),
  };

  bool isAllowedColorToken(String token, String hex) {
    if (palette.contains(hex)) return true;
    if (paletteExceptions.keys.any(token.startsWith)) return true;
    return illustrationPalette.contains(hex) &&
        illustrationTokens.any(token.startsWith);
  }

  bool isAllowedSpacing(double value) =>
      value <= 0 || value > spacingMaxChecked || spacing.contains(value);

  bool isAllowedRadius(double value) =>
      value <= 0 || value >= radiusPillMin || radius.contains(value);
}

/// 줄 끝 `//` 주석을 지운다 (주석 속 예시를 위반으로 세지 않게). 문자열 속 `://` 은 남긴다
String _stripComment(String line) {
  final index = line.indexOf(RegExp(r'(^|[^:])//'));
  if (index < 0) return line;
  return line.substring(0, line[index] == '/' ? index : index + 1);
}

final _hexColor = RegExp(r'Color\(0x([0-9A-Fa-f]{2})([0-9A-Fa-f]{6})\)');
final _colorLiteral = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)|Color\.from(ARGB|RGBO)\(');
final _materialColor = RegExp(r'\bColors\.(\w+)');
final _fontLiteral = RegExp(r'\b(fontSize|fontFamily)\s*:');
final _materialIcon = RegExp(r'\bIcons\.(\w+)');
// 글자 배율은 AppTextScale 한 곳 (.sp 는 폭 배율을 한 번 더 곱하고, noScaling 은 배율을 지운다,
// TextScaler.linear 는 상한·비선형 배율을 버린다 > AppTextScale.scaledBy, textScaleFactor 는 옛 선형 값)
final _textScaleOverride = RegExp(
  r'\.sp\b|TextScaler\.noScaling|MediaQuery\.withNoTextScaling|TextScaler\.linear\(|\btextScaleFactor(?:Of)?\b',
);
final _edgeInsets = RegExp(
  r'EdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB|fromSTEB)\(([^;]*?)\)',
);
final _sizedBoxGap = RegExp(r'SizedBox\(\s*(?:width|height)\s*:\s*([\d.]+)');
final _spacingConstant = RegExp(
  r'static const _?\w*(?:[Pp]ad|[Gg]ap|[Ii]nset|[Mm]argin|[Ss]pacing|To[A-Z])\w*\s*=\s*([\d.]+)\s*;',
);
final _radiusCall = RegExp(r'(?:BorderRadius|Radius)\.circular\(\s*([\d.]+)');
final _radiusConstant = RegExp(r'static const _?\w*[Rr]adius\w*\s*=\s*([\d.]+)\s*;');
final _numberLiteral = RegExp(r'(?<![\w.])(\d+(?:\.\d+)?)(?=\s*(?:\.(?:w|h|r|sp)\b|[,)\s]|$))');

String _formatNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// 화면 · 공통 위젯 코드 한 파일 검사
List<Violation> scanSource(String path, String source, DesignRules rules) {
  final hits = <Violation>[];
  final isTheme = path.startsWith(_themeDir);
  final isMaterialWrapper = rules.materialWrappers.contains(path);
  final isTextScaleOwner = rules.textScaleOwners.contains(path);
  final materialWidget = RegExp(
    r'(?<![\w.])(' + rules.materialWidgets.join('|') + r')(?:\.\w+)?\(',
  );
  final lines = source.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final line = _stripComment(lines[index]);
    final lineNumber = index + 1;
    void add(String rule, String value) =>
        hits.add(Violation(rule, path, value, lineNumber));

    if (!isTheme) {
      for (final match in _colorLiteral.allMatches(line)) {
        add('color-literal', match.group(0)!);
      }
      for (final match in _materialColor.allMatches(line)) {
        if (match.group(1) != 'transparent') add('material-color', match.group(0)!);
      }
      for (final match in _fontLiteral.allMatches(line)) {
        add('font-literal', match.group(1)!);
      }
    }
    if (!isTextScaleOwner) {
      for (final match in _textScaleOverride.allMatches(line)) {
        add('text-scale', match.group(0)!);
      }
    }
    for (final match in _materialIcon.allMatches(line)) {
      add('material-icon', match.group(0)!);
    }
    if (!isMaterialWrapper) {
      for (final match in materialWidget.allMatches(line)) {
        add('material-widget', match.group(1)!);
      }
    }
    _checkNumbers(line, rules, add);
    for (final token in rules.restrictedTokens.entries) {
      if (!token.value.contains(path) &&
          RegExp('\\.${token.key}\\b').hasMatch(line)) {
        add('restricted-token', token.key);
      }
    }
  }
  return hits
      .where((hit) => !rules.measuredExceptions.contains(hit.key))
      .toList();
}

/// 숫자로 쓴 간격 · 모서리가 시안 단계에 있는지
void _checkNumbers(
  String line,
  DesignRules rules,
  void Function(String rule, String value) add,
) {
  void checkSpacing(String number) {
    final value = double.tryParse(number);
    if (value != null && !rules.isAllowedSpacing(value)) {
      add('spacing', _formatNumber(value));
    }
  }

  for (final match in _edgeInsets.allMatches(line)) {
    for (final number in _numberLiteral.allMatches(match.group(1)!)) {
      checkSpacing(number.group(1)!);
    }
  }
  for (final match in _sizedBoxGap.allMatches(line)) {
    checkSpacing(match.group(1)!);
  }
  for (final match in _spacingConstant.allMatches(line)) {
    checkSpacing(match.group(1)!);
  }
  for (final match in [
    ..._radiusCall.allMatches(line),
    ..._radiusConstant.allMatches(line),
  ]) {
    final value = double.tryParse(match.group(1)!);
    if (value != null && !rules.isAllowedRadius(value)) {
      add('radius', _formatNumber(value));
    }
  }
}

/// 색 토큰 값이 시안 색에 있는지 (light 정의 블록)
List<Violation> scanColorTokens(String source, DesignRules rules) {
  final hits = <Violation>[];
  final start = source.indexOf('static const light');
  if (start < 0) return hits;
  final lines = source.split('\n');
  final startLine = source.substring(0, start).split('\n').length;
  for (var index = startLine - 1; index < lines.length; index++) {
    final line = lines[index];
    if (line.trim() == ');') break;
    final match = RegExp(r'(\w+):\s*' + _hexColor.pattern).firstMatch(line);
    if (match == null) continue;
    final token = match.group(1)!;
    final hex = '#${match.group(3)!.toUpperCase()}';
    if (!rules.isAllowedColorToken(token, hex)) {
      hits.add(Violation('palette', _colorsPath, '$token=$hex', index + 1));
    }
  }
  return hits;
}

/// 글자 토큰 조합이 시안에 있는지 (standard 정의 블록)
List<Violation> scanTypographyTokens(String source, DesignRules rules) {
  final hits = <Violation>[];
  final start = source.indexOf('static const standard');
  if (start < 0) return hits;
  final style = RegExp(r'(\w+): TextStyle\(([^)]*)\)', multiLine: true);
  for (final match in style.allMatches(source, start)) {
    final body = match.group(2)!;
    final familyConstant = RegExp(r'fontFamily:\s*(\w+)').firstMatch(body)?.group(1);
    final family = _fontFamilyConstants[familyConstant] ?? familyConstant ?? '?';
    final size = double.tryParse(
      RegExp(r'fontSize:\s*([\d.]+)').firstMatch(body)?.group(1) ?? '',
    );
    final weight =
        int.tryParse(RegExp(r'FontWeight\.w(\d+)').firstMatch(body)?.group(1) ?? '') ?? 400;
    if (size == null) continue;
    final allowedSizes = rules.typography[family]?[weight] ?? const <double>{};
    if (!allowedSizes.contains(size)) {
      final line = source.substring(0, match.start).split('\n').length;
      hits.add(
        Violation(
          'type-token',
          _typographyPath,
          '${match.group(1)}=$family/$weight/${_formatNumber(size)}',
          line,
        ),
      );
    }
  }
  return hits;
}

List<Violation> scanLib(DesignRules rules, [String root = 'lib']) {
  final files =
      Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .where(
            (path) =>
                path.endsWith('.dart') &&
                !path.endsWith('.freezed.dart') &&
                !path.endsWith('.g.dart') &&
                !path.startsWith('lib/l10n/') &&
                // 개발자 도구는 출시 화면이 아니다
                !path.startsWith('lib/core/dev/'),
          )
          .toList()
        ..sort();
  return [
    for (final path in files) ...scanSource(path, File(path).readAsStringSync(), rules),
    ...scanColorTokens(File(_colorsPath).readAsStringSync(), rules),
    ...scanTypographyTokens(File(_typographyPath).readAsStringSync(), rules),
  ];
}

/// 동결 목록 (같은 줄이 여러 번 나오면 그만큼 허용). `#` 로 시작하는 줄은 설명이다
Map<String, int> loadAllowed([String path = _allowedPath]) {
  final counts = <String, int>{};
  final file = File(path);
  if (!file.existsSync()) return counts;
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    counts[line] = (counts[line] ?? 0) + 1;
  }
  return counts;
}

void main(List<String> args) {
  final rules = DesignRules(loadYaml(File(_rulesPath).readAsStringSync()) as YamlMap);
  final hits = scanLib(rules);

  if (args.contains('--list')) {
    hits.forEach(stdout.writeln);
    stdout.writeln('--- 위반 ${hits.length}건');
    return;
  }
  if (args.contains('--summary')) {
    final byRule = <String, int>{};
    final byFile = <String, int>{};
    for (final hit in hits) {
      byRule[hit.rule] = (byRule[hit.rule] ?? 0) + 1;
      byFile[hit.path] = (byFile[hit.path] ?? 0) + 1;
    }
    stdout.writeln('규칙별');
    for (final entry in byRule.entries.toList()..sort((a, b) => b.value - a.value)) {
      stdout.writeln('  ${entry.value.toString().padLeft(4)}  ${entry.key}');
    }
    stdout.writeln('파일별 (상위 40)');
    for (final entry in (byFile.entries.toList()..sort((a, b) => b.value - a.value)).take(40)) {
      stdout.writeln('  ${entry.value.toString().padLeft(4)}  ${entry.key}');
    }
    stdout.writeln('--- 위반 ${hits.length}건');
    return;
  }
  if (args.contains('--write-allowed')) {
    final header = File(_allowedPath).existsSync()
        ? File(_allowedPath).readAsLinesSync().takeWhile((l) => l.startsWith('#')).join('\n')
        : '# 디자인 규칙 동결 목록';
    final keys = hits.map((hit) => hit.key).toList()..sort();
    File(_allowedPath).writeAsStringSync('$header\n${keys.join('\n')}\n');
    stdout.writeln('동결 목록을 다시 썼다: ${keys.length}줄');
    return;
  }

  final allowed = loadAllowed();
  final remaining = Map<String, int>.of(allowed);
  final added = <Violation>[];
  for (final hit in hits) {
    final left = remaining[hit.key] ?? 0;
    if (left > 0) {
      remaining[hit.key] = left - 1;
    } else {
      added.add(hit);
    }
  }
  final stale = [
    for (final entry in remaining.entries)
      for (var count = 0; count < entry.value; count++) entry.key,
  ]..sort();
  for (final hit in added) {
    stdout.writeln('새 위반: $hit');
  }
  for (final key in stale) {
    stdout.writeln('동결 목록에서 지울 줄: $key');
  }
  stdout.writeln('--- 새 위반 ${added.length}건 · 지울 줄 ${stale.length}건 · 동결 ${hits.length - added.length}건');
  if (added.isNotEmpty || stale.isNotEmpty) exit(1);
}
