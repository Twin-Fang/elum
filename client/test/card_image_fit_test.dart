import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:elum/features/guardian/data/card_image_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/card_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카드 그림이 칸을 꽉 채우는지 본다 (시안 `Rectangle 31` 313×230 · objectFit cover, #461).
///
/// 그림 칸 비율(313:230)과 다른 그림(옛 정사각·세로)도 칸 안에 떠서 띠가 생기면 안 된다.
Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final img = await rec.endRecording().toImage(w, h);
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}

void main() {
  const boxW = 313.0;
  const boxH = 230.0;

  Future<void> pumpBox(WidgetTester tester, Uint8List png) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardImageProvider.overrideWith((ref, key) async => png),
        ],
        child: const MaterialApp(
          home: Center(
            child: SizedBox(
              width: boxW,
              height: boxH,
              child: CardImage(routineId: 'r1', stepId: 's1'),
            ),
          ),
        ),
      ),
    );
    // 바이트 디코딩은 실제 비동기라 runAsync 로 기다린다
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final (name, w, h) in [
    ('정사각(옛 그림)', 1024, 1024),
    ('가로 3:2(새 그림)', 1536, 1024),
    ('세로', 1024, 1536),
    ('칸과 같은 비율', 626, 460),
  ]) {
    testWidgets('$name 그림도 칸을 꽉 채운다', (tester) async {
      final png = (await tester.runAsync(() => _png(w, h)))!;
      await pumpBox(tester, png);

      final image = find.byType(Image);
      expect(image, findsOneWidget);
      final rect = tester.getRect(image);
      // cover 로 칸 전체를 덮는다 — 띠가 생기면 그림이 칸보다 작다
      expect(rect.width, moreOrLessEquals(boxW, epsilon: 0.5));
      expect(rect.height, moreOrLessEquals(boxH, epsilon: 0.5));
      expect(tester.widget<Image>(image).fit, BoxFit.cover);
      // 시안에 없는 확대는 두지 않는다
      expect(find.byType(Transform), findsNothing);
    });
  }
}
