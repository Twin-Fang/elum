import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 위젯 테스트의 화면 크기를 Figma 기준 기기(iPhone 16, 393×852)로 맞춘다.
///
/// **왜 필요한가.** `flutter test`의 기본 뷰포트는 800×600이다.
/// `ScreenUtilInit(designSize: 393×852)` 아래에서 `.h`는 `실제높이/852`로
/// 스케일되므로, 뷰포트를 그대로 두면 600/852 = 0.704가 곱해진다.
/// 칩 높이 68이 47.9로 측정되어 "코드가 틀렸다"는 잘못된 결론이 나온다.
///
/// 실제로 이 때문에 정상 동작하는 코드를 버그로 오판할 뻔했다.
/// Figma 실측값을 검증하는 테스트는 반드시 이 헬퍼로 뷰포트를 고정한다.
///
/// ```dart
/// void main() {
///   useFigmaViewport();   // main() 최상단에서 한 번 호출
///   ...
/// }
/// ```
void useFigmaViewport({Size size = const Size(393, 852)}) {
  // devicePixelRatio를 1로 두면 논리 픽셀 = 물리 픽셀이라
  // 기대값을 Figma 좌표 그대로 쓸 수 있다.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views
        .first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = size;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}
