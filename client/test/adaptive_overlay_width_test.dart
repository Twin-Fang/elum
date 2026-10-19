import 'package:elum/core/widgets/elum_bottom_sheet.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/core/widgets/elum_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/adaptive_test_app.dart';

/// 시트·토스트·팝업이 큰 화면에서 전폭으로 늘어나지 않는다.
/// 깨지면: 태블릿 가로에서 바텀시트가 1200px 로 펴지고 토스트가 화면 끝까지 늘어난다.
const _sheetKey = ValueKey('overlay.sheet');

/// 토스트의 보이는 면
final _toastSurface = find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
    .first;

class _Opener extends StatelessWidget {
  const _Opener({required this.onOpen});

  final void Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => onOpen(context),
          child: const Text('열기'),
        ),
      ),
    );
  }
}

void main() {
  Future<void> openSheet(WidgetTester tester, Size size) async {
    setTestWindowSize(tester, size);
    await tester.pumpWidget(
      adaptiveTestApp(
        home: _Opener(
          onOpen: (context) => showElumSheet<void>(
            context: context,
            builder: (_) => const ElumSheetSurface(
              child: SizedBox(key: _sheetKey, height: 120),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  group('바텀시트 폭', () {
    testWidgets('1366x1024: 폭 상한(560 x 배율)에서 가운데', (tester) async {
      await openSheet(tester, const Size(1366, 1024));

      final size = tester.getSize(find.byKey(_sheetKey));
      final center = tester.getCenter(find.byKey(_sheetKey));

      expect(size.width, closeTo(560 * 1024 / 852, 1));
      expect(center.dx, closeTo(1366 / 2, 1));
    });

    testWidgets('1194x834 가로에서도 전폭이 아니다', (tester) async {
      await openSheet(tester, const Size(1194, 834));

      expect(
        tester.getSize(find.byKey(_sheetKey)).width,
        lessThan(1194 * 0.6),
      );
    });

    testWidgets('393x852 폰: 창 폭 그대로 (회귀 0)', (tester) async {
      await openSheet(tester, const Size(393, 852));

      expect(tester.getSize(find.byKey(_sheetKey)).width, 393);
    });
  });

  group('팝업 카드 폭', () {
    testWidgets('1194x834: 카드 폭이 322 x 배율이라 전폭이 아니다', (tester) async {
      setTestWindowSize(tester, const Size(1194, 834));
      await tester.pumpWidget(
        adaptiveTestApp(
          home: _Opener(
            onOpen: (context) => showElumDialog<void>(
              context: context,
              title: '저장했어요',
              actions: [
                const ElumDialogAction<void>(label: '확인'),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(ElumDialogSurface));
      expect(size.width, closeTo(322 * 834 / 852, 1));
      expect(tester.getCenter(find.byType(ElumDialogSurface)).dx, closeTo(597, 1));
    });
  });

  group('토스트 폭', () {
    Future<Size> showToastAndMeasure(WidgetTester tester, Size size) async {
      setTestWindowSize(tester, size);
      await tester.pumpWidget(
        adaptiveTestApp(
          home: _Opener(
            onOpen: (context) => showElumToast(context, '저장했어요'),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // 바깥 SnackBar 는 늘 창 폭이라, 실제로 보이는 면(Material)의 폭을 잰다
      return tester.getSize(_toastSurface);
    }

    testWidgets('1366x1024: 폭 상한 안, 가운데', (tester) async {
      final toastSize = await showToastAndMeasure(
        tester,
        const Size(1366, 1024),
      );

      expect(toastSize.width, lessThanOrEqualTo(560 * 1024 / 852 + 1));
      expect(tester.getCenter(_toastSurface).dx, closeTo(1366 / 2, 1));
    });

    testWidgets('393x852 폰: 폭을 지정하지 않는다 (기존과 같다)', (tester) async {
      final toastSize = await showToastAndMeasure(
        tester,
        const Size(393, 852),
      );

      // 기존: 좌우 16 띄운 전폭
      expect(toastSize.width, 393 - 32);
    });
  });
}
