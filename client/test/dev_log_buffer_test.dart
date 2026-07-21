import 'package:elum/core/dev/dev_log_buffer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실기기에는 콘솔이 없어 이 버퍼가 유일한 로그 확인 수단이다.
/// 상한을 넘겼을 때 메모리가 무한정 늘지 않는지, 원본 출력이 유지되는지 고정한다.
/// (이슈 #13)
void main() {
  // 가로채기를 되돌리지 않으면 다음 테스트 파일의 debugPrint까지 오염된다
  tearDown(DevLogBuffer.uninstall);

  test('debugPrint한 내용이 버퍼에 쌓인다', () {
    DevLogBuffer.install();

    debugPrint('[test] 첫 줄');
    debugPrint('[test] 둘째 줄');

    expect(DevLogBuffer.lines, contains('[test] 첫 줄'));
    expect(DevLogBuffer.lines, contains('[test] 둘째 줄'));
  });

  test('원본 출력을 막지 않는다', () {
    // 버퍼에 쌓느라 콘솔 출력이 사라지면 개발 중 디버깅이 더 불편해진다
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (msg, {wrapWidth}) => printed.add(msg ?? '');

    DevLogBuffer.install();
    debugPrint('[test] 통과 확인');

    expect(printed, contains('[test] 통과 확인'));

    DevLogBuffer.uninstall();
    debugPrint = original;
  });

  test('상한을 넘으면 오래된 줄부터 버린다', () {
    DevLogBuffer.install();

    for (var i = 0; i < DevLogBuffer.maxLines + 50; i++) {
      debugPrint('line $i');
    }

    expect(DevLogBuffer.lines.length, DevLogBuffer.maxLines);
    // 처음 50줄은 밀려나고 마지막 줄은 남아 있어야 한다
    expect(DevLogBuffer.lines.first, 'line 50');
    expect(DevLogBuffer.lines.last, 'line ${DevLogBuffer.maxLines + 49}');
  });

  test('clear하면 비워진다', () {
    DevLogBuffer.install();
    debugPrint('[test] 지워질 줄');

    DevLogBuffer.clear();

    expect(DevLogBuffer.lines, isEmpty);
  });

  test('두 번 install해도 원본이 중첩되지 않는다', () {
    // 중첩되면 같은 줄이 두 번 쌓인다
    DevLogBuffer.install();
    DevLogBuffer.install();

    debugPrint('[test] 한 번만');

    expect(
      DevLogBuffer.lines.where((l) => l == '[test] 한 번만').length,
      1,
    );
  });

  test('복사용 텍스트는 줄바꿈으로 이어진다', () {
    DevLogBuffer.install();
    debugPrint('a');
    debugPrint('b');

    expect(DevLogBuffer.asText(), 'a\nb');
  });
}
