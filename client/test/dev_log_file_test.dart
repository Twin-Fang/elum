import 'dart:io';

import 'package:elum/core/dev/dev_log_file.dart';
import 'package:elum/core/dev/dev_tools_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

/// 파일 로그 — 2MB 상한과 숨김 동작 (이슈 #219).
///
/// 메모리 버퍼만으로는 **앱이 죽으면 로그가 함께 사라진다.** QA가 "튕겼어요"라고
/// 할 때 정작 볼 것이 없었다. 파일에 남기되, 무한히 커지면 기기를 잡아먹는다.
void main() {
  late Directory tmp;
  late File logFile;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('elum_log_test');
    logFile = File('${tmp.path}/elum-debug.log')..createSync();
    DevLogFile.useFileForTest(logFile);
  });

  tearDown(() async {
    DevLogFile.resetForTest();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('쓴 줄이 파일에 남는다', () async {
    DevLogFile.append('첫 줄');
    DevLogFile.append('둘째 줄');
    await DevLogFile.flushForTest();

    expect(await DevLogFile.readAll(), contains('첫 줄'));
    expect(await DevLogFile.readAll(), contains('둘째 줄'));
  });

  test('크기를 알려준다 — 얼마나 찼는지 화면에 보여야 한다', () async {
    expect(DevLogFile.sizeBytes.value, 0);

    DevLogFile.append('가나다라마바사');
    await DevLogFile.flushForTest();

    expect(DevLogFile.sizeBytes.value, greaterThan(0));
    expect(DevLogFile.usedRatio, greaterThan(0));
    expect(DevLogFile.usedRatio, lessThan(1));
  });

  test('2MB를 넘으면 오래된 쪽부터 버린다 (이슈 #219)', () async {
    // 상한을 넘기도록 채운다. 한 줄 1KB × 2500줄 ≈ 2.5MB
    final line = 'x' * 1024;
    for (var i = 0; i < 2500; i++) {
      DevLogFile.append('$i $line');
    }
    await DevLogFile.flushForTest();

    final size = await logFile.length();
    expect(size, lessThanOrEqualTo(DevLogFile.maxBytes),
        reason: '상한을 넘겨 계속 커지면 기기 저장공간을 잡아먹는다');

    final content = await DevLogFile.readAll();
    // 문제는 보통 마지막에 일어난다 — 최근 것이 남아야 한다
    expect(content, contains('2499 '), reason: '가장 최근 줄이 사라졌다');
    expect(content.contains('\n0 $line'), isFalse, reason: '오래된 줄이 남아 있다');
  });

  test('잘라낸 뒤에도 첫 줄이 깨지지 않는다', () async {
    final line = 'y' * 1024;
    for (var i = 0; i < 2500; i++) {
      DevLogFile.append('LINE$i $line');
    }
    await DevLogFile.flushForTest();

    final first = (await DevLogFile.readAll()).split('\n').first;
    // 줄 중간에서 자르면 'INE1234 yyy…'처럼 앞이 뜯긴 줄이 남는다
    expect(first.startsWith('LINE'), isTrue, reason: '첫 줄이 중간부터 시작한다: $first');
  });

  test('파일이 없으면 append가 조용히 넘어간다 — 앱이 죽지 않는다', () async {
    DevLogFile.resetForTest();

    expect(() => DevLogFile.append('아무거나'), returnsNormally);
    expect(await DevLogFile.readAll(), contains('없음'));
  });

  test('비우면 0이 된다', () async {
    DevLogFile.append('지워질 줄');
    await DevLogFile.flushForTest();
    expect(DevLogFile.sizeBytes.value, greaterThan(0));

    await DevLogFile.clear();

    expect(DevLogFile.sizeBytes.value, 0);
    expect(await DevLogFile.readAll(), isEmpty);
  });

  group('디버깅 버튼 숨기기', () {
    tearDown(DevToolsVisibility.reset);

    test('처음에는 보인다', () {
      expect(DevToolsVisibility.hidden.value, isFalse);
    });

    test('숨기면 숨겨진다', () {
      DevToolsVisibility.hide();
      expect(DevToolsVisibility.hidden.value, isTrue);
    });

    test('숨김은 메모리에만 있다 — 재실행하면 되살아난다 (이슈 #219)', () {
      // 저장소에 쓰면 앱을 다시 켜도 숨겨진 채 남아, 다음 사람이 개발자 도구를
      // 못 찾는다. static 필드라 프로세스가 죽으면 초기화된다 — reset이 그 재현이다.
      DevToolsVisibility.hide();
      expect(DevToolsVisibility.hidden.value, isTrue);

      DevToolsVisibility.reset(); // = 앱 완전 종료 후 재실행

      expect(DevToolsVisibility.hidden.value, isFalse);
    });
  });
}
