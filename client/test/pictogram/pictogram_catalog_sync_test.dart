@Tags(['sync'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/shared/pictogram/pictogram_catalog.dart';
import 'package:elum/shared/pictogram/pictogram_ids.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  test('앱 코드의 허용 목록(pictogram_ids.dart)이 카탈로그와 같다', () {
    final ids = idsOf(readCatalog(appCatalogPath)).toSet();
    expect(
      pictogramIds,
      ids,
      reason: '카탈로그를 바꿨으면 `dart run tool/gen_pictogram_ids.dart` 를 다시 돌린다',
    );
  });

  test('폴백 id 의 자산이 있고 코드 상수와 카탈로그가 같다', () {
    final catalog = readCatalog(appCatalogPath);
    expect(catalog['fallbackId'], PictogramCatalog.fallbackId);
    expect(File('assets/pictograms/${PictogramCatalog.fallbackId}.svg').existsSync(), isTrue);
    expect(PictogramCatalog.contains(PictogramCatalog.fallbackId), isTrue);
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

  test('pubspec 에 assets/pictograms/ 가 등록돼 있다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/pictograms/'));
  });

  test('라이선스 원문이 같이 있고 CC BY-SA 4.0 이다', () {
    final f = File('assets/pictograms/LICENSE.txt');
    expect(f.existsSync(), isTrue);
    final text = f.readAsStringSync();
    expect(text, contains('Attribution-Share Alike'));
    expect(text, contains('Steve Lee'));
  });

  test('번들 매니페스트에 811개가 전부 올라 있다 (쉼표·밑줄 파일명 포함)', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    for (final id in pictogramIds) {
      expect(assets, contains(AppAssets.pictogram(id)), reason: id);
    }
  });

  test('쉼표가 든 verb 심볼(get_dressed_,_to)을 실제로 읽어 온다', () async {
    final data = await rootBundle.loadString(AppAssets.pictogram('get_dressed_,_to'));
    expect(data, startsWith('<svg'));
  });

  test('E12 811개 SVG 를 flutter_svg 가 전부 파싱한다 (최대 112KB 포함)', () async {
    final sw = Stopwatch()..start();
    var biggest = 0;
    for (final id in pictogramIds) {
      final svg = await rootBundle.loadString(AppAssets.pictogram(id));
      if (svg.length > biggest) biggest = svg.length;
      // 파싱만 한다 — 깨진 SVG 는 여기서 예외가 난다
      await SvgStringLoader(svg).loadBytes(null);
    }
    sw.stop();
    // ignore: avoid_print
    print('811개 파싱 ${sw.elapsedMilliseconds}ms, 가장 큰 파일 ${biggest ~/ 1024}KB');
    expect(biggest, lessThan(200 * 1024));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
