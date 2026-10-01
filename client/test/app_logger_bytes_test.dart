import 'dart:convert';

import 'package:elum/core/logger/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 로그가 이미지 바이트를 숫자 목록으로 펼치지 않는다 (#501).
///
/// 카드 그림 응답(수 MB)이 `[137,80,78,71,...]` 로 한 줄에 수천 자씩 찍혀 로그를 내보내거나
/// 읽을 수 없었다. 502 오류 때도 HTML 오류 페이지가 숫자 목록이라 무슨 오류인지 알 수 없었다.
void main() {
  List<String> captureLogs() {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
    return logs;
  }

  void logResponse(Object body) => AppLogger.networkSuccess(
    method: 'GET',
    endpoint: '/api/routines/r/steps/s/image',
    statusCode: 200,
    duration: const Duration(milliseconds: 10),
    responseData: body,
  );

  test('그림 같은 바이너리는 개수만 남긴다', () {
    final logs = captureLogs();
    // PNG 머리말 — 글자로 읽히지 않는다
    final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, ...List.filled(5000, 7)]);

    logResponse(png);

    final text = logs.join('\n');
    expect(text, contains('바이트 5008개'));
    expect(text, isNot(contains('137,80')), reason: '숫자를 펼치지 않는다');
    expect(text.length, lessThan(600));
  });

  test('글자로 읽히는 오류 본문은 앞부분을 함께 남긴다', () {
    final logs = captureLogs();
    final html = utf8.encode('<!DOCTYPE html><html><body>502 Bad Gateway</body></html>${' ' * 300}');

    logResponse(html);

    final text = logs.join('\n');
    expect(text, contains('바이트 ${html.length}개'));
    expect(text, contains('502 Bad Gateway'), reason: '무슨 오류인지 알아볼 수 있다');
  });

  test('짧은 정수 목록은 그대로 펼친다', () {
    final logs = captureLogs();

    logResponse([1, 2, 3]);

    expect(logs.join('\n'), contains('[1,2,3]'));
  });
}
