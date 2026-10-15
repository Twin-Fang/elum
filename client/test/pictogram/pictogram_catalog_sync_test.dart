@Tags(['sync'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 픽토그램 카탈로그·자산·서버 목록이 어긋나지 않는지 (#469).
///
/// 어긋나면 화면이 깨지지는 않는다(기본 카드로 떨어진다). 그래서 **조용히** 틀린다 —
/// 이 테스트가 그 조용함을 깬다.
void main() {
  const appCatalogPath = 'assets/pictograms/catalog.json';
  const serverCatalogPath =
      '../server/src/main/resources/pictograms/catalog.json';

  Map<String, dynamic> readCatalog(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      fail('카탈로그 파일이 없다: $path (cwd=${Directory.current.path}). '
          '모노레포라 client/ 와 server/ 가 같이 있어야 한다.');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  List<String> idsOf(Map<String, dynamic> catalog) => [
    for (final s in catalog['symbols'] as List<dynamic>)
      (s as Map<String, dynamic>)['id'] as String,
  ];

  test('카탈로그 811개 id 와 assets/pictograms 의 SVG 가 1:1 이다 (누락·초과 0)', () {
    final ids = idsOf(readCatalog(appCatalogPath));
    expect(ids.length, 811);
    expect(ids.toSet().length, ids.length, reason: 'id 중복');

    final files = {
      for (final f in Directory('assets/pictograms').listSync())
        if (f is File && f.path.endsWith('.svg'))
          f.uri.pathSegments.last.replaceFirst(RegExp(r'\.svg$'), ''),
    };
    expect(ids.toSet().difference(files), isEmpty, reason: '카탈로그에 있는데 파일이 없다');
    expect(files.difference(ids.toSet()), isEmpty, reason: '파일이 있는데 카탈로그에 없다');
  });

  test('앱 카탈로그가 서버 카탈로그와 바이트까지 같다', () {
    final app = File(appCatalogPath);
    final server = File(serverCatalogPath);
    expect(app.existsSync(), isTrue, reason: '앱 카탈로그가 없다: $appCatalogPath');
    expect(
      server.existsSync(),
      isTrue,
      reason: '서버 카탈로그가 없다: $serverCatalogPath — 서버(#247) 작업이 병합돼야 한다',
    );
    expect(
      app.readAsBytesSync(),
      server.readAsBytesSync(),
      reason: '두 카탈로그가 다르다. 서버가 내려준 id 를 앱이 못 그릴 수 있다 — 한쪽을 다른 쪽으로 복사한다',
    );
  });

}
