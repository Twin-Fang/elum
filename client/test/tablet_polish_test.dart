import 'package:elum/core/widgets/elum_bottom_sheet.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/adaptive_test_app.dart';

/// 태블릿 전용 다듬기 (#789): 오로라 가운데 정렬, 가로 태블릿 옆 패널
void main() {
  // 깨지면: 일과 만들기 배경 원이 태블릿 창 왼쪽에 치우쳐 그려진다
  group('오로라 배경', () {
    Future<void> pumpAurora(WidgetTester tester, Size size) async {
      setTestWindowSize(tester, size);
      await tester.pumpWidget(
        adaptiveTestApp(home: const Scaffold(body: AuroraBackground())),
      );
      await tester.pump();
    }

    testWidgets('폰 393x852: 작은 원을 더하지 않고 시안 자리 그대로', (tester) async {
      await pumpAurora(tester, const Size(393, 852));

      expect(find.byKey(AuroraBackground.leftSatelliteKey), findsNothing);
      expect(find.byKey(AuroraBackground.rightSatelliteKey), findsNothing);
      final eclipse = tester.getCenter(find.byKey(AuroraBackground.eclipseKey));
      // 시안 Eclipse 중심 x = 11.2 + 356.7/2
      expect(eclipse.dx, closeTo(11.2 + 356.7 / 2, 1));
    });

    testWidgets('가로 태블릿 1376x1032: 두 원 묶음이 창 가운데, 양옆 작은 원', (tester) async {
      await pumpAurora(tester, const Size(1376, 1032));

      expect(find.byKey(AuroraBackground.leftSatelliteKey), findsOneWidget);
      expect(find.byKey(AuroraBackground.rightSatelliteKey), findsOneWidget);
      final eclipse = tester.getCenter(find.byKey(AuroraBackground.eclipseKey));
      expect(
        (eclipse.dx - 1376 / 2).abs(),
        lessThan(120),
        reason: '창 왼쪽이 아니라 가운데 근처',
      );
    });
  });

  // 깨지면: 가로 태블릿에서 일과 상세가 폰처럼 바닥 시트로 떠 목록을 가린다
  group('showElumSheet 옆 패널', () {
    Future<void> openSheet(WidgetTester tester, Size size) async {
      setTestWindowSize(tester, size);
      await tester.pumpWidget(
        adaptiveTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showElumSheet<void>(
                    context: context,
                    isSidePanelOnWideTablet: true,
                    builder: (_) => const ElumSheetSurface(
                      height: 300,
                      child: SizedBox(key: ValueKey('sheet-body')),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('가로 태블릿: 오른쪽 끝에 붙은 높이 전체 패널', (tester) async {
      await openSheet(tester, const Size(1376, 1032));

      final panel = tester.getRect(find.byType(ElumSheetSurface));
      expect(panel.right, closeTo(1376, 1));
      expect(panel.height, closeTo(1032, 1));
      expect(panel.width, lessThan(1376 / 2));
      expect(find.byType(ElumSheetHandle), findsNothing, reason: '끌어내리기 손잡이 없음');
    });

    testWidgets('폰: 기존 바닥 시트 그대로', (tester) async {
      await openSheet(tester, const Size(393, 852));

      final panel = tester.getRect(find.byType(ElumSheetSurface));
      expect(panel.bottom, closeTo(852, 1));
      expect(panel.height, closeTo(300, 1));
      expect(find.byType(ElumSheetHandle), findsOneWidget);
    });
  });
}
