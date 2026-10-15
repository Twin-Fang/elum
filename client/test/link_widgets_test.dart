import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/widgets/issued_code_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 발급 코드 덩어리와 코드 입력칸의 기본 렌더링.
void main() {
  useFigmaViewport();

  group('IssuedCodePanel', () {
    test('남은 시간 글자는 만료되면 만료 문구다', () {
      final expired = IssuedLinkCode(
        code: 'ABC123',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(IssuedCodePanel.remainingLabel(expired, '만료'), '만료');
    });
  });

}
