import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_hangul_literals.dart';

void main() {
  // CI 가 `flutter test` 만 돌리므로 검사기를 여기서 게이트로 건다
  test('lib 에 사용자 노출 한글 리터럴이 0줄이다', () {
    final hits = <String>[];
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path)
            .where((p) => p.endsWith('.dart') && !p.endsWith('.freezed.dart'))
            .where((p) => !isSkippedPath(p))
            .toList()
          ..sort();
    for (final path in files) {
      hits.addAll(scan(path, File(path).readAsStringSync()));
    }
    expect(hits, isEmpty, reason: '한글 문구는 ARB 로 옮긴다:\n${hits.join('\n')}');
  });
}
