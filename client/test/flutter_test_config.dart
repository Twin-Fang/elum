import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// 모든 위젯 테스트에 자동 적용되는 전역 설정.
///
/// `test/` 루트의 이 파일은 flutter_test가 자동으로 찾아 실행한다.
/// 개별 테스트 파일에서 import하지 않는다.
///
/// ## 오버플로를 테스트 실패로 만든다
///
/// Flutter의 RenderFlex 오버플로는 **예외를 던지지 않는다.** 화면에 노란 줄무늬만
/// 그리고 지나가므로, 테스트는 초록불인데 실기기에서만 깨지는 상황이 생긴다.
/// 실제로 이름·PIN 화면이 키보드가 올라올 때 오버플로가 났는데도 테스트 11개가
/// 전부 통과했다. (트러블슈팅: 키보드가 올라오면 화면이 깨짐)
///
/// 여기서 오버플로를 잡아 실패시키면 어느 화면에서 나든 자동으로 걸린다.
///
/// ## 폰트를 전부 실어 준다
///
/// 테스트 환경은 폰트를 자동으로 싣지 않는다. 안 실으면 한글이 **전부 네모(□)**로
/// 그려지고 아이콘도 □가 된다. 골든은 그 상태로 기준이 잡혀 **회귀를 못 잡는다** —
/// 글자가 바뀌어도 네모 개수만 같으면 통과한다.
///
/// 전에는 골든 파일마다 `FontLoader`를 베껴 넣었다. 새 골든을 쓰는 사람이 그걸
/// 모르면 또 네모가 된다. 여기서 한 번만 실어 **모든 테스트가 같은 조건**이 되게 한다.
/// (이슈 #226)
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadAppFonts();

  final originalOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();

    // 오버플로는 "A RenderFlex overflowed by N pixels on the bottom." 형태로 온다.
    // RenderBox 계열도 같은 문구를 쓰므로 'overflowed'로 넓게 잡는다.
    if (message.contains('overflowed')) {
      // presentError로 넘기면 노란 줄무늬만 그리고 지나간다.
      // throw해야 테스트 바인딩이 pending exception으로 잡아 실패시킨다.
      throw FlutterError(
        '레이아웃 오버플로가 발생했다. 화면이 깨진다.\n\n'
        '$message\n\n'
        '키보드가 올라온 상태라면 Scaffold의 resizeToAvoidBottomInset을 확인할 것. '
        '고정 높이 위젯만 있는 화면은 본문이 줄어들면 터진다.',
      );
    }

    originalOnError?.call(details);
  };

  await testMain();
}

/// `pubspec.yaml`에 선언된 폰트를 그대로 싣는다.
///
/// 목록을 코드에 박지 않는 이유 — 폰트를 추가하고 여기를 안 고치면 그 글자만
/// 조용히 네모가 된다. pubspec을 읽으면 선언과 테스트가 어긋날 수 없다.
Future<void> _loadAppFonts() async {
  final pubspec = loadYaml(await File('pubspec.yaml').readAsString()) as YamlMap;
  final families = (pubspec['flutter'] as YamlMap?)?['fonts'] as YamlList?;

  for (final family in families ?? const []) {
    final loader = FontLoader(family['family'] as String);
    for (final font in family['fonts'] as YamlList) {
      loader.addFont(_loadAsset(font['asset'] as String));
    }
    await loader.load();
  }

  // 아이콘은 pubspec에 없다 — Flutter SDK가 번들로 싣는다.
  // 체크·화살표가 전부 □로 나오면 상태를 눈으로 구분할 수 없다.
  final icons = FontLoader('MaterialIcons')
    ..addFont(_loadAsset('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

/// 테스트 바인딩의 rootBundle은 실제 자산을 읽어 준다.
Future<ByteData> _loadAsset(String path) => rootBundle.load(path);
