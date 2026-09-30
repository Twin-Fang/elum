// 픽토그램 카탈로그(assets/pictograms/catalog.json)에서 허용 id 목록 파일을 만든다.
//
// 실행: dart run tool/gen_pictogram_ids.dart
//
// 왜 손으로 안 쓰는가 — 811개를 옮겨 적다 한 글자만 틀려도 그 카드는 조용히 기본 카드로
// 떨어진다. 카탈로그가 바뀌면 이 도구를 다시 돌리고, test/pictogram 의 동기 테스트가
// 두 파일이 어긋난 채 남는 것을 막는다.
import 'dart:convert';
import 'dart:io';

void main() {
  final json =
      jsonDecode(File('assets/pictograms/catalog.json').readAsStringSync())
          as Map<String, dynamic>;
  final ids = [
    for (final s in json['symbols'] as List<dynamic>)
      (s as Map<String, dynamic>)['id'] as String,
  ]..sort();

  final out = StringBuffer()
    ..writeln('// 자동 생성 — 직접 고치지 않는다. `dart run tool/gen_pictogram_ids.dart`')
    ..writeln('// 원본: assets/pictograms/catalog.json (Mulberry Symbols v3.6.1, ${ids.length}개)')
    ..writeln()
    ..writeln('/// 앱에 번들된 픽토그램 id 전부 (SVG 파일명 stem).')
    ..writeln('const pictogramIds = <String>{');
  for (final id in ids) {
    out.writeln("  '$id',");
  }
  out.writeln('};');
  File('lib/shared/pictogram/pictogram_ids.dart').writeAsStringSync(out.toString());
  stdout.writeln('${ids.length}개 기록');
}
