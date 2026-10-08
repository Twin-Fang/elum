import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_layer_imports.dart';

void main() {
  // CI 가 `flutter test` 만 돌리므로 검사기를 여기서 게이트로 건다
  test('계층 import 위반이 동결 목록보다 늘지 않는다', () {
    final hits = scanLib().toSet();
    final added = hits.difference(allowed()).toList()..sort();
    expect(
      added,
      isEmpty,
      reason:
          '바닥 계층은 위를 모르고, 기능끼리는 application·domain 을 거친다:\n${added.join('\n')}',
    );
  });

  test('동결 목록에 이미 사라진 줄이 남지 않는다', () {
    final stale = allowed().difference(scanLib().toSet()).toList()..sort();
    expect(
      stale,
      isEmpty,
      reason: 'tool/layer_imports_allowed.txt 에서 지운다:\n${stale.join('\n')}',
    );
  });

  test('core 가 기능을 import 하면 잡는다', () {
    expect(
      scan('core/theme/x.dart', "import '../../features/a/domain/b.dart';"),
      ['core/theme/x.dart -> features/a/domain/b.dart'],
    );
    expect(
      scan(
        'core/router/x.dart',
        "import '../../features/a/presentation/b.dart';",
      ),
      isEmpty,
    );
  });

  test('다른 기능의 data·presentation 만 잡고 application·domain 은 둔다', () {
    expect(scan('features/a/x.dart', "import '../b/data/r.dart';"), [
      'features/a/x.dart -> features/b/data/r.dart',
    ]);
    expect(
      scan('features/a/x.dart', "import '../b/application/n.dart';"),
      isEmpty,
    );
    expect(
      scan(
        'features/a/x.dart',
        "import 'package:elum/features/b/presentation/s.dart';",
      ),
      ['features/a/x.dart -> features/b/presentation/s.dart'],
    );
    expect(
      scan('features/a/presentation/x.dart', "import '../data/r.dart';"),
      isEmpty,
    );
  });
}
