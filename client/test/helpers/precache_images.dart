import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 위젯 테스트에서 `Image.asset`이 **실제로 그려지게** 기다린다.
///
/// 이미지 로딩은 비동기라 `pump`만으로는 그 자리가 빈 채로 남는다. 골든이나 시안
/// 대조에서 이것을 모르면 **그림이 통째로 빠진 화면을 정답으로 굳혀 버린다** —
/// 별 화면에서 실제로 별 여덟 개가 전부 사라진 채 통과했다.
///
/// SVG(`flutter_svg`)는 동기라 이 기다림이 필요 없다. `Image` 위젯만 해당된다.
Future<void> precacheAllImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in tester.elementList(find.byType(Image))) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  // **`pumpAndSettle`을 쓰지 않는다.** 별이 둥둥 떠다니는 화면처럼 끝나지 않는
  // 애니메이션이 있으면 그대로 타임아웃된다. 한 프레임만 밀어도 방금 받아 둔
  // 이미지는 그려지고, 애니메이션을 어디서 멈출지는 부르는 쪽이 정한다.
  await tester.pump();
}
