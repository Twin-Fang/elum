import 'package:elum/core/widgets/elum_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/pump_with_locale.dart';

/// 시트 면 위젯 테스트 — 손잡이 표시 여부와 윗모서리 둥글기.
void main() {
  useFigmaViewport();

  Future<void> pumpSurface(WidgetTester tester, {required bool showHandle}) {
    return pumpWithLocale(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ElumSheetSurface(
            showHandle: showHandle,
            height: 200,
            child: const SizedBox(height: 200),
          ),
        ),
      ),
    );
  }

  testWidgets('손잡이를 켜면 40x4 막대가 보인다', (tester) async {
    await pumpSurface(tester, showHandle: true);

    expect(find.byType(ElumSheetHandle), findsOneWidget);
    final size = tester.getSize(find.byType(ElumSheetHandle));
    expect(size.height, greaterThan(0));
    expect(size.width / size.height, closeTo(10, 0.01));
  });

  testWidgets('손잡이를 끄면 막대가 없다', (tester) async {
    await pumpSurface(tester, showHandle: false);

    expect(find.byType(ElumSheetHandle), findsNothing);
  });

  testWidgets('위쪽 두 모서리만 둥글다', (tester) async {
    await pumpSurface(tester, showHandle: true);

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(ElumSheetSurface),
        matching: find.byType(Container),
      ).first,
    );
    final radius =
        (box.decoration! as BoxDecoration).borderRadius! as BorderRadius;
    expect(radius.topLeft.x, greaterThan(0));
    expect(radius.bottomLeft, Radius.zero);
  });
}
