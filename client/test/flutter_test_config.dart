import 'dart:async';

import 'package:flutter/foundation.dart';

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
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
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
