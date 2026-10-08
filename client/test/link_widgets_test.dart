import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/widgets/code_boxes.dart';
import 'package:elum/features/link/presentation/widgets/code_entry_field.dart';
import 'package:elum/features/link/presentation/widgets/issued_code_panel.dart';
import 'package:elum/features/link/presentation/widgets/link_code_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/pump_with_locale.dart';

/// 발급 코드 덩어리와 코드 입력칸의 기본 렌더링.
void main() {
  useFigmaViewport();

  Widget panel({
    bool loading = false,
    IssuedLinkCode? issued,
    bool showStatus = true,
    Widget? replacement,
  }) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IssuedCodePanel(
          loading: loading,
          issued: issued,
          expiredLabel: '만료',
          retryLabel: '다시',
          onRetry: () {},
          showStatus: showStatus,
          replacement: replacement,
        ),
      ],
    ),
  );

  IssuedLinkCode live() =>
      IssuedLinkCode.fromNow(code: 'ABC123', expiresInSeconds: 600);

  group('IssuedCodePanel', () {
    testWidgets('만드는 중에는 스피너만 보인다', (tester) async {
      await pumpWithLocale(tester, Scaffold(body: panel(loading: true)));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinkCodeText), findsNothing);
    });

    testWidgets('코드와 남은 시간과 칩이 보인다', (tester) async {
      await pumpWithLocale(tester, Scaffold(body: panel(issued: live())));

      expect(find.byType(LinkCodeText), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsOneWidget);
      expect(find.text('다시'), findsOneWidget);
    });

    testWidgets('상태를 끄면 코드만 남는다', (tester) async {
      await pumpWithLocale(
        tester,
        Scaffold(body: panel(issued: live(), showStatus: false)),
      );

      expect(find.byType(LinkCodeText), findsOneWidget);
      expect(find.byType(LinkRetryChip), findsNothing);
    });

    testWidgets('대체 위젯이 있으면 코드 대신 보인다', (tester) async {
      await pumpWithLocale(
        tester,
        Scaffold(
          body: panel(issued: live(), replacement: const Text('실패')),
        ),
      );

      expect(find.text('실패'), findsOneWidget);
      expect(find.byType(LinkCodeText), findsNothing);
    });

    test('남은 시간 글자는 만료되면 만료 문구다', () {
      final expired = IssuedLinkCode(
        code: 'ABC123',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(IssuedCodePanel.remainingLabel(expired, '만료'), '만료');
    });
  });

  group('CodeEntryField', () {
    Widget field({String value = '', bool sending = false, bool figma = false}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CodeEntryField(
              controller: TextEditingController(),
              focusNode: FocusNode(),
              value: value,
              semanticsLabel: '코드 입력',
              onTap: () {},
              failCount: 0,
              sending: sending,
              figma: figma,
            ),
          ],
        );

    testWidgets('여섯 칸과 보이지 않는 입력칸이 있다', (tester) async {
      await pumpWithLocale(tester, Scaffold(body: field(value: 'AB')));

      expect(find.byType(CodeBoxes), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('보내는 중이면 스피너가 보인다', (tester) async {
      await pumpWithLocale(
        tester,
        Scaffold(body: field(sending: true, figma: true)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
