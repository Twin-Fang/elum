import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/widgets/issued_code_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 발급 코드 덩어리와 코드 입력칸의 기본 렌더링.
void main() {
  useFigmaViewport();

  group('IssuedCodePanel', () {
    // 올림하면 실제보다 길게 말해 믿고 기다리다 코드가 바뀐다
    test('남은 시간은 올림이 아니라 내림으로 MM:SS 를 말한다', () {
      final issued = IssuedLinkCode(
        code: 'ABC123',
        expiresAt: DateTime.now().add(const Duration(minutes: 9, seconds: 59, milliseconds: 900)),
      );
      expect(IssuedCodePanel.remainingLabel(issued), '09:59');
    });
  });

}
