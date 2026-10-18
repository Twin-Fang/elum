import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/widgets/issued_code_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/pump_with_locale.dart';

/// 깨지면: 코드 복사가 막혔을 때 사용자가 에러 코드(E-CODE-COPY)만 보고 무슨 일인지 모른다
void main() {
  useFigmaViewport();

  testWidgets('복사가 막히면 실패 팝업이 문구와 에러 코드를 함께 보여 준다', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard-blocked');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpWithLocale(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => copyIssuedCode(
              context,
              IssuedLinkCode(
                code: 'ABC123',
                expiresAt: DateTime.now().add(const Duration(minutes: 10)),
              ),
            ),
            child: const Text('복사'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('복사'));
    await tester.pumpAndSettle();

    expect(find.textContaining('복사하지 못했어요'), findsOneWidget);
    expect(find.text('E-CODE-COPY'), findsOneWidget);
  });
}
