@Tags(['sync'])
library;

import 'dart:io';

import 'package:elum/core/network/server_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버 `ErrorCode.java` 와 클라 [ServerErrorCode] 가 어긋나지 않는지 본다.
///
/// **사람이 두 파일을 눈으로 맞추는 일은 반드시 빠진다.** 서버에 코드를 하나 더하고
/// 앱에 안 더하면, 그 실패는 사용자에게 `E-HTTP-400` 같은 알맹이 없는 식별자로만
/// 보인다. 그 어긋남을 여기서 잡는다 (#347).
void main() {
  // 모노레포라 서버 파일이 같은 저장소에 있다. 없으면(서버만 떼어낸 체크아웃 등)
  // 조용히 건너뛴다 — 없는 파일 때문에 앱 테스트가 깨지면 안 된다.
  final file = File(
    '../server/src/main/java/com/chuseok22/elumserver/'
    'common/infrastructure/exception/ErrorCode.java',
  );

  test('서버에 있는 코드가 앱에도 다 있다', () {
    if (!file.existsSync()) {
      markTestSkipped('서버 파일이 없다 — 이 체크아웃에서는 건너뛴다');
      return;
    }

    final serverCodes = RegExp(r'^\s{2}([A-Z][A-Z0-9_]*)\(HttpStatus\.', multiLine: true)
        .allMatches(file.readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();

    expect(serverCodes, isNotEmpty, reason: '추출에 실패하면 이 테스트는 아무것도 못 본다');

    final appCodes = ServerErrorCode.values.map((c) => c.wire).toSet();
    final missing = serverCodes.difference(appCodes);

    expect(
      missing,
      isEmpty,
      reason: '서버에만 있는 코드다. `server_error_code.dart` 에 같은 이름으로 더한다',
    );
  });

  test('앱에만 있는 코드는 없다 — 서버에서 지워졌다는 뜻이다', () {
    if (!file.existsSync()) {
      markTestSkipped('서버 파일이 없다 — 이 체크아웃에서는 건너뛴다');
      return;
    }

    final serverCodes = RegExp(r'^\s{2}([A-Z][A-Z0-9_]*)\(HttpStatus\.', multiLine: true)
        .allMatches(file.readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();

    final appCodes = ServerErrorCode.values
        .where((c) => c != ServerErrorCode.unknown)
        .map((c) => c.wire)
        .toSet();

    expect(appCodes.difference(serverCodes), isEmpty);
  });
}
