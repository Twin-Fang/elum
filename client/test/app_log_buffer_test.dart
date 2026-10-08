import 'dart:convert';

import 'package:elum/core/logger/app_log_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

int _bytes(String s) => utf8.encode(s).length;

/// 의견에 붙는 앱 기록 버퍼 — 일반 기록 상한, 오류 보관, 전송 텍스트의 순서와 크기 상한을 고정한다.
void main() {
  setUp(AppLogBuffer.resetForTest);
  tearDown(AppLogBuffer.resetForTest);

  test('줄 수가 상한을 넘으면 오래된 줄부터 빠진다', () {
    for (var i = 0; i < AppLogBuffer.maxLines + 50; i++) {
      AppLogBuffer.add('line $i');
    }

    final lines = AppLogBuffer.asText().split('\n');
    expect(lines.length, AppLogBuffer.maxLines);
    expect(lines.first, 'line 50');
    expect(lines.last, 'line ${AppLogBuffer.maxLines + 49}');
  });

  test('바이트 합계가 256KB를 넘지 않고 오래된 줄이 먼저 빠진다', () {
    final chunk = 'x' * 1000;
    for (var i = 0; i < 400; i++) {
      AppLogBuffer.add('$i $chunk');
    }

    expect(AppLogBuffer.maxBytes, 262144);
    expect(AppLogBuffer.totalBytes, lessThanOrEqualTo(AppLogBuffer.maxBytes));
    final text = AppLogBuffer.asText();
    expect(_bytes(text), lessThanOrEqualTo(AppLogBuffer.maxBytes));
    expect(text.startsWith('0 $chunk'), isFalse);
    expect(text.endsWith('399 $chunk'), isTrue);
  });

  test('한글은 글자 수가 아니라 UTF-8 바이트로 센다', () {
    // 한글 한 글자는 3바이트 — 100000자는 300000바이트라 한 줄로도 상한을 넘는다
    AppLogBuffer.add('가' * 100000);

    expect(AppLogBuffer.totalBytes, lessThanOrEqualTo(AppLogBuffer.maxBytes));
    expect(_bytes(AppLogBuffer.asText()), lessThanOrEqualTo(AppLogBuffer.maxBytes));
    expect(AppLogBuffer.asText(), isNotEmpty);
  });

  test('오류는 최근 30건만 보관하고 한 건은 6000자에서 잘린다', () {
    for (var i = 0; i < 40; i++) {
      AppLogBuffer.addError('err $i');
    }
    expect(AppLogBuffer.errorCount, AppLogBuffer.maxErrors);
    final text = AppLogBuffer.asText();
    expect(text.contains('err 9\n'), isFalse);
    expect(text.contains('err 10'), isTrue);
    expect(text.contains('err 39'), isTrue);

    AppLogBuffer.resetForTest();
    AppLogBuffer.addError('y' * 9000);
    final err = AppLogBuffer.asText().split('\n').last;
    expect(err.length, AppLogBuffer.maxErrorChars);
  });

  test('일반 기록이 쏟아져도 오류는 밀리지 않는다', () {
    AppLogBuffer.addError('중요한 오류');
    for (var i = 0; i < 5000; i++) {
      AppLogBuffer.add('noise $i ${'z' * 200}');
    }

    final text = AppLogBuffer.asText();
    expect(text, contains('중요한 오류'));
    expect(_bytes(text), lessThanOrEqualTo(AppLogBuffer.maxBytes));
  });

  test('순서는 머리말, 최근 오류, 기록이고 전체가 상한 안이다', () {
    AppLogBuffer.addError('E1');
    AppLogBuffer.add('L1');
    final text = AppLogBuffer.asText(header: 'HEAD');

    expect(text, 'HEAD\n${AppLogBuffer.errorSectionTitle}\nE1\n${AppLogBuffer.logSectionTitle}\nL1');
  });

  test('머리말과 오류가 크면 일반 기록을 앞에서부터 잘라 상한을 지킨다', () {
    for (var i = 0; i < 30; i++) {
      AppLogBuffer.addError('${'e' * 5000}$i');
    }
    for (var i = 0; i < 1000; i++) {
      AppLogBuffer.add('log $i ${'q' * 300}');
    }
    final text = AppLogBuffer.asText(header: 'H' * 2000);

    expect(_bytes(text), lessThanOrEqualTo(AppLogBuffer.maxBytes));
    expect(text.startsWith('H'), isTrue);
    expect(text, contains(AppLogBuffer.errorSectionTitle));
    expect(text, contains('log 999'));
    expect(text.contains('log 0 '), isFalse);
  });

  test('clear 하면 비고 다시 쌓을 수 있다', () {
    AppLogBuffer.add('a');
    AppLogBuffer.addError('e');
    AppLogBuffer.clear();
    expect(AppLogBuffer.asText(), isEmpty);
    expect(AppLogBuffer.isEmpty, isTrue);
    expect(AppLogBuffer.length, 0);
    expect(AppLogBuffer.errorCount, 0);
    expect(AppLogBuffer.totalBytes, 0);

    AppLogBuffer.add('b');
    expect(AppLogBuffer.asText(), 'b');
  });
}
