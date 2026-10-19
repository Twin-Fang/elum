import 'dart:ui' as ui;

import 'package:elum/core/widgets/coach_mark_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 코치마크 막의 좌우 번짐 (#794)
/// 깨지면: 태블릿 가운데 열 화면에서 첫 안내가 뜰 때 양옆 여백이 밝게 남는다(폰은 0 이라 그대로).
void main() {
  // 100x100 막을 가운데(50~150)에 두고 200 폭 그림에서 왼쪽 여백(x=10)의 불투명도를 잰다
  Future<int> leftMarginAlpha({required double sideBleed}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(50, 0);
    CoachScrimPainter(
      color: const Color(0xCC000000),
      hole: null,
      sideBleed: sideBleed,
    ).paint(canvas, const Size(100, 100));
    final image = await recorder.endRecording().toImage(200, 100);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    const x = 10;
    const y = 50;
    return bytes!.getUint8((y * 200 + x) * 4 + 3);
  }

  testWidgets('번짐 0(폰)이면 자기 크기 밖은 칠하지 않는다', (tester) async {
    final alpha = await tester.runAsync(() => leftMarginAlpha(sideBleed: 0));
    expect(alpha, 0);
  });

  testWidgets('번짐을 주면(태블릿 열 안) 열 바깥 여백까지 어둡게 칠한다', (tester) async {
    final alpha = await tester.runAsync(() => leftMarginAlpha(sideBleed: 50));
    expect(alpha, greaterThan(0));
  });
}
