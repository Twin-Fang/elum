import 'dart:convert';

import 'package:elum/core/logger/app_log_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

/// 의견에 붙는 앱 로그 버퍼 — 줄·바이트 상한과 오래된 줄부터 버리는 순서를 고정한다.
void main() {
  setUp(AppLogBuffer.resetForTest);
  tearDown(AppLogBuffer.resetForTest);

  test('줄 수가 200을 넘으면 오래된 줄부터 빠진다', () {
    for (var i = 0; i < 250; i++) {
      AppLogBuffer.add('line $i');
    }

    final lines = AppLogBuffer.asText().split('\n');
    expect(lines.length, AppLogBuffer.maxLines);
    expect(lines.first, 'line 50');
    expect(lines.last, 'line 249');
  });

  test('바이트 합계가 50KB를 넘지 않고 오래된 줄이 먼저 빠진다', () {
    final chunk = 'x' * 1000;
    for (var i = 0; i < 80; i++) {
      AppLogBuffer.add('$i $chunk');
    }

    expect(AppLogBuffer.totalBytes, lessThanOrEqualTo(AppLogBuffer.maxBytes));
    expect(utf8.encode(AppLogBuffer.asText()).length,
        lessThanOrEqualTo(AppLogBuffer.maxBytes + AppLogBuffer.maxLines));
    final text = AppLogBuffer.asText();
    expect(text.startsWith('0 $chunk'), isFalse);
    expect(text.endsWith('79 $chunk'), isTrue);
  });

  test('한글은 글자 수가 아니라 UTF-8 바이트로 센다', () {
    // 한글 한 글자는 3바이트 — 20000자는 60000바이트라 한 줄로도 상한을 넘는다
    AppLogBuffer.add('가' * 20000);

    expect(AppLogBuffer.totalBytes, lessThanOrEqualTo(AppLogBuffer.maxBytes));
    expect(AppLogBuffer.asText(), isNotEmpty);
  });

  test('clear 하면 비고 다시 쌓을 수 있다', () {
    AppLogBuffer.add('a');
    AppLogBuffer.clear();
    expect(AppLogBuffer.asText(), isEmpty);
    expect(AppLogBuffer.length, 0);
    expect(AppLogBuffer.totalBytes, 0);

    AppLogBuffer.add('b');
    expect(AppLogBuffer.asText(), 'b');
  });
}
