import 'package:elum/core/layout/adaptive_page_frame.dart';
import 'package:elum/core/layout/screen_layout_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/adaptive_test_app.dart';

/// 태블릿에서 화면을 폰 비율 열(가운데)로 담는 프레임.
/// 깨지면: 태블릿에서 화면이 전폭으로 늘어나 찌그러지거나, 회전할 때 입력한 글이 사라진다.
const _probeKey = ValueKey('frame.probe');
const _fieldKey = ValueKey('frame.field');
const _buttonKey = ValueKey('frame.button');

/// 입력칸과 아래 버튼이 있는 시안형 화면 (높이 고정 배치 흉내)
class _FormPage extends StatefulWidget {
  const _FormPage();

  @override
  State<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<_FormPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        key: _probeKey,
        child: Column(
          children: [
            const SizedBox(height: 120),
            TextField(key: _fieldKey, controller: _controller),
            const Spacer(),
            ElevatedButton(
              key: _buttonKey,
              onPressed: () {},
              child: const Text('다음'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

Widget _framed(ScreenLayoutKind kind) => adaptiveTestApp(
  home: AdaptivePageFrame(kind: kind, child: const _FormPage()),
);

void main() {
  group('phoneColumn', () {
    testWidgets('가로 태블릿: 폰 비율 열이 창 가운데에 선다', (tester) async {
      setTestWindowSize(tester, const Size(1194, 834));
      await tester.pumpWidget(_framed(ScreenLayoutKind.phoneColumn));
      await tester.pump();

      final size = tester.getSize(find.byKey(_probeKey));
      final center = tester.getCenter(find.byKey(_probeKey));

      expect(size.width, closeTo(393 * 834 / 852, 0.5));
      expect(size.height, closeTo(834, 0.5));
      expect(center.dx, closeTo(1194 / 2, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('열 안 MediaQuery 크기가 열 크기와 같다', (tester) async {
      setTestWindowSize(tester, const Size(1194, 834));
      late Size innerSize;
      await tester.pumpWidget(
        adaptiveTestApp(
          home: AdaptivePageFrame(
            kind: ScreenLayoutKind.phoneColumn,
            child: Builder(
              builder: (context) {
                innerSize = MediaQuery.sizeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(innerSize.width, closeTo(393 * 834 / 852, 0.5));
    });

    testWidgets('폰 크기에서는 프레임이 크기를 바꾸지 않는다', (tester) async {
      setTestWindowSize(tester, const Size(393, 852));
      await tester.pumpWidget(adaptiveTestApp(home: const _FormPage()));
      await tester.pump();
      final withoutFrame = tester.getSize(find.byKey(_probeKey));

      await tester.pumpWidget(_framed(ScreenLayoutKind.phoneColumn));
      await tester.pump();

      expect(tester.getSize(find.byKey(_probeKey)), withoutFrame);
    });

    testWidgets('등급이 바뀌어도 입력한 글이 남는다 (회전·분할)', (tester) async {
      setTestWindowSize(tester, const Size(393, 852));
      await tester.pumpWidget(_framed(ScreenLayoutKind.phoneColumn));
      await tester.pump();
      await tester.enterText(find.byKey(_fieldKey), '하늘이');

      tester.view.physicalSize = const Size(800, 1280);
      await tester.pump();
      await tester.pump();

      expect(find.text('하늘이'), findsOneWidget);

      tester.view.physicalSize = const Size(393, 852);
      await tester.pump();
      await tester.pump();

      expect(find.text('하늘이'), findsOneWidget);
    });

    testWidgets('높이가 모자라면 스크롤되고 아래 버튼에 닿는다', (tester) async {
      setTestWindowSize(tester, const Size(960, 600));
      await tester.pumpWidget(_framed(ScreenLayoutKind.phoneColumn));
      await tester.pump();

      // TextField 안쪽에도 Scrollable 이 있어 프레임의 스크롤뷰로 확인한다
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.ensureVisible(find.byKey(_buttonKey));
      await tester.pump();

      final bottom = tester.getRect(find.byKey(_buttonKey)).bottom;
      expect(bottom, lessThanOrEqualTo(600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('스크롤 상태에서 키보드가 올라와도 버튼이 키보드 위에 보인다', (tester) async {
      setTestWindowSize(tester, const Size(960, 600));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpWidget(_framed(ScreenLayoutKind.phoneColumn));
      await tester.pump();

      await tester.ensureVisible(find.byKey(_buttonKey));
      await tester.pump();

      final bottom = tester.getRect(find.byKey(_buttonKey)).bottom;
      expect(bottom, lessThanOrEqualTo(600 - 300));
    });
  });

  group('contentColumn', () {
    testWidgets('폭 상한(560 x 배율) 안에서 가운데', (tester) async {
      setTestWindowSize(tester, const Size(1366, 1024));
      await tester.pumpWidget(_framed(ScreenLayoutKind.contentColumn));
      await tester.pump();

      final size = tester.getSize(find.byKey(_probeKey));
      final center = tester.getCenter(find.byKey(_probeKey));

      expect(size.width, closeTo(560 * 1024 / 852, 0.5));
      expect(center.dx, closeTo(1366 / 2, 0.5));
    });
  });

  group('adaptive', () {
    testWidgets('화면이 직접 구성하므로 자식을 그대로 둔다', (tester) async {
      setTestWindowSize(tester, const Size(1194, 834));
      await tester.pumpWidget(_framed(ScreenLayoutKind.adaptive));
      await tester.pump();

      expect(tester.getSize(find.byKey(_probeKey)).width, 1194);
    });
  });
}
